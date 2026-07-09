//
//  StaffAIChatService.swift
//  LMS Staff
//
//  Service layer for communicating with the ai-chat edge function.
//  Detects the user's role and sends real context data for managers/officers.
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
        
        // Detect user role from DB
        let role = await fetchUserRole(userId: userId)
        
        if role == "manager" || role == "admin" {
            // Use real manager context with portfolio data
            return try await sendWithManagerContext(content: content, userId: userId, role: role, conversationId: conversationId)
        } else {
            // Officer — use officer context
            return try await sendWithOfficerContext(content: content, userId: userId, conversationId: conversationId)
        }
    }
    
    // MARK: - Manager/Admin context (real DB data)
    
    private func sendWithManagerContext(content: String, userId: UUID, role: String, conversationId: UUID?) async throws -> AIChatResponse {
        let context = try await buildManagerContext()
        
        let body: [String: AnyEncodable] = [
            "message": AnyEncodable(content),
            "userId": AnyEncodable(userId.uuidString),
            "role": AnyEncodable(role),
            "conversationId": AnyEncodable(conversationId?.uuidString),
            "contextData": AnyEncodable(context)
        ]
        
        let response: AIChatResponse = try await supabase.client.functions.invoke(
            "ai-chat",
            options: FunctionInvokeOptions(body: body)
        )
        return response
    }
    
    // MARK: - Officer context (real assigned applications)
    
    private func sendWithOfficerContext(content: String, userId: UUID, conversationId: UUID?) async throws -> AIChatResponse {
        let context = try await buildOfficerContext(userId: userId)
        
        let body: [String: AnyEncodable] = [
            "message": AnyEncodable(content),
            "userId": AnyEncodable(userId.uuidString),
            "role": AnyEncodable("officer"),
            "conversationId": AnyEncodable(conversationId?.uuidString),
            "contextData": AnyEncodable(context)
        ]
        
        let response: AIChatResponse = try await supabase.client.functions.invoke(
            "ai-chat",
            options: FunctionInvokeOptions(body: body)
        )
        return response
    }
    
    // MARK: - Role Detection
    
    private func fetchUserRole(userId: UUID) async -> String {
        struct RoleRow: Decodable { let role: String }
        do {
            let rows: [RoleRow] = try await supabase.database
                .from("users")
                .select("role")
                .eq("id", value: userId.uuidString)
                .execute()
                .value
            return rows.first?.role ?? "officer"
        } catch {
            return "officer"
        }
    }
    
    // MARK: - Build Manager Context
    
    private func buildManagerContext() async throws -> ManagerContext {
        let activeLoans: [LoanRow] = try await supabase.database
            .from("loans")
            .select("id, status, principal_amount, interest_rate")
            .eq("status", value: "active")
            .execute()
            .value
        
        let npaLoans: [LoanRow] = try await supabase.database
            .from("loans")
            .select("id, status, principal_amount, interest_rate")
            .eq("status", value: "npa")
            .execute()
            .value
        
        let pendingApps: [IdRow] = try await supabase.database
            .from("loan_applications")
            .select("id")
            .in("status", values: ["submitted", "under_review", "approved", "pending_acceptance", "pending_disbursal"])
            .execute()
            .value
        
        let totalDisbursed = activeLoans.reduce(0.0) { $0 + ($1.principalAmount ?? 0) }
        let totalLoans = activeLoans.count + npaLoans.count
        let npaPercentage = totalLoans == 0 ? 0 : (Double(npaLoans.count) / Double(totalLoans)) * 100
        
        let overdueEmis: [IdRow] = try await supabase.database
            .from("emi_schedule")
            .select("id")
            .eq("status", value: "overdue")
            .execute()
            .value
        
        let paidEmis: [IdRow] = try await supabase.database
            .from("emi_schedule")
            .select("id")
            .eq("status", value: "paid")
            .execute()
            .value
        
        let settledCount = paidEmis.count + overdueEmis.count
        let collectionEfficiency = settledCount == 0 ? 100.0 : (Double(paidEmis.count) / Double(settledCount)) * 100
        
        return ManagerContext(
            portfolioSummary: ManagerPortfolioSummary(
                totalActiveLoans: activeLoans.count,
                totalDisbursedAmount: totalDisbursed,
                npaCount: npaLoans.count,
                npaPercentage: npaPercentage
            ),
            branchMetrics: ManagerBranchMetrics(
                collectionEfficiency: collectionEfficiency,
                pendingApplicationsCount: pendingApps.count,
                overdueEmiCount: overdueEmis.count,
                totalEmiCount: settledCount
            )
        )
    }
    
    // MARK: - Build Officer Context
    
    private func buildOfficerContext(userId: UUID) async throws -> OfficerContext {
        // Get officer's staff profile
        struct ProfileRow: Decodable { let id: UUID }
        let profiles: [ProfileRow] = try await supabase.database
            .from("staff_profiles")
            .select("id")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        
        guard let profileId = profiles.first?.id else {
            return OfficerContext(assignedApplications: 0, underReview: 0, sentBack: 0, activeLoans: 0)
        }
        
        struct AppRow: Decodable { let status: String }
        let apps: [AppRow] = try await supabase.database
            .from("loan_applications")
            .select("status")
            .eq("assigned_officer_id", value: profileId.uuidString)
            .execute()
            .value
        
        let underReview = apps.filter { $0.status == "under_review" }.count
        let sentBack = apps.filter { $0.status == "sent_back" }.count
        
        // Active loans assigned to this officer
        let activeLoans: [IdRow] = try await supabase.database
            .from("loans")
            .select("id")
            .eq("status", value: "active")
            .execute()
            .value
        
        return OfficerContext(
            assignedApplications: apps.count,
            underReview: underReview,
            sentBack: sentBack,
            activeLoans: activeLoans.count
        )
    }
}

// MARK: - Private Row Models

private struct LoanRow: Codable {
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

private struct IdRow: Codable {
    let id: UUID
}

// MARK: - Officer Context

struct OfficerContext: Codable {
    let assignedApplications: Int
    let underReview: Int
    let sentBack: Int
    let activeLoans: Int
}
