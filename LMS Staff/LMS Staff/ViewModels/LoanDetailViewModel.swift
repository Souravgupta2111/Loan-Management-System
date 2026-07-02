//
//  LoanDetailViewModel.swift
//  LMS Staff
//
//  ViewModel for managing the unified Loan Inspector View.
//

import Foundation
import SwiftUI
import Supabase
import Combine

@MainActor
class LoanDetailViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var loanWithDetails: LoanWithDetails
    @Published var borrowerProfile: BorrowerProfile?
    @Published var application: LoanApplication?
    @Published var appWithBorrower: ApplicationWithBorrower?
    
    @Published var documents: [LMSDocument] = []
    @Published var timelineItems: [StaffTimelineView.TimelineItem] = []
    @Published var emiSchedule: [EMIScheduleItem] = []
    @Published var payments: [Payment] = []
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let documentService = DocumentService.shared
    private let portfolioService = LoanPortfolioService.shared
    private let supabase = SupabaseManager.shared
    
    init(loanWithDetails: LoanWithDetails) {
        self.loanWithDetails = loanWithDetails
    }
    
    // MARK: - Load Details
    
    func loadAllDetails() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 1. Fetch Borrower Profile
            let profiles: [BorrowerProfile] = try await supabase.database
                .from("borrower_profiles")
                .select()
                .eq("user_id", value: loanWithDetails.borrower.id)
                .execute()
                .value
            self.borrowerProfile = profiles.first
            
            // 2. Fetch Application
            let app: LoanApplication = try await supabase.database
                .from("loan_applications")
                .select()
                .eq("id", value: loanWithDetails.loan.applicationId)
                .single()
                .execute()
                .value
            self.application = app
            
            // Construct ApplicationWithBorrower for Chat Support
            self.appWithBorrower = ApplicationWithBorrower(
                application: app,
                borrower: loanWithDetails.borrower,
                profile: self.borrowerProfile,
                product: loanWithDetails.product
            )
            
            // 3. Fetch Documents
            self.documents = try await documentService.fetchDocuments(forApplicationId: app.id)
            
            // 4. Fetch Timeline (Approval History and Audit Logs)
            let logs: [ApprovalHistoryItem] = try await supabase.database
                .from("approval_history")
                .select()
                .eq("application_id", value: app.id)
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
                for user in users { actorsMap[user.id] = user }
            }
            
            // Add audit logs for NPA recovery actions
            let auditLogs: [AuditLog] = try await AuditService.shared.fetchAuditLogs(forRecordId: loanWithDetails.loan.id)
                
            let auditActorIds = Array(Set(auditLogs.compactMap { $0.actorId }))
            if !auditActorIds.isEmpty {
                let users: [AppUser] = try await supabase.database
                    .from("users")
                    .select()
                    .in("id", values: auditActorIds)
                    .execute()
                    .value
                for user in users { actorsMap[user.id] = user }
            }
            
            var allTimelineItems: [StaffTimelineView.TimelineItem] = []
            
            allTimelineItems.append(contentsOf: logs.map { log in
                let actorUser = actorsMap[log.actorId]
                let actorName = actorUser?.fullName ?? "System"
                let roleName = actorUser?.role.rawValue ?? "system"
                
                var icon = "clock"
                var color = Color.staffTextSecondary
                
                switch log.action {
                case .submit: icon = "paperplane.fill"; color = .staffAccent
                case .review: icon = "eye.fill"; color = .staffAmber
                case .approve: icon = "checkmark.circle.fill"; color = .staffGreen
                case .reject: icon = "xmark.circle.fill"; color = .staffRed
                case .sendBack: icon = "arrow.uturn.backward.circle.fill"; color = .staffOrange
                case .disburse: icon = "banknote.fill"; color = .staffAccent
                case .escalate: icon = "arrow.up.circle.fill"; color = .staffRed
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
            })
            
            allTimelineItems.append(contentsOf: auditLogs.map { log in
                let actorUser = log.actorId != nil ? actorsMap[log.actorId!] : nil
                let actorName = actorUser?.fullName ?? "System"
                let roleName = actorUser?.role.rawValue ?? "system"
                
                var icon = "doc.plaintext.fill"
                var color = Color.staffTextSecondary
                
                if log.action.contains("RESTRUCTURE") {
                    icon = "arrow.triangle.2.circlepath"
                    color = .staffAmber
                } else if log.action.contains("WRITE_OFF") {
                    icon = "xmark.seal.fill"
                    color = .staffRed
                } else if log.action.contains("ESCALATE") {
                    icon = "exclamationmark.triangle.fill"
                    color = .staffRed
                }
                
                return StaffTimelineView.TimelineItem(
                    id: log.id,
                    action: log.action,
                    actor: actorName,
                    role: roleName,
                    remarks: log.changeSummary ?? "",
                    timestamp: log.createdAt ?? Date(),
                    icon: icon,
                    color: color
                )
            })
            
            self.timelineItems = allTimelineItems.sorted(by: { $0.timestamp > $1.timestamp })
            
            // 5. Fetch EMI Schedule and Payments
            self.emiSchedule = try await portfolioService.fetchEMISchedule(forLoanId: loanWithDetails.loan.id)
            self.payments = try await portfolioService.fetchPayments(forLoanId: loanWithDetails.loan.id)
            
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Document Actions
    
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
}
