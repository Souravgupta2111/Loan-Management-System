//
//  LoanApplication.swift
//  LMS
//
//  Data model for the `loan_applications` table.
//

import Foundation

// MARK: - Application Status Enum

enum ApplicationStatus: String, Codable, CaseIterable, Identifiable {
    case draft
    case submitted
    case underReview = "under_review"
    case approved
    case rejected
    case sentBack = "sent_back"
    case pendingAcceptance = "pending_acceptance"
    case pendingDisbursal = "pending_disbursal"
    case disbursed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .draft:       return "Draft"
        case .submitted:   return "Submitted"
        case .underReview: return "Under Review"
        case .approved:    return "Approved"
        case .rejected:    return "Rejected"
        case .sentBack:    return "Sent Back"
        case .pendingAcceptance: return "Pending Acceptance"
        case .pendingDisbursal: return "Pending Disbursal"
        case .disbursed:   return "Disbursed"
        }
    }

    var officerDisplayName: String {
        switch self {
        case .submitted:   return "Under Review"
        case .underReview: return "Submitted"
        default:           return displayName
        }
    }

    var icon: String {
        switch self {
        case .draft:       return "doc.badge.clock"
        case .submitted:   return "paperplane.fill"
        case .underReview: return "eye.fill"
        case .approved:    return "checkmark.circle.fill"
        case .rejected:    return "xmark.circle.fill"
        case .sentBack:    return "arrow.uturn.backward.circle.fill"
        case .pendingAcceptance: return "signature"
        case .pendingDisbursal: return "banknote"
        case .disbursed:   return "banknote.fill"
        }
    }

    var colorName: String {
        switch self {
        case .draft:       return "gray"
        case .submitted:   return "blue"
        case .underReview: return "orange"
        case .approved:    return "green"
        case .rejected:    return "red"
        case .sentBack:    return "yellow"
        case .pendingAcceptance: return "purple"
        case .pendingDisbursal: return "teal"
        case .disbursed:   return "indigo"
        }
    }
}

// MARK: - Loan Application Model

struct LoanApplication: Codable, Identifiable, Hashable {
    let id: UUID
    var applicationNumber: String?
    let borrowerId: UUID
    var loanProductId: UUID
    var assignedOfficerId: UUID?
    var branchId: UUID?
    var requestedAmount: Double
    var requestedTenureMonths: Int
    var purpose: String?
    var collateralDescription: String?
    var status: ApplicationStatus
    var rejectionReason: String?
    var sentBackReason: String?
    var revisionCount: Int
    var submittedAt: Date?
    var lastUpdatedAt: Date?
    var decidedAt: Date?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case applicationNumber = "application_number"
        case borrowerId = "borrower_id"
        case loanProductId = "loan_product_id"
        case assignedOfficerId = "assigned_officer_id"
        case branchId = "branch_id"
        case requestedAmount = "requested_amount"
        case requestedTenureMonths = "requested_tenure_months"
        case purpose
        case collateralDescription = "collateral_description"
        case status
        case rejectionReason = "rejection_reason"
        case sentBackReason = "sent_back_reason"
        case revisionCount = "revision_count"
        case submittedAt = "submitted_at"
        case lastUpdatedAt = "last_updated_at"
        case decidedAt = "decided_at"
        case createdAt = "created_at"
    }
}
