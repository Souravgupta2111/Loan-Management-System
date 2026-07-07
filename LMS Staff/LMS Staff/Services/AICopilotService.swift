//
//  AICopilotService.swift
//  LMS Staff
//
//  Service layer for communicating with the ai-chat edge function as an Officer
//

import Foundation
import Supabase

@MainActor
final class AICopilotService {
    
    static let shared = AICopilotService()
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    enum CopilotAction: String {
        case summarizeRisk = "Summarize the risk profile of this borrower including credit score, income, FOIR, and any red flags."
        case draftRejection = "Draft a professional rejection reason based on this borrower's profile and application data."
        case flagGaps = "What are the red flags or missing data in this application? Check for incomplete KYC, low credit score, high debt ratio."
        case suggestQuestions = "What clarifying questions should I ask this borrower before recommending approval?"
    }
    
    func quickAction(_ action: CopilotAction, app: ApplicationWithBorrower) async throws -> String {
        guard let userId = supabase.currentUserId else { throw URLError(.userAuthenticationRequired) }
        
        let context = buildContext(app: app)
        
        let body: [String: AnyEncodable] = [
            "message": AnyEncodable(action.rawValue),
            "userId": AnyEncodable(userId.uuidString),
            "role": AnyEncodable("officer"),
            "contextData": AnyEncodable(context)
        ]
        
        let result: StaffAIChatResponse = try await supabase.client.functions.invoke(
            "ai-chat",
            options: FunctionInvokeOptions(
                body: body
            )
        )
        return result.reply
    }
    
    private func buildContext(app: ApplicationWithBorrower) -> OfficerContext {
        let borrowerProfile = OfficerContextProfile(
            name: app.borrower.fullName,
            creditScore: app.profile?.creditScore,
            employmentType: app.profile?.employmentType?.displayName,
            monthlyIncome: app.profile?.monthlyIncome,
            panNumber: app.profile?.panNumber,
            kycStatus: app.profile?.kycStatus.displayName
        )
        
        let applicationData = OfficerContextApplication(
            id: app.application.id,
            productName: app.product.name,
            requestedAmount: app.application.requestedAmount,
            requestedTenureMonths: app.application.requestedTenureMonths,
            status: app.application.status.displayName,
            purpose: app.application.purpose,
            collateralDescription: app.application.collateralDescription,
            rejectionReason: app.application.rejectionReason,
            sentBackReason: app.application.sentBackReason,
            revisionCount: app.application.revisionCount
        )
        
        let productData = OfficerContextProduct(
            name: app.product.name,
            minInterestRate: app.product.minInterestRate,
            maxInterestRate: app.product.maxInterestRate,
            minAmount: app.product.minAmount,
            maxAmount: app.product.maxAmount,
            minTenureMonths: app.product.minTenureMonths,
            maxTenureMonths: app.product.maxTenureMonths
        )
        
        return OfficerContext(
            borrower: borrowerProfile,
            application: applicationData,
            product: productData
        )
    }
}

// MARK: - Shared Response Model (used by both Officer and Manager services)
struct StaffAIChatResponse: Codable {
    let reply: String
    let conversationId: UUID?
}

// Note: `AnyEncodable` is defined once in ApplicationService.swift and reused here.

// MARK: - Officer Context Models
struct OfficerContext: Codable {
    let borrower: OfficerContextProfile
    let application: OfficerContextApplication
    let product: OfficerContextProduct
}

struct OfficerContextProfile: Codable {
    let name: String
    let creditScore: Int?
    let employmentType: String?
    let monthlyIncome: Double?
    let panNumber: String?
    let kycStatus: String?
}

struct OfficerContextApplication: Codable {
    let id: UUID
    let productName: String
    let requestedAmount: Double
    let requestedTenureMonths: Int
    let status: String
    let purpose: String?
    let collateralDescription: String?
    let rejectionReason: String?
    let sentBackReason: String?
    let revisionCount: Int
}

struct OfficerContextProduct: Codable {
    let name: String
    let minInterestRate: Double
    let maxInterestRate: Double
    let minAmount: Double
    let maxAmount: Double
    let minTenureMonths: Int
    let maxTenureMonths: Int
}
