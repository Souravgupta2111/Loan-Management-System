//
//  LoanRestructure.swift
//  LMS
//
//  Data model for the `loan_restructures` table.
//

import Foundation

// MARK: - Restructure Status Enum

enum RestructureStatus: String, Codable, CaseIterable, Identifiable {
    case requested
    case approved
    case rejected
    case applied

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .requested: return "Requested"
        case .approved:  return "Approved"
        case .rejected:  return "Rejected"
        case .applied:   return "Applied"
        }
    }
}

// MARK: - Loan Restructure Model

struct LoanRestructure: Codable, Identifiable, Hashable {
    let id: UUID
    let originalLoanId: UUID
    var approvedBy: UUID?
    var reason: String
    var waivedPenalty: Double
    var revisedInterestRate: Double?
    var revisedTenureMonths: Int?
    var revisedFirstEmiDate: String?
    var status: RestructureStatus
    let createdAt: Date?
    var approvedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case originalLoanId = "original_loan_id"
        case approvedBy = "approved_by"
        case reason
        case waivedPenalty = "waived_penalty"
        case revisedInterestRate = "revised_interest_rate"
        case revisedTenureMonths = "revised_tenure_months"
        case revisedFirstEmiDate = "revised_first_emi_date"
        case status
        case createdAt = "created_at"
        case approvedAt = "approved_at"
    }
}
