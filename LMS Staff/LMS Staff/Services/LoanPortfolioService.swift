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
            // Resolve staff_profiles.id (profileId)
            let staffProfile: StaffProfile? = try? await supabase.database
                .from("staff_profiles")
                .select()
                .or("id.eq.\(officerId.uuidString),user_id.eq.\(officerId.uuidString)")
                .single()
                .execute()
                .value
                
            let profileId = staffProfile?.id ?? officerId
            
            struct AppIdResponse: Decodable {
                let id: UUID
            }
            
            let responses: [AppIdResponse] = try await supabase.database
                .from("loan_applications")
                .select("id")
                .eq("assigned_officer_id", value: profileId)
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
        // Compute the REAL overdue amount and days from the loan's EMIs rather
        // than writing a hardcoded placeholder. An installment is overdue when
        // it is explicitly 'overdue', or unpaid with a due date in the past.
        struct EMIRow: Decodable {
            let due_date: String
            let total_emi: Double
            let penalty_amount: Double
            let status: String
        }
        let emis: [EMIRow] = try await supabase.database
            .from("emi_schedule")
            .select("due_date, total_emi, penalty_amount, status")
            .eq("loan_id", value: loanId)
            .execute()
            .value

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = Calendar.current.startOfDay(for: Date())
        let todayStr = dateFormatter.string(from: today)

        let overdueEmis = emis.filter { emi in
            let unsettled = emi.status != EMIStatus.paid.rawValue && emi.status != EMIStatus.writtenOff.rawValue
            return emi.status == EMIStatus.overdue.rawValue || (unsettled && String(emi.due_date.prefix(10)) < todayStr)
        }

        let totalOverdue = overdueEmis.reduce(0.0) { $0 + $1.total_emi + $1.penalty_amount }

        // Don't force a loan into NPA when nothing is actually overdue.
        guard totalOverdue > 0, !overdueEmis.isEmpty else {
            throw NSError(domain: "LoanPortfolioService", code: 422, userInfo: [
                NSLocalizedDescriptionKey: "This loan has no overdue installments, so it can't be flagged as NPA."
            ])
        }

        // Overdue days = distance from the oldest overdue due date to today.
        let oldestDueStr = overdueEmis.map { String($0.due_date.prefix(10)) }.min() ?? todayStr
        var overdueDays = 0
        if let oldestDue = dateFormatter.date(from: oldestDueStr) {
            overdueDays = max(0, Calendar.current.dateComponents([.day], from: oldestDue, to: today).day ?? 0)
        }

        try await supabase.database
            .from("loans")
            .update([
                "status": AnyEncodable(LoanStatus.npa.rawValue),
                "total_overdue": AnyEncodable(totalOverdue),
                "overdue_days": AnyEncodable(overdueDays),
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
