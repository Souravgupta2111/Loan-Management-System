import Foundation
import Supabase

class DocumentService {
    
    static let shared = DocumentService()
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    func fetchDocuments(forApplicationId applicationId: UUID) async throws -> [LMSDocument] {
        let documents: [LMSDocument] = try await supabase.database
            .from("documents")
            .select()
            .eq("application_id", value: applicationId)
            .execute()
            .value
        return documents
    }
    
    func verifyDocument(documentId: UUID, isVerified: Bool, rejectionReason: String? = nil) async throws {
        guard let staffId = supabase.currentUserId else { return }
        
        let nowString = ISO8601DateFormatter().string(from: Date())
        
        var updateDict: [String: AnyEncodable] = [
            "is_verified": AnyEncodable(isVerified),
            "verified_by": AnyEncodable(staffId.uuidString),
            "verified_at": AnyEncodable(nowString)
        ]
        
        if let reason = rejectionReason {
            updateDict["rejection_reason"] = AnyEncodable(reason)
        }
        
        try await supabase.database
            .from("documents")
            .update(updateDict)
            .eq("id", value: documentId)
            .execute()
        
        try await AuditService.shared.logAction(
            action: isVerified ? "VERIFY_DOCUMENT" : "REJECT_DOCUMENT",
            tableName: "documents",
            recordId: documentId,
            summary: isVerified ? "Verified document \(documentId)" : "Rejected document \(documentId): \(rejectionReason ?? "N/A")"
        )
    }
    
    func getSignedUrl(bucket: String, path: String) async throws -> URL {
        struct SignedURLResponse: Decodable {
            let signedURL: String
        }
        
        let url = try await supabase.storage
            .from(bucket)
            .createSignedURL(path: path, expiresIn: 3600)
        
        return url
    }
    
    func uploadDocument(
        ownerId: UUID,
        ownerType: String = "borrower",
        applicationId: UUID?,
        category: DocumentCategory,
        documentType: String,
        fileName: String,
        fileData: Data,
        mimeType: String
    ) async throws -> LMSDocument {
        
        let fileExtension = (fileName as NSString).pathExtension
        let uniqueName = "\(UUID().uuidString).\(fileExtension)"
        let bucket = "documents"
        let storagePath = "\(ownerId.uuidString)/\(uniqueName)"
        
        _ = try await supabase.storage
            .from(bucket)
            .upload(
                path: storagePath,
                file: fileData,
                options: FileOptions(cacheControl: "3600", contentType: mimeType)
            )
        
        let insertPayload: [String: AnyEncodable] = [
            "owner_id": AnyEncodable(ownerId),
            "owner_type": AnyEncodable(ownerType),
            "application_id": AnyEncodable(applicationId?.uuidString ?? ""),
            "document_type": AnyEncodable(documentType),
            "category": AnyEncodable(category.rawValue),
            "file_name": AnyEncodable(fileName),
            "storage_bucket": AnyEncodable(bucket),
            "storage_path": AnyEncodable(storagePath),
            "file_size_bytes": AnyEncodable(Int64(fileData.count)),
            "mimeType": AnyEncodable(mimeType),
            "is_verified": AnyEncodable(false)
        ]
        
        let newDoc: LMSDocument = try await supabase.database
            .from("documents")
            .insert(insertPayload)
            .select()
            .single()
            .execute()
            .value
            
        return newDoc
    }
}
