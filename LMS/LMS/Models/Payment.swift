//
//  Payment.swift
//  LMS
//
//  Data model for the `payments` table.
//

import Foundation

// MARK: - Payment Status Enum

enum PaymentStatus: String, Codable, CaseIterable, Identifiable {
    case initiated
    case processing
    case confirmed
    case failed
    case refunded

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .initiated:  return "Initiated"
        case .processing: return "Processing"
        case .confirmed:  return "Confirmed"
        case .failed:     return "Failed"
        case .refunded:   return "Refunded"
        }
    }
}

enum PaymentMode: String, Codable, CaseIterable, Identifiable {
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

// MARK: - Payment Model

struct Payment: Codable, Identifiable, Hashable {
    let id: UUID
    let loanId: UUID
    var emiId: UUID?
    var collectedBy: UUID?
    var amountPaid: Double
    var principalPaid: Double
    var interestPaid: Double
    var penaltyPaid: Double
    var excessPaid: Double
    var paymentMode: PaymentMode
    var razorpayOrderId: String?
    var razorpayPaymentId: String?
    var razorpaySignature: String?
    var upiTransactionId: String?
    var chequeNumber: String?
    var bankReference: String?
    var status: PaymentStatus
    var failureReason: String?
    let initiatedAt: Date?
    var confirmedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case loanId = "loan_id"
        case emiId = "emi_id"
        case collectedBy = "collected_by"
        case amountPaid = "amount_paid"
        case principalPaid = "principal_paid"
        case interestPaid = "interest_paid"
        case penaltyPaid = "penalty_paid"
        case excessPaid = "excess_paid"
        case paymentMode = "payment_mode"
        case razorpayOrderId = "razorpay_order_id"
        case razorpayPaymentId = "razorpay_payment_id"
        case razorpaySignature = "razorpay_signature"
        case upiTransactionId = "upi_transaction_id"
        case chequeNumber = "cheque_number"
        case bankReference = "bank_reference"
        case status
        case failureReason = "failure_reason"
        case initiatedAt = "initiated_at"
        case confirmedAt = "confirmed_at"
    }
}
