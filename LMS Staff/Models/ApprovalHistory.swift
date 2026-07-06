//
//  ApprovalHistory.swift
//  LMS
//
//  Data model for the `approval_history` table.
//

import Foundation

// MARK: - Approval Action Enum

enum ApprovalAction: String, Codable, CaseIterable, Identifiable {
    case submit
    case review
    case approve
    case reject
    case sendBack = "send_back"
    case disburse
    case escalate

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .submit:   return "Submitted"
        case .review:   return "Reviewed"
        case .approve:  return "Approved"
        case .reject:   return "Rejected"
        case .sendBack: return "Sent Back"
        case .disburse: return "Disbursed"
        case .escalate: return "Escalated"
        }
    }
}

// MARK: - Approval History Model

struct ApprovalHistoryItem: Codable, Identifiable, Hashable {
    let id: UUID
    let applicationId: UUID
    let actorId: UUID
    var fromStatus: ApplicationStatus?
    var toStatus: ApplicationStatus
    var action: ApprovalAction
    var remarks: String?
    var approvedAmount: Double?
    var approvedTenureMonths: Int?
    var approvedInterestRate: Double?
    let actionedAt: Date?
    var ipAddress: String?

    enum CodingKeys: String, CodingKey {
        case id
        case applicationId = "application_id"
        case actorId = "actor_id"
        case fromStatus = "from_status"
        case toStatus = "to_status"
        case action
        case remarks
        case approvedAmount = "approved_amount"
        case approvedTenureMonths = "approved_tenure_months"
        case approvedInterestRate = "approved_interest_rate"
        case actionedAt = "actioned_at"
        case ipAddress = "ip_address"
    }
}
