//
//  ApplicationService.swift
//  LMS Staff
//
//  Service for managing loan applications, assigned officers, and decisions.
//

import Foundation
import Supabase

struct ApplicationWithBorrower: Identifiable, Hashable {
    var id: UUID { application.id }
    let application: LoanApplication
    let borrower: AppUser
    let profile: BorrowerProfile?
    let product: LoanProduct
}

@MainActor
class ApplicationService {
    
    static let shared = ApplicationService()
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    /// Fetches all applications in the system, joining user, profile, and product data in-memory.
    func fetchAllApplications() async throws -> [ApplicationWithBorrower] {
        let applications: [LoanApplication] = try await supabase.database
            .from("loan_applications")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return try await populateApplications(applications)
    }
    
    /// Fetches applications assigned to a specific loan officer.
    func fetchApplications(forOfficerId officerId: UUID) async throws -> [ApplicationWithBorrower] {
        // Resolve staff_profiles.id (profileId) and users.id (userId)
        let staffProfile: StaffProfile? = try? await supabase.database
            .from("staff_profiles")
            .select()
            .or("id.eq.\(officerId.uuidString),user_id.eq.\(officerId.uuidString)")
            .single()
            .execute()
            .value
            
        let profileId = staffProfile?.id ?? officerId
        let userId = staffProfile?.userId ?? officerId

        // 1. Fetch applications directly assigned to officer or submitted
        let applications: [LoanApplication] = try await supabase.database
            .from("loan_applications")
            .select()
            .or("assigned_officer_id.eq.\(profileId.uuidString),status.eq.submitted")
            .order("created_at", ascending: false)
            .execute()
            .value
        
        // 2. Fetch applications officer previously actioned (e.g. recommended to manager)
        struct HistoryID: Codable {
            let application_id: UUID
        }
        
        let historyLogs: [HistoryID] = (try? await supabase.database
            .from("approval_history")
            .select("application_id")
            .eq("actor_id", value: userId)
            .execute()
            .value) ?? []
        let actionedAppIds = Array(Set(historyLogs.map { $0.application_id }))
        
        var allApps = applications
        if !actionedAppIds.isEmpty {
            let additionalApps: [LoanApplication] = try await supabase.database
                .from("loan_applications")
                .select()
                .in("id", values: actionedAppIds)
                .execute()
                .value
            
            var seenIds = Set(allApps.map { $0.id })
            for app in additionalApps {
                if !seenIds.contains(app.id) {
                    allApps.append(app)
                    seenIds.insert(app.id)
                }
            }
        }
        
        // Sort by created_at descending
        allApps.sort { ($0.createdAt ?? Date()) > ($1.createdAt ?? Date()) }
        
        return try await populateApplications(allApps)
    }
    
    /// Helper to join products, users, and borrower profiles in-memory.
    private func populateApplications(_ applications: [LoanApplication]) async throws -> [ApplicationWithBorrower] {
        if applications.isEmpty { return [] }
        
        // Fetch all products
        let products: [LoanProduct] = try await supabase.database
            .from("loan_products")
            .select()
            .execute()
            .value
        let productsMap = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        
        var populated: [ApplicationWithBorrower] = []
        
        for app in applications {
            guard let product = productsMap[app.loanProductId] else { continue }
            
            // Fetch borrower user details
            let borrower: AppUser = try await supabase.database
                .from("users")
                .select()
                .eq("id", value: app.borrowerId)
                .single()
                .execute()
                .value
            
            // Fetch borrower profile (could be nil if not created yet, though usually is)
            let profile: BorrowerProfile? = try? await supabase.database
                .from("borrower_profiles")
                .select()
                .eq("user_id", value: app.borrowerId)
                .single()
                .execute()
                .value
            
            populated.append(ApplicationWithBorrower(
                application: app,
                borrower: borrower,
                profile: profile,
                product: product
            ))
        }
        
        return populated
    }
    
