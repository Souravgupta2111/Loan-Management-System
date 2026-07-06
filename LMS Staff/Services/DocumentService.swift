//
//  DocumentService.swift
//  LMS Staff
//
//  Service for managing document uploads, downloads, and verifications.
//

import Foundation
import Supabase

class DocumentService {
    
    static let shared = DocumentService()
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    /// Fetches all documents uploaded for a specific loan application
    func fetchDocuments(forApplicationId applicationId: UUID) async throws -> [LMSDocument] {
        let documents: [LMSDocument] = try await supabase.database
            .from("documents")
            .select()
            .eq("application_id", value: applicationId)
            .execute()
            .value
        return documents
    }
    
    /// Verifies or rejects a document with remarks/reason
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
        
        // Log action to audit log
        try await AuditService.shared.logAction(
            action: isVerified ? "VERIFY_DOCUMENT" : "REJECT_DOCUMENT",
            tableName: "documents",
            recordId: documentId,
            summary: isVerified ? "Verified document \(documentId)" : "Rejected document \(documentId): \(rejectionReason ?? "N/A")"
        )
    }
    
    /// Generates a temporary signed URL for displaying a document from Supabase Storage
    func getSignedUrl(bucket: String, path: String) async throws -> URL {
        struct SignedURLResponse: Decodable {
            let signedURL: String
        }
        
        // Supabase Swift client supports download/getSignedURL directly:
        let url = try await supabase.storage
            .from(bucket)
            .createSignedURL(path: path, expiresIn: 3600)
        
        return url
    }
    
    /// Uploads a file (e.g. PDF sanction letter) to Supabase Storage and records it in database
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
        
        // Upload to storage bucket
        _ = try await supabase.storage
            .from(bucket)
            .upload(
                path: storagePath,
                file: fileData,
                options: FileOptions(cacheControl: "3600", contentType: mimeType)
            )
        
        // Insert DB record
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
