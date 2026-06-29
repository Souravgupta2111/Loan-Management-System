import Foundation
import Supabase

extension Notification.Name {
    static let loanDataDidChange = Notification.Name("loanDataDidChange")
}

@MainActor
class LoanService {
    static let shared = LoanService()
    
    private init() {}
    
    /// Fetches all active loan products from the database
    func fetchActiveProducts(for type: LoanType? = nil) async throws -> [LoanProduct] {
        var query = SupabaseManager.shared.client
            .from("loan_products")
            .select()
            .eq("is_active", value: true)

        if let type {
            query = query.eq("type", value: type.rawValue)
        }

        return try await query.execute().value
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

        NotificationCenter.default.post(name: .loanDataDidChange, object: nil)
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
            let paidAmount = loan.emi_schedule.filter { $0.status.lowercased() == "paid" }.map { $0.total_emi }.reduce(0, +)
            let paidPercent = loan.total_payable > 0 ? (paidAmount / loan.total_payable) : 0.0
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
        struct HistoryRow: Decodable {
            let action: String
            let actioned_at: String
            let remarks: String?
            let to_status: String
            let approved_interest_rate: Double?
        }
        
        struct DocumentRow: Decodable {
            let document_type: String
            let file_name: String
            let uploaded_at: String
            let category: String
            let storage_path: String
        }
        
        struct ApplicationData: Decodable {
            let id: UUID
            let requested_tenure_months: Int?
            let submitted_at: String?
            let approval_history: [HistoryRow]
            let documents: [DocumentRow]
        }
        
        let mapTimeline: ([HistoryRow], String?) -> [LoanTimelineEvent] = { history, submittedAt in
            var events = history.sorted { $0.actioned_at < $1.actioned_at }.map { h in
                let date = self.displayDate(h.actioned_at)
                let title: String
                switch h.action.lowercased() {
                case "submit": title = "Applied"
                case "review": title = "Under Review"
                case "approve": title = h.to_status == "approved" ? "Approved by Manager" : "Approved by Loan Officer"
                case "reject": title = "Rejected"
                case "send_back": title = "Sent Back"
                case "disburse": title = "Disbursed"
                default: title = h.action.capitalized
                }
                return LoanTimelineEvent(title: title, date: date, remarks: h.remarks)
            }
            if !events.contains(where: { $0.title == "Applied" }), let submittedAt = submittedAt {
                events.insert(LoanTimelineEvent(title: "Applied", date: self.displayDate(submittedAt), remarks: nil), at: 0)
            }
            return events
        }
        
        let mapDocuments: ([DocumentRow]) -> [LoanDocumentEvent] = { docs in
            return docs.sorted { $0.uploaded_at < $1.uploaded_at }.map { d in
                let date = self.displayDate(d.uploaded_at)
                let icon: String
                switch d.category.lowercased() {
                case "kyc": icon = "person.text.rectangle.fill"
                case "income": icon = "indianrupeesign.circle.fill"
                case "loan": icon = "doc.text.fill"
                default: icon = "doc.fill"
                }
                return LoanDocumentEvent(
                    title: d.document_type.capitalized.replacingOccurrences(of: "_", with: " "),
                    documentType: d.document_type,
                    category: d.category,
                    storagePath: d.storage_path,
                    uploadDate: "Uploaded \(date)",
                    icon: icon
                )
            }
        }
        
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
            let loan_applications: ApplicationData?
            
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

        struct ApplicationRow: Decodable {
            let id: UUID
            let application_number: String?
            let requested_amount: Double
            let requested_tenure_months: Int
            let status: String
            let submitted_at: String?
            let loan_product: ProductSummary
            let approval_history: [HistoryRow]
            let documents: [DocumentRow]

            struct ProductSummary: Decodable {
                let name: String
                let type: String
                let min_interest_rate: Double?
                let max_interest_rate: Double?
            }
        }

        let response: [SupabaseDetailedLoanResponse] = try await SupabaseManager.shared.client
            .from("loans")
            .select("id, loan_number, principal_amount, outstanding_principal, total_payable, interest_rate, status, disbursement_date, loan_product:loan_products(name, type), emi_schedule(total_emi, status, due_date), loan_applications(id, requested_tenure_months, submitted_at, approval_history(action, actioned_at, remarks, to_status, approved_interest_rate), documents(document_type, file_name, uploaded_at, category, storage_path))")
            .eq("borrower_id", value: userId.uuidString)
            .execute()
            .value

        let disbursedLoans = response.map { loan in
            let paidAmount = loan.emi_schedule.filter { $0.status.lowercased() == "paid" }.map { $0.total_emi }.reduce(0, +)
            let paidPercent = loan.total_payable > 0 ? (paidAmount / loan.total_payable) : 0.0
            let nextEMI = loan.emi_schedule
                .filter { $0.status != "paid" }
                .sorted { $0.due_date < $1.due_date }
                .first
                
            let emiSchedule = loan.emi_schedule.map { emi in
                LoanListItemEMI(amount: emi.total_emi, status: emi.status, dueDate: emi.due_date)
            }.sorted { $0.dueDate < $1.dueDate }

            let timeline = loan.loan_applications.map { mapTimeline($0.approval_history, $0.submitted_at) } ?? []
            let documents = loan.loan_applications.map { mapDocuments($0.documents) } ?? []

            return LoanListItem(
                id: loan.id,
                applicationId: loan.loan_applications?.id,
                name: loan.loan_product.name,
                loanType: loan.loan_product.type,
                loanNumber: loan.loan_number ?? "N/A",
                amount: loan.principal_amount,
                emiAmount: nextEMI?.total_emi ?? 0,
                status: loan.status,
                paidPercent: paidPercent,
                interestRate: loan.interest_rate,
                disbursedDate: loan.disbursement_date ?? "N/A",
                nextDueDate: nextEMI?.due_date,
                paidAmount: paidAmount > 0 ? paidAmount : 0,
                remainingAmount: loan.outstanding_principal,
                requestedTenure: loan.loan_applications?.requested_tenure_months,
                emiSchedule: emiSchedule,
                timeline: timeline,
                documents: documents
            )
        }

        let applications: [ApplicationRow] = try await SupabaseManager.shared.client
            .from("loan_applications")
            .select("id, application_number, requested_amount, requested_tenure_months, status, submitted_at, loan_product:loan_products(name, type, min_interest_rate, max_interest_rate), approval_history(action, actioned_at, remarks, to_status, approved_interest_rate), documents(document_type, file_name, uploaded_at, category, storage_path)")
            .eq("borrower_id", value: userId)
            .in("status", values: ["draft", "submitted", "under_review", "sent_back", "approved"])
            .order("last_updated_at", ascending: false)
            .execute()
            .value

        let pendingApplications = applications
            .map { app in
                let approvedRate = app.approval_history.compactMap { $0.approved_interest_rate }.last
                let fallbackRate = app.loan_product.min_interest_rate ?? app.loan_product.max_interest_rate ?? 0
                
                return LoanListItem(
                    id: app.id,
                    applicationId: app.id,
                    name: app.loan_product.name,
                    loanType: app.loan_product.type,
                    loanNumber: app.application_number ?? "Draft application",
                    amount: app.requested_amount,
                    emiAmount: 0,
                    status: app.status,
                    paidPercent: 0,
                    interestRate: approvedRate ?? fallbackRate,
                    disbursedDate: displayDate(app.submitted_at ?? ""),
                    nextDueDate: nil,
                    paidAmount: 0,
                    remainingAmount: app.requested_amount,
                    requestedTenure: app.requested_tenure_months,
                    emiSchedule: nil,
                    timeline: mapTimeline(app.approval_history, app.submitted_at),
                    documents: mapDocuments(app.documents)
                )
            }

        return disbursedLoans + pendingApplications
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
    
    func uploadAdditionalDocument(applicationId: UUID, userId: UUID, data: Data, title: String) async throws {
        let safeTitle = title.lowercased().replacingOccurrences(of: "[^a-z0-9]+", with: "_", options: .regularExpression)
        let filePath = "\(userId.uuidString.lowercased())/applications/\(applicationId.uuidString.lowercased())/\(safeTitle)_\(UUID().uuidString.lowercased()).jpg"
        
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
            document_type: safeTitle, category: "other",
            file_name: filePath.split(separator: "/").last.map(String.init) ?? safeTitle,
            storage_bucket: "documents", storage_path: filePath,
            file_size_bytes: data.count, mime_type: "image/jpeg"
        )).execute()
    }
    
    private func displayDate(_ value: String) -> String {
        guard let date = Formatter.iso8601.date(from: value) else { return value }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func uploadDocument(path: String, data: Data) async throws {
        let maxAttempts = 5
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                try await directUpload(bucket: "documents", path: path, data: data)
                return
            } catch {
                lastError = error
                print("Document upload attempt \(attempt) failed: \(Self.describeUploadError(error))")
                guard attempt < maxAttempts, isRetryableUploadError(error) else {
                    throw LoanSubmissionError.documentUploadFailed(Self.describeUploadError(error))
                }

                // Exponential backoff: 1s, 2s, 4s, 8s
                let delay = UInt64(1) << UInt64(attempt - 1)
                try await Task.sleep(nanoseconds: delay * 1_000_000_000)
            }
        }

        throw LoanSubmissionError.documentUploadFailed(
            lastError.map(Self.describeUploadError) ?? "Upload did not complete."
        )
    }

    /// Direct HTTP upload to Supabase Storage REST API, bypassing the SDK's
    /// storage client which uses QUIC (HTTP/3) and fails on networks with
    /// small MTU (the 1362-byte UDP packets exceed the 1216-byte MSS).
    /// Each attempt uses a fresh ephemeral URLSession so that cached QUIC
    /// connection state is never reused.
    private func directUpload(bucket: String, path: String, data: Data) async throws {
        let supabaseURL = SupabaseManager.shared.baseURL
        let session = try await SupabaseManager.shared.client.auth.session

        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        guard let url = URL(string: "\(supabaseURL)/storage/v1/object/\(bucket)/\(encodedPath)") else {
            throw LoanSubmissionError.documentUploadFailed("Invalid storage upload URL for path: \(path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseManager.shared.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("false", forHTTPHeaderField: "x-upsert")
        request.timeoutInterval = 60

        // Use a fresh ephemeral session each time so iOS cannot reuse
        // cached QUIC connection state that causes "Message too long".
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        config.waitsForConnectivity = true
        config.httpAdditionalHeaders = ["Alt-Svc": "clear"]
        let uploadSession = URLSession(configuration: config)
        defer { uploadSession.invalidateAndCancel() }

        let (responseData, response) = try await uploadSession.upload(for: request, from: data)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            // 409 = object already exists, treat as success (duplicate upload)
            if code == 409 { return }

            let responseBody = String(data: responseData, encoding: .utf8) ?? "No response body"
            throw LoanSubmissionError.documentUploadFailed("Storage upload failed (\(code)): \(responseBody)")
        }
    }

    private static func describeUploadError(_ error: Error) -> String {
        if let submissionError = error as? LoanSubmissionError {
            switch submissionError {
            case .kycNotVerified:
                return submissionError.errorDescription ?? error.localizedDescription
            case .documentUploadFailed(let reason):
                return reason
            }
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return "Network upload failed (\(nsError.code)): \(nsError.localizedDescription)"
        }

        return error.localizedDescription
    }

    private func isRetryableUploadError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return [
                NSURLErrorNetworkConnectionLost,
                NSURLErrorTimedOut,
                NSURLErrorCannotConnectToHost,
                NSURLErrorNotConnectedToInternet,
                NSURLErrorSecureConnectionFailed,
                NSURLErrorDataNotAllowed
            ].contains(nsError.code)
        }

        let message = error.localizedDescription.lowercased()
        return message.contains("network connection was lost")
            || message.contains("timed out")
            || message.contains("connection reset")
            || message.contains("message too long")
    }
}

enum LoanSubmissionError: LocalizedError {
    case kycNotVerified
    case documentUploadFailed(String)

    var errorDescription: String? {
        switch self {
        case .kycNotVerified:
            return "Complete KYC verification before applying for a loan."
        case .documentUploadFailed(let reason):
            return "Document upload failed: \(reason)"
        }
    }
}
