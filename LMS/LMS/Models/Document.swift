//
//  Document.swift
//  LMS
//
//  Data model for the `documents` table.
//

import Foundation

// MARK: - Document Category Enum

enum DocumentCategory: String, Codable, CaseIterable, Identifiable {
    case kyc
    case income
    case collateral
    case loan
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kyc:        return "KYC"
        case .income:     return "Income Proof"
        case .collateral: return "Collateral"
        case .loan:       return "Loan Document"
        case .other:      return "Other"
        }
    }
}

// MARK: - Document Model

struct LMSDocument: Codable, Identifiable, Hashable {
    let id: UUID
    let ownerId: UUID
    var ownerType: String
    var applicationId: UUID?
    var documentType: String
    var category: DocumentCategory
    var fileName: String
    var fileUrl: String?
    var storageBucket: String?
    var storagePath: String?
    var fileSizeBytes: Int64?
    var mimeType: String?
    var isVerified: Bool
    var rejectionReason: String?
    var verifiedBy: UUID?
    var verifiedAt: Date?
    var expiryDate: String?
    var isExpired: Bool
    let uploadedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case ownerType = "owner_type"
        case applicationId = "application_id"
        case documentType = "document_type"
        case category
        case fileName = "file_name"
        case fileUrl = "file_url"
        case storageBucket = "storage_bucket"
        case storagePath = "storage_path"
        case fileSizeBytes = "file_size_bytes"
        case mimeType = "mime_type"
        case isVerified = "is_verified"
        case rejectionReason = "rejection_reason"
        case verifiedBy = "verified_by"
        case verifiedAt = "verified_at"
        case expiryDate = "expiry_date"
        case isExpired = "is_expired"
        case uploadedAt = "uploaded_at"
    }
}
