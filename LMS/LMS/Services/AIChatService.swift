//
//  AIChatService.swift
//  LMS
//
//  Service layer for communicating with the ai-chat edge function
//

import Foundation
import Supabase

@MainActor
final class AIChatService {
    
    static let shared = AIChatService()
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    // MARK: - Conversations
    
    func fetchConversations() async throws -> [AIConversation] {
        guard let userId = supabase.currentUserId else { throw URLError(.userAuthenticationRequired) }
        
        let response: [AIConversation] = try await supabase.client
            .from("ai_conversations")
            .select()
            .eq("user_id", value: userId)
            .eq("role", value: "borrower")
            .order("updated_at", ascending: false)
            .execute()
            .value
        
        return response
    }
    
    func fetchMessages(conversationId: UUID) async throws -> [AIMessage] {
        let response: [AIMessage] = try await supabase.client
            .from("ai_messages")
            .select()
            .eq("conversation_id", value: conversationId)
            .order("created_at", ascending: true)
            .execute()
            .value
        
        return response
    }
    
    // MARK: - Sending Messages
    
    func sendMessage(content: String, conversationId: UUID?, context: BorrowerContext) async throws -> AIChatResponse {
        guard let userId = supabase.currentUserId else { throw URLError(.userAuthenticationRequired) }
        
        let request = AIChatRequest(
            message: content,
            userId: userId,
            role: "borrower",
            conversationId: conversationId,
            contextData: context
        )
        
        let response: AIChatResponse = try await supabase.client.functions.invoke(
            "ai-chat",
            options: FunctionInvokeOptions(
                body: request
            )
        )
        
        return response
    }
    
    // MARK: - Context Building
    
    func buildBorrowerContext() async throws -> BorrowerContext {
        guard let userId = supabase.currentUserId else { throw URLError(.userAuthenticationRequired) }
        
        // Fetch Profile
        let profile: BorrowerProfile = try await supabase.client
            .from("borrower_profiles")
            .select()
            .eq("user_id", value: userId)
            .single()
            .execute()
            .value
            
        // Fetch User (for name)
        let name = supabase.currentUser?.userMetadata["full_name"]?.value as? String ?? "Borrower"
        
        let profileContext = BorrowerContextProfile(
            name: name,
            creditScore: profile.creditScore,
            employmentType: profile.employmentType?.displayName,
            monthlyIncome: profile.monthlyIncome,
            panNumber: profile.panNumber,
            kycStatus: profile.kycStatus.rawValue,
            aaConsentStatus: profile.aaConsentStatus
        )
        
        // Fetch Active Loans
        let loans: [Loan] = try await supabase.client
            .from("loans")
            .select()
            .eq("borrower_id", value: userId)
            .execute()
            .value
            
        var activeLoans: [LoanContextItem] = []
        var allEmiSchedule: [EmiContextItem] = []
        var allPaymentHistory: [PaymentContextItem] = []
        let dateFormatter = ISO8601DateFormatter()
        
        for loan in loans where loan.status == .active {
            // Fetch next EMI (real table is `emi_schedule`, not `emis`)
            let emis: [EMIScheduleItem] = try await supabase.client
                .from("emi_schedule")
                .select()
                .eq("loan_id", value: loan.id)
                .order("due_date", ascending: true)
                .execute()
                .value
            
            let nextPendingEmi = emis.first { $0.status == .due || $0.status == .upcoming }
            let emiDateString = nextPendingEmi?.dueDate
            
            activeLoans.append(LoanContextItem(
                id: loan.id,
                productName: "Loan",
                status: loan.status.rawValue,
                remainingAmount: loan.outstandingPrincipal,
                interestRate: loan.interestRate,
                nextEmiAmount: nextPendingEmi?.totalEmi,
                nextEmiDate: emiDateString
            ))
            
            // Build EMI schedule (upcoming + next 6 months)
            for emi in emis.prefix(12) {
                allEmiSchedule.append(EmiContextItem(
                    loanId: loan.id,
                    dueDate: emi.dueDate,
                    emiAmount: emi.totalEmi,
                    principalComponent: emi.principalComponent,
                    interestComponent: emi.interestComponent,
                    status: emi.status.rawValue
                ))
            }
            
            // Build payment history (paid EMIs)
            for emi in emis where emi.status == .paid {
                allPaymentHistory.append(PaymentContextItem(
                    loanId: loan.id,
                    paidDate: emi.paidDate ?? emi.dueDate,
                    amount: emi.totalEmi,
                    paymentMethod: nil
                ))
            }
        }
        
        // Fetch Available Products
        let products: [LoanProduct] = try await supabase.client
            .from("loan_products")
            .select()
            .eq("is_active", value: true)
            .execute()
            .value
            
        let productsContext = products.map { 
            ProductContextItem(
                id: $0.id,
                name: $0.name,
                interestRate: $0.minInterestRate,
                minAmount: $0.minAmount,
                maxAmount: $0.maxAmount
            )
        }
        
        return BorrowerContext(
            profile: profileContext,
            activeLoans: activeLoans,
            availableProducts: productsContext,
            emiSchedule: allEmiSchedule,
            paymentHistory: allPaymentHistory
        )
    }
}
