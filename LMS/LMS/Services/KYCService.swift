import Foundation
import Supabase

struct PANVerificationResponse: Codable {
    let pan: String
    let status: String
    let nameAsPerPanMatch: Bool
    let dateOfBirthMatch: Bool

    enum CodingKeys: String, CodingKey {
        case pan, status
        case nameAsPerPanMatch = "name_as_per_pan_match"
        case dateOfBirthMatch = "date_of_birth_match"
    }
}

struct AadhaarOTPResponse: Codable {
    let success: Bool
    let referenceId: String?
    let message: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success
        case referenceId = "reference_id"
        case message, error
    }
}

struct AadhaarAddress: Codable {
    let house: String?
    let street: String?
    let landmark: String?
    let loc: String?
    let po: String?
    let dist: String?
    let state: String?
    let pc: String?
}

struct AadhaarVerifyOTPResponse: Codable {
    let success: Bool
    let status: String?
    let name: String?
    let aadhaarLastFour: String?
    let dob: String?
    let gender: String?
    let address: AadhaarAddress?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success, status, name, error, dob, gender, address
        case aadhaarLastFour = "aadhaar_last_four"
    }
}

@MainActor
class KYCService {
    static let shared = KYCService()
    
    private init() {}
    
    /// Invokes the authenticated Edge Function so KYC credentials never ship in the app.
    func verifyPAN(_ pan: String, name: String, dob: String) async throws -> PANVerificationResponse {
        struct Request: Encodable { let pan: String; let name: String; let dateOfBirth: String }
        return try await SupabaseManager.shared.client.functions.invoke(
            "verify-pan",
            options: FunctionInvokeOptions(body: Request(pan: pan, name: name, dateOfBirth: dob))
        )
    }

    /// Step 1: Send OTP to user's Aadhaar-linked mobile
    func generateAadhaarOTP(_ aadhaar: String) async throws -> AadhaarOTPResponse {
        struct Request: Encodable { let action: String; let aadhaar: String }
        return try await SupabaseManager.shared.client.functions.invoke(
            "verify-aadhaar",
            options: FunctionInvokeOptions(body: Request(action: "generate_otp", aadhaar: aadhaar))
        )
    }

    /// Step 2: Verify the OTP and complete e-KYC
    func verifyAadhaarOTP(referenceId: String, otp: String) async throws -> AadhaarVerifyOTPResponse {
        struct Request: Encodable { let action: String; let reference_id: String; let otp: String }
        return try await SupabaseManager.shared.client.functions.invoke(
            "verify-aadhaar",
            options: FunctionInvokeOptions(body: Request(action: "verify_otp", reference_id: referenceId, otp: otp))
        )
    }
    
    /// Uploads documents to Supabase storage
    func uploadDocument(data: Data, type: String, userId: String) async throws -> String {
        let filePath = "\(userId.lowercased())/\(type)_\(UUID().uuidString.lowercased()).jpg"
        
        try await SupabaseManager.shared.client.storage
            .from("documents")
            .upload(
                path: filePath,
                file: data,
                options: FileOptions(contentType: "image/jpeg")
            )
        
        return filePath
    }
    
    /// Updates the KYC status in the database, inserting the profile if it doesn't exist
    func updateKYCStatus(userId: UUID, status: String) async throws {
        struct ProfileRow: Decodable {
            let user_id: UUID
            enum CodingKeys: String, CodingKey {
                case user_id = "user_id"
            }
        }
        
        let existing: [ProfileRow] = try await SupabaseManager.shared.client
            .from("borrower_profiles")
            .select("user_id")
            .eq("user_id", value: userId)
            .execute()
            .value
            
        if existing.isEmpty {
            struct KYCInsert: Encodable {
                let user_id: UUID
                let kyc_status: String
            }
            try await SupabaseManager.shared.client
                .from("borrower_profiles")
                .insert(KYCInsert(user_id: userId, kyc_status: status))
                .execute()
        } else {
            struct KYCUpdate: Encodable {
                let kyc_status: String
            }
            try await SupabaseManager.shared.client
                .from("borrower_profiles")
                .update(KYCUpdate(kyc_status: status))
                .eq("user_id", value: userId)
                .execute()
        }
    }

