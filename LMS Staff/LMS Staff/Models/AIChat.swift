//
//  AIChat.swift
//  LMS
//
//  Models for AI Chat interactions
//

import Foundation

enum AIRole: String, Codable {
    case user
    case assistant
}

struct AIConversation: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let role: String // "borrower", "officer", "manager"
    let title: String?
    let contextRefId: UUID?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case role
        case title
        case contextRefId = "context_ref_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct AIMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let conversationId: UUID
    let role: AIRole
    let content: String
    let suggestedActions: [AISuggestedAction]?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case role
        case content
        case suggestedActions = "suggested_actions"
        case createdAt = "created_at"
    }
    
    static func == (lhs: AIMessage, rhs: AIMessage) -> Bool {
        lhs.id == rhs.id
    }
}

struct AISuggestedAction: Codable, Identifiable {
    var id: String { type.rawValue + label }
    let type: ActionType
    let target: String?
    let label: String
    
    enum ActionType: String, Codable {
        case navigate
        case calculate
        case fillForm
    }
}

// Request & Response models for the Edge Function
struct AIChatRequest: Codable {
    let message: String
    let userId: UUID
    let role: String
    let conversationId: UUID?
    let contextData: BorrowerContext
}

struct AIChatResponse: Codable {
    let reply: String
    let conversationId: UUID
    
    enum CodingKeys: String, CodingKey {
        case reply
        case conversationId
    }
}

// Context Model for the Borrower
struct BorrowerContext: Codable {
    let profile: BorrowerContextProfile
    let activeLoans: [LoanContextItem]
    let availableProducts: [ProductContextItem]
    let emiSchedule: [EmiContextItem]
    let paymentHistory: [PaymentContextItem]
}

struct BorrowerContextProfile: Codable {
    let name: String
    let creditScore: Int?
    let employmentType: String?
    let monthlyIncome: Double?
    let panNumber: String?
    let kycStatus: String?
    let aaConsentStatus: String?
}

struct LoanContextItem: Codable {
    let id: UUID
    let productName: String
    let status: String
    let remainingAmount: Double
    let interestRate: Double
    let nextEmiAmount: Double?
    let nextEmiDate: String?
}

struct ProductContextItem: Codable {
    let id: UUID
    let name: String
    let interestRate: Double
    let minAmount: Double
    let maxAmount: Double
}

struct EmiContextItem: Codable {
    let loanId: UUID
    let dueDate: String
    let emiAmount: Double
    let principalComponent: Double?
    let interestComponent: Double?
    let status: String
}

struct PaymentContextItem: Codable {
    let loanId: UUID
    let paidDate: String
    let amount: Double
    let paymentMethod: String?
}
