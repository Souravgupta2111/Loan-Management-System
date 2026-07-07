//
//  StaffAIChatService.swift
//  LMS Staff
//
//  Service layer for communicating with the ai-chat edge function
//

import Foundation
import Supabase

@MainActor
final class StaffAIChatService {
    
    static let shared = StaffAIChatService()
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    func sendMessage(content: String, conversationId: UUID?) async throws -> AIChatResponse {
        guard let userId = supabase.currentUserId else { throw URLError(.userAuthenticationRequired) }
        
        // Pass a dummy BorrowerContext to satisfy the current ai-chat edge function schema.
        // In a production app, the edge function would be updated to accept a StaffContext.
        let dummyContext = BorrowerContext(
            profile: BorrowerContextProfile(
                name: "Staff Member",
                creditScore: nil,
                employmentType: nil,
                monthlyIncome: nil,
                panNumber: nil,
                kycStatus: nil,
                aaConsentStatus: nil
            ),
            activeLoans: [],
            availableProducts: [],
            emiSchedule: [],
            paymentHistory: []
        )
        
        let request = AIChatRequest(
            message: content,
            userId: userId,
            role: "staff",
            conversationId: conversationId,
            contextData: dummyContext
        )
        
        let response: AIChatResponse = try await supabase.client.functions.invoke(
            "ai-chat",
            options: FunctionInvokeOptions(
                body: request
            )
        )
        
        return response
    }
}
