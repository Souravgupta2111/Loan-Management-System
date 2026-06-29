//
//  LoanPortfolioService.swift
//  LMS Staff
//
//  Service for managing active loans, tracking repayments, and flagging overdues.
//

import Foundation
import Supabase

struct LoanWithDetails: Identifiable, Hashable {
    var id: UUID { loan.id }
    let loan: Loan
    let borrower: AppUser
    let product: LoanProduct
}

@MainActor
class LoanPortfolioService {
    
    static let shared = LoanPortfolioService()
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    /// Fetches all active/restructured/NPA loans in the system, joining borrower and product data in-memory.
    func fetchLoans(status: LoanStatus? = nil, officerId: UUID? = nil) async throws -> [LoanWithDetails] {
        var query = supabase.database
            .from("loans")
            .select()
        
        if let st = status {
            query = query.eq("status", value: st.rawValue)
        }
        
        let loans: [Loan] = try await query
            .order("created_at", ascending: false)
            .execute()
            .value
            
        var populated = try await populateLoans(loans)
        
        if let officerId = officerId {
            struct AppIdResponse: Decodable {
                let id: UUID
            }
            
            let responses: [AppIdResponse] = try await supabase.database
                .from("loan_applications")
                .select("id")
                .eq("assigned_officer_id", value: officerId)
                .execute()
                .value
                
            let appIds = responses.map { $0.id }
            
            populated = populated.filter { appIds.contains($0.loan.applicationId) }
        }
            
        return populated
    }
    
    /// Helper to join products and users in-memory.
    private func populateLoans(_ loans: [Loan]) async throws -> [LoanWithDetails] {
        if loans.isEmpty { return [] }
        
        // Fetch all products
        let products: [LoanProduct] = try await supabase.database
            .from("loan_products")
            .select()
            .execute()
            .value
        let productsMap = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        
        var populated: [LoanWithDetails] = []
        
        for loan in loans {
            guard let product = productsMap[loan.loanProductId] else { continue }
            
            // Fetch borrower user details
            let borrower: AppUser = try await supabase.database
                .from("users")
                .select()
                .eq("id", value: loan.borrowerId)
                .single()
                .execute()
                .value
            
            populated.append(LoanWithDetails(
                loan: loan,
                borrower: borrower,
                product: product
            ))
        }
        
        return populated
    }
    
    /// Fetches the EMI schedule list for a specific loan.
    func fetchEMISchedule(forLoanId loanId: UUID) async throws -> [EMIScheduleItem] {
        let schedule: [EMIScheduleItem] = try await supabase.database
            .from("emi_schedule")
            .select()
            .eq("loan_id", value: loanId)
            .order("installment_number", ascending: true)
            .execute()
            .value
        return schedule
    }
    
    /// Fetches the transaction payments list for a specific loan.
    func fetchPayments(forLoanId loanId: UUID) async throws -> [Payment] {
        let payments: [Payment] = try await supabase.database
            .from("payments")
            .select()
            .eq("loan_id", value: loanId)
            .order("initiated_at", ascending: false)
            .execute()
            .value
        return payments
    }
    
    /// Flags a loan for overdue / NPA tracking (US-37)
    func flagOverdue(loanId: UUID, reason: String) async throws {
        try await supabase.database
            .from("loans")
            .update([
                "status": AnyEncodable(LoanStatus.npa.rawValue),
                "total_overdue": AnyEncodable(100.0), // placeholder default if not already parsed
                "npa_triggered_at": AnyEncodable(ISO8601DateFormatter().string(from: Date()))
            ])
            .eq("id", value: loanId)
            .execute()
            
        // Notify Borrower
        let loan: Loan = try await supabase.database
            .from("loans")
            .select()
            .eq("id", value: loanId)
            .single()
            .execute()
            .value
            
        try await NotificationService.shared.createNotification(
            userId: loan.borrowerId,
            title: "Loan Flagged as NPA",
            message: "Your loan account has been flagged for NPA monitoring. Reason: \(reason). Please pay immediately to resolve."
        )
        
        // Log action in audit log
        try await AuditService.shared.logAction(
            action: "FLAG_OVERDUE",
            tableName: "loans",
            recordId: loanId,
            summary: "Flagged loan \(loanId) as NPA. Reason: \(reason)"
        )
    }
}
