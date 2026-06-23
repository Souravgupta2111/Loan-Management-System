//
//  CreditCheck.swift
//  LMS
//
//  Data model for the `credit_checks` table.
//

import Foundation

// MARK: - Credit Bureau Enum

enum CreditBureauType: String, Codable, CaseIterable, Identifiable {
    case cibil
    case experian
    case equifax
    case crif

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cibil:    return "CIBIL"
        case .experian: return "Experian"
        case .equifax:  return "Equifax"
        case .crif:     return "CRIF"
        }
    }
}

// MARK: - Credit Check Model

struct CreditCheck: Codable, Identifiable, Hashable {
    let id: UUID
    let borrowerId: UUID
    var applicationId: UUID?
    var bureauName: CreditBureauType
    var score: Int?
    var reportReference: String?
    var reportSummary: [String: String]?
    var status: String
    let pulledAt: Date?
    var validUntil: String?

    enum CodingKeys: String, CodingKey {
        case id
        case borrowerId = "borrower_id"
        case applicationId = "application_id"
        case bureauName = "bureau_name"
        case score
        case reportReference = "report_reference"
        case reportSummary = "report_summary"
        case status
        case pulledAt = "pulled_at"
        case validUntil = "valid_until"
    }
}
