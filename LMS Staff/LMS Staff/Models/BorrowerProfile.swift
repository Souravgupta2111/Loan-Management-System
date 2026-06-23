//
//  BorrowerProfile.swift
//  LMS
//
//  Data model for the `borrower_profiles` table.
//

import Foundation

// MARK: - Enums

enum KYCStatus: String, Codable, CaseIterable, Identifiable {
    case pending
    case submitted
    case verified
    case rejected

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pending:   return "Pending"
        case .submitted: return "Submitted"
        case .verified:  return "Verified"
        case .rejected:  return "Rejected"
        }
    }
}

enum Gender: String, Codable, CaseIterable, Identifiable {
    case male
    case female
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .male:   return "Male"
        case .female: return "Female"
        case .other:  return "Other"
        }
    }
}

enum EmploymentType: String, Codable, CaseIterable, Identifiable {
    case salaried
    case selfEmployed = "self_employed"
    case business
    case retired
    case unemployed
    case student

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .salaried:     return "Salaried"
        case .selfEmployed: return "Self Employed"
        case .business:     return "Business"
        case .retired:      return "Retired"
        case .unemployed:   return "Unemployed"
        case .student:      return "Student"
        }
    }
}

// MARK: - Borrower Profile Model

struct BorrowerProfile: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    var aadhaarNumber: String?
    var panNumber: String?
    var dateOfBirth: String?  // Date string from DB
    var gender: Gender?
    var addressLine1: String?
    var addressLine2: String?
    var city: String?
    var state: String?
    var pincode: String?
    var employmentType: EmploymentType?
    var monthlyIncome: Double?
    var creditScore: Int?
    var creditBureau: CreditBureauType?
    var kycStatus: KYCStatus
    var kycSubmittedAt: Date?
    var kycVerifiedAt: Date?
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case aadhaarNumber = "aadhaar_number"
        case panNumber = "pan_number"
        case dateOfBirth = "date_of_birth"
        case gender
        case addressLine1 = "address_line1"
        case addressLine2 = "address_line2"
        case city
        case state
        case pincode
        case employmentType = "employment_type"
        case monthlyIncome = "monthly_income"
        case creditScore = "credit_score"
        case creditBureau = "credit_bureau"
        case kycStatus = "kyc_status"
        case kycSubmittedAt = "kyc_submitted_at"
        case kycVerifiedAt = "kyc_verified_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
