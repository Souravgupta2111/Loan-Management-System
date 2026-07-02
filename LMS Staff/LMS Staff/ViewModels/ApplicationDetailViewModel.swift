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
    @Published var underwritingSuggestion: UnderwritingSuggestion?
    
    @Published var isLoading: Bool = false
    @Published var isActionLoading: Bool = false
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
            // Fetch latest borrower profile to ensure we have the newest aa_consent_id
            let profiles: [BorrowerProfile] = try await supabase.database
                .from("borrower_profiles")
                .select()
                .eq("user_id", value: borrower.id)
                .execute()
                .value
            
            if let latestProfile = profiles.first {
                self.borrowerProfile = latestProfile
            }
            
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
            
            let mappedItems = logs.map { log -> StaffTimelineView.TimelineItem in
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
            
            // De-duplicate: Sort ascending, filter out adjacent duplicates within 60s
            var sortedMapped = mappedItems.sorted(by: { $0.timestamp < $1.timestamp })
            var filteredItems: [StaffTimelineView.TimelineItem] = []
            for i in 0..<sortedMapped.count {
                let current = sortedMapped[i]
                if i < sortedMapped.count - 1 {
                    let next = sortedMapped[i + 1]
                    if current.action == next.action && abs(next.timestamp.timeIntervalSince(current.timestamp)) <= 60 {
                        continue
                    }
                }
                filteredItems.append(current)
            }
            
            // Synthesize the initial Submission timeline item if not already logged in history
            if !filteredItems.contains(where: { $0.action.lowercased() == "submitted" || $0.action.lowercased() == "submit" }) {
                let submitDate = application.submittedAt ?? application.createdAt ?? Date()
                filteredItems.append(StaffTimelineView.TimelineItem(
                    id: UUID(),
                    action: "Submitted",
                    actor: borrower.fullName,
                    role: "Borrower",
                    remarks: "Application successfully submitted for review.",
                    timestamp: submitDate,
                    icon: "paperplane.fill",
                    color: .staffAccent
                ))
            }
            
            filteredItems.sort(by: { $0.timestamp > $1.timestamp })
            self.timelineItems = filteredItems
            
            // Fetch chat history
            let allMessages = try await messageService.fetchMessages(forApplicationId: application.id)
            self.borrowerMessages = allMessages.filter { $0.senderId == borrower.id || $0.receiverId == borrower.id }
            self.internalMessages = allMessages.filter { $0.senderId != borrower.id && $0.receiverId != borrower.id }
            
            // Subscribe to real-time chat
            subscribeToChat()
            
            // Calculate initial underwriting suggestion
            calculateSuggestion()
            
            // Automatically pull a mock credit score if it hasn't been fetched yet
            if let profile = self.borrowerProfile, (profile.creditScore == nil || profile.creditScore == 0) {
                Task {
                    do {
                        let score = try await MockCreditBureauService.shared.fetchAndSaveCreditScore(
                            userId: self.borrower.id,
                            panNumber: profile.panNumber
                        )
                        await MainActor.run {
                            self.borrowerProfile?.creditScore = score
                            self.calculateSuggestion()
                        }
                    } catch {
                        print("Failed to pull mock credit score: \(error)")
                    }
                }
            }
            
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
        guard !isActionLoading else { return false }
        isActionLoading = true
        defer { isActionLoading = false }
        
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
    
    func sendChatMessage(_ content: String, isInternal: Bool = false) async -> Bool {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        isSendingMessage = true
        
        do {
            let receiverId: UUID
            if isInternal {
                // If it's internal, we need to send it to the manager (if current is officer) or officer (if current is manager).
                // Let's resolve the receiver.
                let currentUserId = supabase.currentUserId!
                
                // Fetch the staff list to find the manager if needed
                let allStaff = try? await StaffManagementService.shared.fetchStaff()
                let currentStaff = allStaff?.first(where: { $0.staff.userId == currentUserId })
                
                if currentStaff?.user.role == .manager {
                    // Manager sends to Officer
                    if let officerProfileId = application.assignedOfficerId,
                       let officerStaff = allStaff?.first(where: { $0.staff.id == officerProfileId }) {
                        receiverId = officerStaff.user.id
                    } else {
                        receiverId = currentUserId
                    }
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
            isSendingMessage = false
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            isSendingMessage = false
            return false
        }
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
    
    private func getOfficerIdIfNeeded() async -> UUID? {
        if application.assignedOfficerId == nil {
            let currentUserId = supabase.currentUserId
            if let allStaff = try? await StaffManagementService.shared.fetchStaff(),
               let officer = allStaff.first(where: { $0.staff.userId == currentUserId }) {
                return officer.staff.id
            }
        }
        return nil
    }
    
    func recommendToManager() async -> Bool {
        guard !isActionLoading else { return false }
        isActionLoading = true
        defer { isActionLoading = false }
        
        do {
            let officerId = await getOfficerIdIfNeeded()
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
        guard !isActionLoading else { return false }
        isActionLoading = true
        defer { isActionLoading = false }
        
        do {
            let officerId = await getOfficerIdIfNeeded()
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
        guard !isActionLoading else { return false }
        isActionLoading = true
        defer { isActionLoading = false }
        
        do {
            let officerId = await getOfficerIdIfNeeded()
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
    
    // MARK: - Underwriting & Verification
    
    private func calculateSuggestion() {
        guard let profile = borrowerProfile else { return }
        let existingEMIs: Double = 0 // In future, use real data
        
        self.underwritingSuggestion = UnderwritingService.shared.calculateSuggestion(
            monthlyIncome: profile.verifiedAnnualIncome != nil ? (profile.verifiedAnnualIncome! / 12) : (profile.monthlyIncome ?? 0),
            creditScore: profile.creditScore ?? 0,
            employmentType: profile.employmentType ?? .salaried,
            requestedAmount: application.requestedAmount,
            product: product,
            existingEMIs: existingEMIs,
            isIncomeVerified: profile.incomeVerified ?? false
        )
    }
    
    func saveVerifiedIncome(_ analyzedData: AnalyzedIncome) async {
        guard let profileId = borrowerProfile?.id else { return }
        
        do {
            let updates: [String: AnyJSON] = [
                "income_verified": true,
                "verified_annual_income": .double(analyzedData.monthlySalary * 12),
                "itr_assessment_year": "AA_VERIFIED"
            ]
            
            try await supabase.database
                .from("borrower_profiles")
                .update(updates)
                .eq("id", value: profileId)
                .execute()
            
            // Refresh borrower profile
            self.borrowerProfile?.incomeVerified = true
            self.borrowerProfile?.verifiedAnnualIncome = analyzedData.monthlySalary * 12
            self.borrowerProfile?.itrAssessmentYear = "AA_VERIFIED"
            
            calculateSuggestion()
            
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
