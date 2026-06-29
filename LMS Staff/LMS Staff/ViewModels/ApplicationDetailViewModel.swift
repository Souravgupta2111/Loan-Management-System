//
//  ApplicationDetailViewModel.swift
//  LMS Staff
//
//  ViewModel for managing the detail view of a loan application.
//

import Foundation
import SwiftUI
import Supabase
import Combine

@MainActor
class ApplicationDetailViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var application: LoanApplication
    @Published var borrower: AppUser
    @Published var borrowerProfile: BorrowerProfile?
    @Published var product: LoanProduct
    @Published var documents: [LMSDocument] = []
    @Published var borrowerMessages: [Message] = []
    @Published var internalMessages: [Message] = []
    @Published var timelineItems: [StaffTimelineView.TimelineItem] = []
    
    @Published var isLoading: Bool = false
    @Published var isSendingMessage: Bool = false
    @Published var errorMessage: String?
    
    private let documentService = DocumentService.shared
    private let messageService = MessageService.shared
    private let appService = ApplicationService.shared
    private let supabase = SupabaseManager.shared
    
    private var chatChannel: RealtimeChannelV2?
    
    init(application: LoanApplication, borrower: AppUser, profile: BorrowerProfile?, product: LoanProduct) {
        self.application = application
        self.borrower = borrower
        self.borrowerProfile = profile
        self.product = product
    }
    
    // MARK: - Load Details
    
    func loadAllDetails() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch uploaded documents
            self.documents = try await documentService.fetchDocuments(forApplicationId: application.id)
            
            // Fetch timeline logs from approval history
            let logs: [ApprovalHistoryItem] = try await supabase.database
                .from("approval_history")
                .select()
                .eq("application_id", value: application.id)
                .order("actioned_at", ascending: false)
                .execute()
                .value
            
            let actorIds = Array(Set(logs.map { $0.actorId }))
            var actorsMap: [UUID: AppUser] = [:]
            if !actorIds.isEmpty {
                let users: [AppUser] = try await supabase.database
                    .from("users")
                    .select()
                    .in("id", values: actorIds)
                    .execute()
                    .value
                for user in users {
                    actorsMap[user.id] = user
                }
            }
            
            self.timelineItems = logs.map { log in
                let actorUser = actorsMap[log.actorId]
                let actorName = actorUser?.fullName ?? "System"
                let roleName = actorUser?.role.rawValue ?? "system"
                
                var icon = "clock"
                var color = Color.staffTextSecondary
                
                switch log.action {
                case .submit:
                    icon = "paperplane.fill"
                    color = .staffAccent
                case .review:
                    icon = "eye.fill"
                    color = .staffAmber
                case .approve:
                    icon = "checkmark.circle.fill"
                    color = .staffGreen
                case .reject:
                    icon = "xmark.circle.fill"
                    color = .staffRed
                case .sendBack:
                    icon = "arrow.uturn.backward.circle.fill"
                    color = .staffOrange
                case .disburse:
                    icon = "banknote.fill"
                    color = .staffAccent
                case .escalate:
                    icon = "arrow.up.circle.fill"
                    color = .staffRed
                }
                
                return StaffTimelineView.TimelineItem(
                    id: log.id,
                    action: log.action.displayName,
                    actor: actorName,
                    role: roleName,
                    remarks: log.remarks,
                    timestamp: log.actionedAt ?? Date(),
                    icon: icon,
                    color: color
                )
            }
            
            // Fetch chat history
            let allMessages = try await messageService.fetchMessages(forApplicationId: application.id)
            self.borrowerMessages = allMessages.filter { $0.senderId == borrower.id || $0.receiverId == borrower.id }
            self.internalMessages = allMessages.filter { $0.senderId != borrower.id && $0.receiverId != borrower.id }
            
            // Subscribe to real-time chat
            subscribeToChat()
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Document Actions
    
    func verifyDocument(documentId: UUID, isVerified: Bool, reason: String? = nil) async {
        do {
            try await documentService.verifyDocument(documentId: documentId, isVerified: isVerified, rejectionReason: reason)
            // Reload documents
            self.documents = try await documentService.fetchDocuments(forApplicationId: application.id)
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func getDocumentUrl(for document: LMSDocument) async -> URL? {
        guard let bucket = document.storageBucket, let path = document.storagePath else {
            self.errorMessage = "Document file is missing storage information."
            return nil
        }
        do {
            return try await documentService.getSignedUrl(bucket: bucket, path: path)
        } catch {
            self.errorMessage = error.localizedDescription
            return nil
        }
    }
    
    func requestDocuments(documentTypes: [String], remarks: String) async -> Bool {
        do {
            try await appService.requestDocuments(
                applicationId: application.id,
                borrowerId: borrower.id,
                documentTypes: documentTypes,
                remarks: remarks
            )
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
    
    // MARK: - Chat Actions
    
    func subscribeToChat() {
        if chatChannel != nil { return }
        
        chatChannel = messageService.subscribeToMessages(forApplicationId: application.id) { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                if let allMessages = try? await self.messageService.fetchMessages(forApplicationId: self.application.id) {
                    self.borrowerMessages = allMessages.filter { $0.senderId == self.borrower.id || $0.receiverId == self.borrower.id }
                    self.internalMessages = allMessages.filter { $0.senderId != self.borrower.id && $0.receiverId != self.borrower.id }
                }
            }
        }
    }
    
    func sendChatMessage(_ content: String, isInternal: Bool = false) async {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSendingMessage = true
        
        do {
            let receiverId: UUID
            if isInternal {
                // If it's internal, we need to send it to the manager (if current is officer) or officer (if current is manager).
                // Let's resolve the receiver.
                let currentUserId = supabase.currentUserId!
                
                // Fetch the staff list to find the manager if needed
                let allStaff = try? await StaffManagementService.shared.fetchStaff()
                let currentStaff = allStaff?.first(where: { $0.id == currentUserId })
                
                if currentStaff?.user.role == .manager {
                    // Manager sends to Officer
                    receiverId = application.assignedOfficerId ?? currentUserId
                } else if let branchId = application.branchId, let manager = try? await StaffManagementService.shared.fetchBranchManager(branchId: branchId) {
                    // Officer sends to Manager
                    receiverId = manager.id
                } else {
                    // Fallback
                    receiverId = currentUserId
                }
            } else {
                receiverId = borrower.id
            }
            
            let sent = try await messageService.sendMessage(
                applicationId: application.id,
                receiverId: receiverId,
                content: content
            )
            
            if isInternal {
                self.internalMessages.append(sent)
            } else {
                self.borrowerMessages.append(sent)
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isSendingMessage = false
    }
    
    func markMessageAsRead(_ messageId: UUID) async {
        do {
            try await messageService.markAsRead(messageId: messageId)
            if let index = borrowerMessages.firstIndex(where: { $0.id == messageId }) {
                borrowerMessages[index].isRead = true
            } else if let index = internalMessages.firstIndex(where: { $0.id == messageId }) {
                internalMessages[index].isRead = true
            }
        } catch {
            print("Failed to mark message as read: \(error)")
        }
    }
    
    func deleteMessage(_ messageId: UUID, isSender: Bool) async {
        do {
            try await messageService.deleteMessage(messageId: messageId, isSender: isSender)
            if let index = borrowerMessages.firstIndex(where: { $0.id == messageId }) {
                if isSender { borrowerMessages[index].isDeletedBySender = true }
                else { borrowerMessages[index].isDeletedByReceiver = true }
            } else if let index = internalMessages.firstIndex(where: { $0.id == messageId }) {
                if isSender { internalMessages[index].isDeletedBySender = true }
                else { internalMessages[index].isDeletedByReceiver = true }
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Decision Actions
    
    private func getOfficerIdIfNeeded() -> UUID? {
        if application.assignedOfficerId == nil {
            return supabase.currentUserId
        }
        return nil
    }
    
    func recommendToManager() async -> Bool {
        do {
            let officerId = getOfficerIdIfNeeded()
            try await appService.updateStatus(applicationId: application.id, status: .underReview, reason: "Recommended for manager approval by officer.", assignedOfficerId: officerId)
            self.application.status = .underReview
            if let oid = officerId { self.application.assignedOfficerId = oid }
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
    
    func rejectApplication(reason: String) async -> Bool {
        do {
            let officerId = getOfficerIdIfNeeded()
            try await appService.updateStatus(applicationId: application.id, status: .rejected, reason: reason, assignedOfficerId: officerId)
            self.application.status = .rejected
            if let oid = officerId { self.application.assignedOfficerId = oid }
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
    
    func sendBackToBorrower(reason: String) async -> Bool {
        do {
            let officerId = getOfficerIdIfNeeded()
            try await appService.updateStatus(applicationId: application.id, status: .sentBack, reason: reason, assignedOfficerId: officerId)
            self.application.status = .sentBack
            if let oid = officerId { self.application.assignedOfficerId = oid }
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
    
    deinit {
        if let channel = chatChannel {
            let service = MessageService.shared
            Task.detached {
                await service.unsubscribe(channel)
            }
        }
    }
}