    /// Assigns or updates the officer for a loan application.
    func assignOfficer(applicationId: UUID, officerId: UUID) async throws {
        let payload: [String: AnyEncodable] = [
            "assigned_officer_id": AnyEncodable(officerId),
            "status": AnyEncodable(ApplicationStatus.underReview.rawValue)
        ]
        try await supabase.database
            .from("loan_applications")
            .update(payload)
            .eq("id", value: applicationId)
            .execute()
        
        try await AuditService.shared.logAction(
            action: "ASSIGN_OFFICER",
            tableName: "loan_applications",
            recordId: applicationId,
            summary: "Assigned officer \(officerId) to application \(applicationId)"
        )
    }
    
    func updateStatus(applicationId: UUID, status: ApplicationStatus, reason: String? = nil, assignedOfficerId: UUID? = nil) async throws {
        var updateDict: [String: AnyEncodable] = ["status": AnyEncodable(status.rawValue)]
        
        if let officerId = assignedOfficerId {
            updateDict["assigned_officer_id"] = AnyEncodable(officerId)
        }
        
        if status == .rejected {
            updateDict["rejection_reason"] = AnyEncodable(reason ?? "Rejected by credit guidelines")
            updateDict["decided_at"] = AnyEncodable(ISO8601DateFormatter().string(from: Date()))
        } else if status == .sentBack {
            updateDict["sent_back_reason"] = AnyEncodable(reason ?? "Requested additional details")
        } else if status == .approved {
            updateDict["decided_at"] = AnyEncodable(ISO8601DateFormatter().string(from: Date()))
        }
        
        try await supabase.database
            .from("loan_applications")
            .update(updateDict)
            .eq("id", value: applicationId)
            .execute()
            
        // Fetch borrower ID and staff info to send notifications
        struct AppRecord: Decodable { 
            let borrower_id: UUID
            let branch_id: UUID?
            let assigned_officer_id: UUID?
        }
        
        if let record: AppRecord = try? await supabase.database
            .from("loan_applications")
            .select("borrower_id, branch_id, assigned_officer_id")
            .eq("id", value: applicationId)
            .single()
            .execute()
            .value {
            
            // Resolve Officer and Manager User IDs
            let allStaff = try? await StaffManagementService.shared.fetchStaff()
            let officerUserId = allStaff?.first(where: { $0.staff.id == record.assigned_officer_id })?.user.id
            var managerUserId: UUID? = nil
            if let branchId = record.branch_id {
                managerUserId = try? await StaffManagementService.shared.fetchBranchManager(branchId: branchId)?.id
            }
            
            if status == .underReview {
                if let managerId = managerUserId {
                    try? await NotificationService.shared.createNotification(
                        userId: managerId,
                        title: "New Application to Review",
                        message: "An application has been recommended for your review.",
                        type: .loanUpdate,
                        referenceId: applicationId,
                        referenceType: "loan_applications"
                    )
                }
            } else if status == .sentBack {
                if let officerId = officerUserId {
                    try? await NotificationService.shared.createNotification(
                        userId: officerId,
                        title: "Application Sent Back",
                        message: "Manager sent back an application for revision. Reason: \(reason ?? "Check details")",
                        type: .loanUpdate,
                        referenceId: applicationId,
                        referenceType: "loan_applications"
                    )
                }
            } else if status == .approved {
                try? await NotificationService.shared.createNotification(
                    userId: record.borrower_id,
                    title: "Loan Approved!",
                    message: "Congratulations! Your loan application has been approved.",
                    type: .general,
                    referenceId: applicationId,
                    referenceType: "loan_applications"
                )
                
                if let officerId = officerUserId {
                    try? await NotificationService.shared.createNotification(
                        userId: officerId,
                        title: "Application Approved",
                        message: "An application you recommended has been approved.",
                        type: .loanUpdate,
                        referenceId: applicationId,
                        referenceType: "loan_applications"
                    )
                }
            } else if status == .rejected {
                try? await NotificationService.shared.createNotification(
                    userId: record.borrower_id,
                    title: "Loan Application Update",
                    message: "Your loan application was rejected. Reason: \(reason ?? "Did not meet criteria")",
                    type: .loanUpdate,
                    referenceId: applicationId,
                    referenceType: "loan_applications"
                )
                
                if let officerId = officerUserId {
                    try? await NotificationService.shared.createNotification(
                        userId: officerId,
                        title: "Application Rejected",
                        message: "An application you recommended has been rejected.",
                        type: .loanUpdate,
                        referenceId: applicationId,
                        referenceType: "loan_applications"
                    )
                }
            }
        }
        
        var actionValue = ""
        switch status {
        case .underReview: actionValue = "escalate"
        case .approved: actionValue = "approve"
        case .rejected: actionValue = "reject"
        case .sentBack: actionValue = "send_back"
        case .disbursed: actionValue = "disburse"
        default: actionValue = "submit"
        }
        
        // Log action in approval history
        try await addApprovalHistory(
            applicationId: applicationId,
            action: actionValue,
            toStatus: status.rawValue,
            remarks: reason
        )
        
        // Log to audit log
        try await AuditService.shared.logAction(
            action: "UPDATE_STATUS_\(status.rawValue.uppercased())",
            tableName: "loan_applications",
            recordId: applicationId,
            summary: "Updated status of \(applicationId) to \(status.rawValue): \(reason ?? "N/A")"
        )
    }
    
