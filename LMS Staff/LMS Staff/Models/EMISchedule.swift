//
//  EMISchedule.swift
//  LMS
//
//  Data model for the `emi_schedule` table.
//

import Foundation

// MARK: - EMI Status Enum

enum EMIStatus: String, Codable, CaseIterable, Identifiable {
    case upcoming
    case due
    case paid
    case overdue
    case partiallyPaid = "partially_paid"
    case writtenOff = "written_off"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .upcoming:      return "Upcoming"
        case .due:           return "Due"
        case .paid:          return "Paid"
        case .overdue:       return "Overdue"
        case .partiallyPaid: return "Partially Paid"
        case .writtenOff:    return "Written Off"
        }
    }

    var icon: String {
        switch self {
        case .upcoming:      return "clock.fill"
        case .due:           return "bell.fill"
        case .paid:          return "checkmark.circle.fill"
        case .overdue:       return "exclamationmark.triangle.fill"
        case .partiallyPaid: return "circle.lefthalf.filled"
        case .writtenOff:    return "xmark.circle.fill"
        }
    }
}

// MARK: - EMI Schedule Item Model

struct EMIScheduleItem: Codable, Identifiable, Hashable {
    let id: UUID
    let loanId: UUID
    var installmentNumber: Int
    var dueDate: String  // Date string from DB
    var openingBalance: Double
    var principalComponent: Double
    var interestComponent: Double
    var totalEmi: Double
    var penaltyAmount: Double
    var penaltyDays: Int
    var closingBalance: Double
    var status: EMIStatus
    var paidDate: String?
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case loanId = "loan_id"
        case installmentNumber = "installment_number"
        case dueDate = "due_date"
        case openingBalance = "opening_balance"
        case principalComponent = "principal_component"
        case interestComponent = "interest_component"
        case totalEmi = "total_emi"
        case penaltyAmount = "penalty_amount"
        case penaltyDays = "penalty_days"
        case closingBalance = "closing_balance"
        case status
        case paidDate = "paid_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
