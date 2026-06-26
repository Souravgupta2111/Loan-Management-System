import Foundation
import Supabase

@MainActor
class LoanService {
    static let shared = LoanService()
    
    private init() {}
    
    /// Fetches all active loan products from the database
    func fetchActiveProducts() async throws -> [LoanProduct] {
        return try await SupabaseManager.shared.client
            .from("loan_products")
            .select()
            .eq("is_active", value: true)
            .execute()
            .value
    }
    
    /// Submits a new loan application and uploads associated documents
    func submitApplication(
        userId: UUID,
        productId: UUID,
        amount: Double,
        tenure: Int,
        purpose: String? = nil,
        documents: [String: Data]
    ) async throws -> String {
        struct KYCRow: Decodable { let kyc_status: String }
        let kyc: [KYCRow] = try await SupabaseManager.shared.client
            .from("borrower_profiles").select("kyc_status")
            .eq("user_id", value: userId).execute().value
        guard kyc.first?.kyc_status == "verified" else {
            throw LoanSubmissionError.kycNotVerified
        }

        struct ApplicationInsert: Encodable {
            let borrower_id: UUID
            let loan_product_id: UUID
            let requested_amount: Double
            let requested_tenure_months: Int
            let purpose: String?
            let status: String
        }
        
        let application = ApplicationInsert(
            borrower_id: userId,
            loan_product_id: productId,
            requested_amount: amount,
            requested_tenure_months: tenure,
            purpose: purpose,
            status: "draft"
        )

        struct ApplicationRow: Decodable { let id: UUID; let application_number: String }
        let created: ApplicationRow = try await SupabaseManager.shared.client
            .from("loan_applications")
            .insert(application)
            .select("id, application_number")
            .single()
            .execute()
            .value

        for (documentType, data) in documents {
            let safeType = documentType.lowercased().replacingOccurrences(
                of: "[^a-z0-9]+", with: "_", options: .regularExpression
            )
            let path = "\(userId.uuidString.lowercased())/applications/\(created.id.uuidString.lowercased())/\(safeType)_\(UUID().uuidString.lowercased()).jpg"
            try await SupabaseManager.shared.client.storage.from("documents").upload(
                path: path, file: data, options: FileOptions(contentType: "image/jpeg")
            )
            struct DocumentInsert: Encodable {
                let owner_id: UUID; let owner_type: String; let application_id: UUID
                let document_type: String; let category: String; let file_name: String
                let storage_bucket: String; let storage_path: String
                let file_size_bytes: Int; let mime_type: String
            }
            try await SupabaseManager.shared.client.from("documents").insert(DocumentInsert(
                owner_id: userId, owner_type: "application", application_id: created.id,
                document_type: documentType, category: "loan",
                file_name: path.split(separator: "/").last.map(String.init) ?? safeType,
                storage_bucket: "documents", storage_path: path,
                file_size_bytes: data.count, mime_type: "image/jpeg"
            )).execute()
        }

        struct SubmissionUpdate: Encodable { let status: String; let submitted_at: String }
        try await SupabaseManager.shared.client.from("loan_applications")
            .update(SubmissionUpdate(status: "submitted", submitted_at: Formatter.iso8601.string(from: Date())))
            .eq("id", value: created.id).eq("status", value: "draft").execute()

        return created.application_number
    }
    
    /// Fetches the user's loans from the database
    func fetchUserLoans(userId: UUID) async throws -> [LoanSummary] {
        struct SupabaseLoanResponse: Decodable {
            let id: UUID
            let outstanding_principal: Double
            let total_payable: Double
            let status: String
            let loan_product: ProductSummary
            let emi_schedule: [EMISummary]
            
            struct ProductSummary: Decodable {
                let name: String
                let type: String
            }
            struct EMISummary: Decodable {
                let total_emi: Double
                let status: String
                let due_date: String
            }
        }
        
        let response: [SupabaseLoanResponse] = try await SupabaseManager.shared.client
            .from("loans")
            .select("id, outstanding_principal, total_payable, status, loan_product:loan_products(name, type), emi_schedule(total_emi, status, due_date)")
            .eq("borrower_id", value: userId.uuidString)
            .execute()
            .value
            
        return response.map { loan in
            let paidPercent = loan.total_payable > 0 ? (1.0 - (loan.outstanding_principal / loan.total_payable)) : 0.0
            let nextEMI = loan.emi_schedule
                .filter { $0.status != "paid" }
                .sorted { $0.due_date < $1.due_date }
                .first?.total_emi ?? 0
            return LoanSummary(
                id: loan.id,
                name: loan.loan_product.name,
                loanType: loan.loan_product.type,
                outstandingAmount: loan.outstanding_principal,
                emiAmount: nextEMI,
                status: loan.status,
                paidPercent: paidPercent,
                changePercent: 0.0
            )
        }
    }
    
