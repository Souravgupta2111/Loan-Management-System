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
        let applications: [LoanApplication] = try await supabase.database
            .from("loan_applications")
            .select()
            .eq("assigned_officer_id", value: officerId)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return try await populateApplications(applications)
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
    
    /// Updates the application status and notes down rejection/send-back remarks.
    func updateStatus(applicationId: UUID, status: ApplicationStatus, reason: String? = nil) async throws {
        var updateDict: [String: String] = ["status": status.rawValue]
        
        if status == .rejected {
            updateDict["rejection_reason"] = reason ?? "Rejected by credit guidelines"
            updateDict["decided_at"] = ISO8601DateFormatter().string(from: Date())
        } else if status == .sentBack {
            updateDict["sent_back_reason"] = reason ?? "Requested additional details"
        } else if status == .approved {
            updateDict["decided_at"] = ISO8601DateFormatter().string(from: Date())
        }
        
        try await supabase.database
            .from("loan_applications")
            .update(updateDict)
            .eq("id", value: applicationId)
            .execute()
        
        // Log action in approval history
        try await addApprovalHistory(
            applicationId: applicationId,
            action: status.rawValue.uppercased(),
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
    
    /// Adds a record to the `approval_history` table for this application.
    func addApprovalHistory(applicationId: UUID, action: String, remarks: String?) async throws {
        guard let currentUserId = supabase.currentUserId else { return }
        
        let payload: [String: AnyEncodable] = [
            "application_id": AnyEncodable(applicationId),
            "staff_id": AnyEncodable(currentUserId),
            "action": AnyEncodable(action),
            "remarks": AnyEncodable(remarks ?? "")
        ]
        
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
        
        try await addApprovalHistory(
            applicationId: applicationId,
            action: "REQUEST_DOCUMENTS",
            remarks: "Requested: \(documentTypes.joined(separator: ", ")). Notes: \(remarks)"
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
