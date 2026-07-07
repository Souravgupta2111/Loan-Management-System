//
//  ManagerAIService.swift
//  LMS Staff
//
//  Service layer for the Manager's AI Analytics assistant — queries real DB data
//

import Foundation
import Supabase

@MainActor
final class ManagerAIService {
    
    static let shared = ManagerAIService()
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    func sendMessage(content: String, conversationId: UUID?) async throws -> StaffAIChatResponse {
        guard let userId = supabase.currentUserId else { throw URLError(.userAuthenticationRequired) }
        
        let context = try await buildManagerContext()
        
        let body: [String: AnyEncodable] = [
            "message": AnyEncodable(content),
            "userId": AnyEncodable(userId.uuidString),
            "role": AnyEncodable("manager"),
            "conversationId": AnyEncodable(conversationId?.uuidString),
            "contextData": AnyEncodable(context)
        ]
        
        let response: StaffAIChatResponse = try await supabase.client.functions.invoke(
            "ai-chat",
            options: FunctionInvokeOptions(
                body: body
            )
        )
        return response
    }
    
    // MARK: - Build Real Manager Context from DB
    private func buildManagerContext() async throws -> ManagerContext {
        // 1. Count active loans
        let activeLoans: [ManagerLoanRow] = try await supabase.database
            .from("loans")
            .select("id, status, approved_amount, applied_interest_rate")
            .eq("status", value: "active")
            .execute()
            .value
        
        // 2. Count NPA loans
        let npaLoans: [ManagerLoanRow] = try await supabase.database
            .from("loans")
            .select("id, status, approved_amount, applied_interest_rate")
            .eq("status", value: "npa")
            .execute()
            .value
        
        // 3. Count pending applications
        let pendingApps: [ManagerAppRow] = try await supabase.database
            .from("loan_applications")
            .select("id")
            .in("status", values: ["submitted", "under_review", "recommended"])
            .execute()
            .value
        
        // 4. Compute totals
        let totalDisbursed = activeLoans.reduce(0.0) { $0 + ($1.approvedAmount ?? 0) }
        let npaPercentage = activeLoans.isEmpty ? 0 : (Double(npaLoans.count) / Double(activeLoans.count + npaLoans.count)) * 100
        
        // 5. Fetch recent overdue EMIs for collection efficiency
        let overdueEmis: [ManagerEmiRow] = try await supabase.database
            .from("emis")
            .select("id")
            .eq("status", value: "overdue")
            .execute()
            .value
        
        let totalEmis: [ManagerEmiRow] = try await supabase.database
            .from("emis")
            .select("id")
            .in("status", values: ["paid", "overdue", "pending"])
            .execute()
            .value
        
        let paidEmis = totalEmis.count - overdueEmis.count
        let collectionEfficiency = totalEmis.isEmpty ? 100.0 : (Double(paidEmis) / Double(totalEmis.count)) * 100
        
        let portfolioSummary = ManagerPortfolioSummary(
            totalActiveLoans: activeLoans.count,
            totalDisbursedAmount: totalDisbursed,
            npaCount: npaLoans.count,
            npaPercentage: npaPercentage
        )
        
        let branchMetrics = ManagerBranchMetrics(
            collectionEfficiency: collectionEfficiency,
            pendingApplicationsCount: pendingApps.count,
            overdueEmiCount: overdueEmis.count,
            totalEmiCount: totalEmis.count
        )
        
        return ManagerContext(
            portfolioSummary: portfolioSummary,
            branchMetrics: branchMetrics
        )
    }
}

// MARK: - Lightweight row models for aggregate queries
private struct ManagerLoanRow: Codable {
    let id: UUID
    let status: String
    let approvedAmount: Double?
    let appliedInterestRate: Double?

    enum CodingKeys: String, CodingKey {
        case id, status
        case approvedAmount = "approved_amount"
        case appliedInterestRate = "applied_interest_rate"
    }
}

private struct ManagerAppRow: Codable {
    let id: UUID
}

private struct ManagerEmiRow: Codable {
    let id: UUID
}

// MARK: - Manager Context Models
struct ManagerContext: Codable {
    let portfolioSummary: ManagerPortfolioSummary
    let branchMetrics: ManagerBranchMetrics
}

struct ManagerPortfolioSummary: Codable {
    let totalActiveLoans: Int
    let totalDisbursedAmount: Double
    let npaCount: Int
    let npaPercentage: Double
}

struct ManagerBranchMetrics: Codable {
    let collectionEfficiency: Double
    let pendingApplicationsCount: Int
    let overdueEmiCount: Int
    let totalEmiCount: Int
}