    /// Fetches the user's detailed loans for the list view
    func fetchDetailedUserLoans(userId: UUID) async throws -> [LoanListItem] {
        struct SupabaseDetailedLoanResponse: Decodable {
            let id: UUID
            let loan_number: String?
            let principal_amount: Double
            let outstanding_principal: Double
            let total_payable: Double
            let interest_rate: Double
            let status: String
            let disbursement_date: String?
            let loan_product: ProductSummary
            let emi_schedule: [EMISummary]
            
            struct ProductSummary: Decodable {
                let name: String
                let type: String
            }
            struct EMISummary: Decodable {
                let total_emi: Double
                let status: String
                let due_date: String
            }
        }
        
        let response: [SupabaseDetailedLoanResponse] = try await SupabaseManager.shared.client
            .from("loans")
            .select("id, loan_number, principal_amount, outstanding_principal, total_payable, interest_rate, status, disbursement_date, loan_product:loan_products(name, type), emi_schedule(total_emi, status, due_date)")
            .eq("borrower_id", value: userId.uuidString)
            .execute()
            .value
            
        return response.map { loan in
            let paidPercent = loan.total_payable > 0 ? (1.0 - (loan.outstanding_principal / loan.total_payable)) : 0.0
            let paidAmount = loan.total_payable - loan.outstanding_principal
            let nextEMI = loan.emi_schedule
                .filter { $0.status != "paid" }
                .sorted { $0.due_date < $1.due_date }
                .first?.total_emi ?? 0
            return LoanListItem(
                id: loan.id,
                name: loan.loan_product.name,
                loanType: loan.loan_product.type,
                loanNumber: loan.loan_number ?? "N/A",
                amount: loan.principal_amount,
                emiAmount: nextEMI,
                status: loan.status,
                paidPercent: paidPercent,
                interestRate: loan.interest_rate,
                disbursedDate: loan.disbursement_date ?? "N/A",
                paidAmount: paidAmount > 0 ? paidAmount : 0,
                remainingAmount: loan.outstanding_principal
            )
        }
    }
    
    // MARK: - Applications
    
    struct ApplicationListItem: Identifiable {
        let id: UUID
        let applicationNumber: String
        let loanType: String
        let amount: Double
        let status: String
        let submittedAt: String
        let rejectionReason: String?
        let sentBackReason: String?
        let officerId: UUID?
    }
    
    func fetchUserApplications(userId: UUID) async throws -> [ApplicationListItem] {
        struct AppRow: Decodable {
            let id: UUID
            let application_number: String?
            let requested_amount: Double
            let status: String
            let submitted_at: String?
            let rejection_reason: String?
            let sent_back_reason: String?
            let assigned_officer_id: UUID?
            let loan_product: ProductRow
            
            struct ProductRow: Decodable { let name: String; let type: String }
        }
        
        let rows: [AppRow] = try await SupabaseManager.shared.client
            .from("loan_applications")
            .select("id, application_number, requested_amount, status, submitted_at, rejection_reason, sent_back_reason, assigned_officer_id, loan_product:loan_products(name, type)")
            .eq("borrower_id", value: userId)
            .order("last_updated_at", ascending: false)
            .execute().value
            
        return rows.map {
            ApplicationListItem(
                id: $0.id, applicationNumber: $0.application_number ?? "Draft",
                loanType: $0.loan_product.name, amount: $0.requested_amount,
                status: $0.status,
                submittedAt: displayDate($0.submitted_at ?? ""),
                rejectionReason: $0.rejection_reason,
                sentBackReason: $0.sent_back_reason,
                officerId: $0.assigned_officer_id
            )
        }
    }
    
    func resubmitApplication(applicationId: UUID, newDocuments: [String: Data], userId: UUID) async throws {
        // Upload any new documents provided
        for (docType, data) in newDocuments {
            let filePath = "\(userId.uuidString.lowercased())/\(docType)_\(UUID().uuidString.lowercased()).jpg"
            try await SupabaseManager.shared.client.storage
                .from("documents")
                .upload(path: filePath, file: data, options: FileOptions(contentType: "image/jpeg"))
            
            struct DocInsert: Encodable {
                let owner_id: UUID; let owner_type: String; let application_id: UUID
                let document_type: String; let category: String; let file_name: String
                let storage_bucket: String; let storage_path: String; let file_size_bytes: Int
                let mime_type: String
            }
            try await SupabaseManager.shared.client.from("documents").insert(DocInsert(
                owner_id: userId, owner_type: "application", application_id: applicationId,
                document_type: docType, category: "other",
                file_name: filePath.split(separator: "/").last.map(String.init) ?? docType,
                storage_bucket: "documents", storage_path: filePath,
                file_size_bytes: data.count, mime_type: "image/jpeg"
            )).execute()
        }
        
        // Update application status back to submitted
        struct AppUpdate: Encodable {
            let status: String
            let sent_back_reason: String?
        }
        try await SupabaseManager.shared.client.from("loan_applications")
            .update(AppUpdate(status: "submitted", sent_back_reason: nil))
            .eq("id", value: applicationId)
            .execute()
    }
    
    private func displayDate(_ value: String) -> String {
        guard let date = Formatter.iso8601.date(from: value) else { return value }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

enum LoanSubmissionError: LocalizedError {
    case kycNotVerified
    var errorDescription: String? { "Complete KYC verification before applying for a loan." }
}