    func addApprovalHistory(
        applicationId: UUID, 
        action: String, 
        toStatus: String, 
        remarks: String?,
        approvedAmount: Double? = nil,
        approvedTenure: Int? = nil,
        approvedRate: Double? = nil
    ) async throws {
        guard let currentUserId = supabase.currentUserId else { return }
        
        var payload: [String: AnyEncodable] = [
            "application_id": AnyEncodable(applicationId),
            "actor_id": AnyEncodable(currentUserId),
            "action": AnyEncodable(action),
            "to_status": AnyEncodable(toStatus),
            "remarks": AnyEncodable(remarks ?? "")
        ]
        
        if let amt = approvedAmount {
            payload["approved_amount"] = AnyEncodable(amt)
        }
        if let tenure = approvedTenure {
            payload["approved_tenure_months"] = AnyEncodable(tenure)
        }
        if let rate = approvedRate {
            payload["approved_interest_rate"] = AnyEncodable(rate)
        }
        
        try await supabase.database
            .from("approval_history")
            .insert(payload)
            .execute()
    }
    
    /// Requests documents from the borrower (KYC, income slips, etc.).
    func requestDocuments(applicationId: UUID, borrowerId: UUID, documentTypes: [String], remarks: String) async throws {
        for type in documentTypes {
            let docPayload: [String: AnyEncodable] = [
                "borrower_id": AnyEncodable(borrowerId),
                "application_id": AnyEncodable(applicationId),
                "name": AnyEncodable(type),
                "file_type": AnyEncodable("PDF"),
                "status": AnyEncodable("pending"),
                "remarks": AnyEncodable(remarks)
            ]
            
            try await supabase.database
                .from("documents")
                .insert(docPayload)
                .execute()
        }
        
        // Notify Borrower
        try await NotificationService.shared.createNotification(
            userId: borrowerId,
            title: "Documents Requested",
            message: "A loan officer has requested: \(documentTypes.joined(separator: ", ")). Remarks: \(remarks)"
        )
        
        try await AuditService.shared.logAction(
            action: "REQUEST_DOCUMENTS",
            tableName: "loan_applications",
            recordId: applicationId,
            summary: "Requested: \(documentTypes.joined(separator: ", ")). Notes: \(remarks)"
        )
    }
}

// MARK: - Encodable Wrapper for arbitrary Dictionary insertions
struct AnyEncodable: Encodable {
    private let encode: (Encoder) throws -> Void
    
    init<T: Encodable>(_ value: T) {
        self.encode = value.encode
    }
    
    func encode(to encoder: Encoder) throws {
        try encode(encoder)
    }
}
