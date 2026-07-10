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
    
    private func buildManagerContext() async throws -> ManagerContext {
        let activeLoans: [ManagerLoanRow] = try await supabase.database
            .from("loans")
            .select("id, status, principal_amount, interest_rate")
            .eq("status", value: "active")
            .execute()
            .value
        
        let npaLoans: [ManagerLoanRow] = try await supabase.database
            .from("loans")
            .select("id, status, principal_amount, interest_rate")
            .eq("status", value: "npa")
            .execute()
            .value
        
        let pendingApps: [ManagerAppRow] = try await supabase.database
            .from("loan_applications")
            .select("id")
            .in("status", values: ["submitted", "under_review"])
            .execute()
            .value
        
        let totalDisbursed = activeLoans.reduce(0.0) { $0 + ($1.principalAmount ?? 0) }
        let npaPercentage = activeLoans.isEmpty ? 0 : (Double(npaLoans.count) / Double(activeLoans.count + npaLoans.count)) * 100
        
        let overdueEmis: [ManagerEmiRow] = try await supabase.database
            .from("emi_schedule")
            .select("id")
            .eq("status", value: "overdue")
            .execute()
            .value
        
        let paidEmis: [ManagerEmiRow] = try await supabase.database
            .from("emi_schedule")
            .select("id")
            .eq("status", value: "paid")
            .execute()
            .value
        
        let settledCount = paidEmis.count + overdueEmis.count
        let collectionEfficiency = settledCount == 0 ? 100.0 : (Double(paidEmis.count) / Double(settledCount)) * 100
        
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
            totalEmiCount: settledCount
        )
        
        return ManagerContext(
            portfolioSummary: portfolioSummary,
            branchMetrics: branchMetrics
        )
    }
}

private struct ManagerLoanRow: Codable {
    let id: UUID
    let status: String
    let principalAmount: Double?
    let interestRate: Double?

    enum CodingKeys: String, CodingKey {
        case id, status
        case principalAmount = "principal_amount"
        case interestRate = "interest_rate"
    }
}

private struct ManagerAppRow: Codable {
    let id: UUID
}

private struct ManagerEmiRow: Codable {
    let id: UUID
}

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