    func recordDocument(userId: UUID, type: String, storagePath: String, byteCount: Int) async throws {
        struct DocumentInsert: Encodable {
            let owner_id: UUID
            let owner_type: String
            let document_type: String
            let category: String
            let file_name: String
            let storage_bucket: String
            let storage_path: String
            let file_size_bytes: Int
            let mime_type: String
        }
        try await SupabaseManager.shared.client.from("documents").insert(DocumentInsert(
            owner_id: userId, owner_type: "borrower", document_type: type, category: "kyc",
            file_name: storagePath.split(separator: "/").last.map(String.init) ?? type,
            storage_bucket: "documents", storage_path: storagePath,
            file_size_bytes: byteCount, mime_type: "image/jpeg"
        )).execute()
    }

    /// Submission temporarily marks as verified for testing
    func submitFullKYCDocs(
        userId: UUID,
        aadhaar: String,
        pan: String,
        dob: String?,
        gender: String?,
        addressLine1: String?,
        addressLine2: String?,
        city: String?,
        state: String?,
        pincode: String?,
        fullName: String
    ) async throws {
        // Normalize gender for Postgres ENUM ('male', 'female', 'other')
        let normalizedGender: String?
        if let g = gender?.lowercased() {
            if g.hasPrefix("m") {
                normalizedGender = "male"
            } else if g.hasPrefix("f") {
                normalizedGender = "female"
            } else {
                normalizedGender = "other"
            }
        } else {
            normalizedGender = nil
        }

        // Normalize DOB for Postgres DATE (YYYY-MM-DD)
        var formattedDOB: String? = nil
        if let dobStr = dob {
            if dobStr.contains("/") {
                let parts = dobStr.split(separator: "/")
                if parts.count == 3 {
                    let day = parts[0]
                    let month = parts[1]
                    let year = parts[2]
                    formattedDOB = "\(year)-\(month)-\(day)"
                }
            } else {
                // If it's already YYYY-MM-DD or other separator
                formattedDOB = dobStr
            }
        }

        // 1. Update full name in users table
        struct UserUpdate: Encodable {
            let full_name: String
        }
        try await SupabaseManager.shared.client
            .from("users")
            .update(UserUpdate(full_name: fullName))
            .eq("id", value: userId)
            .execute()

        // 2. Update borrower profile with all extracted demographic details
        struct FullKYCUpdate: Encodable {
            let aadhaar_number: String
            let pan_number: String
            let date_of_birth: String?
            let gender: String?
            let address_line1: String?
            let address_line2: String?
            let city: String?
            let state: String?
            let pincode: String?
            let kyc_status: String
            let kyc_submitted_at: String
        }
        
        let now = Formatter.iso8601.string(from: Date())
        
        try await SupabaseManager.shared.client
            .from("borrower_profiles")
            .update(FullKYCUpdate(
                aadhaar_number: aadhaar,
                pan_number: pan,
                date_of_birth: formattedDOB,
                gender: normalizedGender,
                address_line1: addressLine1,
                address_line2: addressLine2,
                city: city,
                state: state,
                pincode: pincode,
                kyc_status: "submitted",
                kyc_submitted_at: now
            ))
            .eq("user_id", value: userId)
            .execute()
    }
    
    func resubmitDocument(userId: UUID, type: String, data: Data) async throws {
        // 1. Upload new document
        let storagePath = try await uploadDocument(data: data, type: type, userId: userId.uuidString)
        
        // 2. Update the existing document
        struct DocumentUpdate: Encodable {
            let storage_path: String
            let file_size_bytes: Int
            let file_name: String
            let is_verified: Bool
        }
        
        try await SupabaseManager.shared.client.from("documents")
            .update(DocumentUpdate(
                storage_path: storagePath,
                file_size_bytes: data.count,
                file_name: storagePath.split(separator: "/").last.map(String.init) ?? type,
                is_verified: false
            ))
            .eq("owner_id", value: userId)
            .eq("document_type", value: type)
            .eq("category", value: "kyc")
            .execute()
        
        // Clear rejection reason using raw dictionary to avoid needing Optional struct wrappers that PostgREST might skip
        let clearRejection: [String: AnyJSON] = ["rejection_reason": .null, "verified_by": .null, "verified_at": .null]
        try await SupabaseManager.shared.client.from("documents")
            .update(clearRejection)
            .eq("owner_id", value: userId)
            .eq("document_type", value: type)
            .eq("category", value: "kyc")
            .execute()
        
        // 3. Update KYC status to submitted so it goes back to review
        try await updateKYCStatus(userId: userId, status: "submitted")
    }
}

extension Formatter {
    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
