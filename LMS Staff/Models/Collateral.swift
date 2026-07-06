//
//  Collateral.swift
//  LMS
//
//  Data model for the `collateral` table.
//

import Foundation

// MARK: - Collateral Status Enum

enum CollateralStatus: String, Codable, CaseIterable, Identifiable {
    case submitted
    case appraised
    case approved
    case released
    case seized

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .submitted: return "Submitted"
        case .appraised: return "Appraised"
        case .approved:  return "Approved"
        case .released:  return "Released"
        case .seized:    return "Seized"
        }
    }
}

// MARK: - Collateral Model

struct Collateral: Codable, Identifiable, Hashable {
    let id: UUID
    let applicationId: UUID
    var loanId: UUID?
    var collateralType: String
    var description: String?
    var estimatedValue: Double
    var appraisedValue: Double?
    var appraiserName: String?
    var appraiserLicense: String?
    var appraisalDate: String?
    var custodyReference: String?
    var status: CollateralStatus
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case applicationId = "application_id"
        case loanId = "loan_id"
        case collateralType = "collateral_type"
        case description
        case estimatedValue = "estimated_value"
        case appraisedValue = "appraised_value"
        case appraiserName = "appraiser_name"
        case appraiserLicense = "appraiser_license"
        case appraisalDate = "appraisal_date"
        case custodyReference = "custody_reference"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
