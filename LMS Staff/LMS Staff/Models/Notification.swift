//
//  Notification.swift
//  LMS
//
//  Data model for the `notifications` table.
//

import Foundation

// MARK: - Notification Type Enum

enum LMSNotificationType: String, Codable, CaseIterable, Identifiable {
    case loanUpdate = "loan_update"
    case paymentReminder = "payment_reminder"
    case paymentReceived = "payment_received"
    case kycUpdate = "kyc_update"
    case documentRequest = "document_request"
    case approvalRequired = "approval_required"
    case general
    case system

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .loanUpdate:       return "Loan Update"
        case .paymentReminder:  return "Payment Reminder"
        case .paymentReceived:  return "Payment Received"
        case .kycUpdate:        return "KYC Update"
        case .documentRequest:  return "Document Request"
        case .approvalRequired: return "Approval Required"
        case .general:          return "General"
        case .system:           return "System"
        }
    }

    var icon: String {
        switch self {
        case .loanUpdate:       return "doc.text.fill"
        case .paymentReminder:  return "bell.badge.fill"
        case .paymentReceived:  return "indianrupeesign.circle.fill"
        case .kycUpdate:        return "person.badge.shield.checkmark.fill"
        case .documentRequest:  return "doc.badge.arrow.up.fill"
        case .approvalRequired: return "checkmark.seal.fill"
        case .general:          return "bell.fill"
        case .system:           return "gearshape.fill"
        }
    }
}

// MARK: - Notification Model

struct LMSNotification: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    var referenceId: UUID?
    var referenceType: String?
    var type: LMSNotificationType
    var title: String
    var body: String?
    var payload: [String: String]?
    var isRead: Bool
    var pushSent: Bool
    var pushStatus: String?
    var apnsMessageId: String?
    let sentAt: Date?
    var readAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case referenceId = "reference_id"
        case referenceType = "reference_type"
        case type
        case title
        case body
        case payload
        case isRead = "is_read"
        case pushSent = "push_sent"
        case pushStatus = "push_status"
        case apnsMessageId = "apns_message_id"
        case sentAt = "sent_at"
        case readAt = "read_at"
    }
}
