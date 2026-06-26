//
//  Loan.swift
//  LMS
//
//  Data model for the `loans` table.
//  Tracks spread + base rate separately for floating-rate loans.
//

import Foundation

// MARK: - Loan Status Enum

enum LoanStatus: String, Codable, CaseIterable, Identifiable {
    case active
    case closed
    case npa
    case restructured
    case writtenOff = "written_off"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .active:       return "Active"
        case .closed:       return "Closed"
        case .npa:          return "NPA"
        case .restructured: return "Restructured"
        case .writtenOff:   return "Written Off"
        }
    }

    var icon: String {
        switch self {
        case .active:       return "checkmark.circle.fill"
        case .closed:       return "lock.fill"
        case .npa:          return "exclamationmark.triangle.fill"
        case .restructured: return "arrow.triangle.2.circlepath"
        case .writtenOff:   return "xmark.bin.fill"
        }
    }
}

enum RepaymentMode: String, Codable, CaseIterable, Identifiable {
    case cash
    case upi
    case razorpay
    case cheque
    case neft
    case rtgs
    case autoDebit = "auto_debit"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cash:      return "Cash"
        case .upi:       return "UPI"
        case .razorpay:  return "Razorpay"
        case .cheque:    return "Cheque"
        case .neft:      return "NEFT"
        case .rtgs:      return "RTGS"
        case .autoDebit: return "Auto Debit"
        }
    }
}

// MARK: - Loan Model

struct Loan: Codable, Identifiable, Hashable {
    let id: UUID
    let applicationId: UUID
    let borrowerId: UUID
    let loanProductId: UUID
    var disbursedBy: UUID?
    var branchId: UUID?
    var loanNumber: String?
    var principalAmount: Double

    // Interest rate breakdown
    // For floating loans: interestRate = currentBaseRate + spread
    // For fixed loans: interestRate stays constant, spread/base are recorded for audit
    var interestRate: Double
    var interestType: InterestType
    var spread: Double                    // Bank's markup (stays constant for loan life)
    var baseRateAtDisbursement: Double    // RBI rate when loan was given (audit snapshot)
    var currentBaseRate: Double           // Current RBI rate applied (updated for floating)

    var tenureMonths: Int
    var processingFee: Double
    var totalPayable: Double
    var disbursementDate: String?
    var firstEmiDate: String?
    var maturityDate: String?
    var status: LoanStatus
    var outstandingPrincipal: Double
    var outstandingInterest: Double
    var totalOverdue: Double
    var overdueDays: Int
    var bankAccountNumber: String?
    var ifscCode: String?
    var disbursementReference: String?
    var repaymentMode: RepaymentMode
    var npaTriggeredAt: Date?
    var closedAt: Date?
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case applicationId = "application_id"
        case borrowerId = "borrower_id"
        case loanProductId = "loan_product_id"
        case disbursedBy = "disbursed_by"
        case branchId = "branch_id"
        case loanNumber = "loan_number"
        case principalAmount = "principal_amount"
        case interestRate = "interest_rate"
        case interestType = "interest_type"
        case spread
        case baseRateAtDisbursement = "base_rate_at_disbursement"
        case currentBaseRate = "current_base_rate"
        case tenureMonths = "tenure_months"
        case processingFee = "processing_fee"
        case totalPayable = "total_payable"
        case disbursementDate = "disbursement_date"
        case firstEmiDate = "first_emi_date"
        case maturityDate = "maturity_date"
        case status
        case outstandingPrincipal = "outstanding_principal"
        case outstandingInterest = "outstanding_interest"
        case totalOverdue = "total_overdue"
        case overdueDays = "overdue_days"
        case bankAccountNumber = "bank_account_number"
        case ifscCode = "ifsc_code"
        case disbursementReference = "disbursement_reference"
        case repaymentMode = "repayment_mode"
        case npaTriggeredAt = "npa_triggered_at"
        case closedAt = "closed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - Computed Properties

    /// Whether this loan's rate changes with RBI repo rate
    var isFloatingRate: Bool {
        interestType == .floating
    }

    /// Formatted rate with type (e.g., "8.50% Floating (Spread: 2.00%)")
    var formattedRate: String {
        if isFloatingRate {
            return String(format: "%.2f%% Floating (Spread: %.2f%%)", interestRate, spread)
        }
        return String(format: "%.2f%% %@", interestRate, interestType.displayName)
    }

    /// Rate breakdown for display
    var rateBreakdown: String? {
        guard isFloatingRate else { return nil }
        return String(format: "Base: %.2f%% + Spread: %.2f%%", currentBaseRate, spread)
    }
}
