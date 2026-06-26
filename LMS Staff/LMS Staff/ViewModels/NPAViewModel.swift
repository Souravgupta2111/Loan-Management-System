//
//  NPAViewModel.swift
//  LMS Staff
//
//  ViewModel for managing NPA delinquent accounts, loan restructuring, and write-offs.
//

import Foundation
import Combine

@MainActor
class NPAViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var overdueLoans: [LoanWithDetails] = []
    
    @Published var tier30To59: [LoanWithDetails] = []
    @Published var tier60To89: [LoanWithDetails] = []
    @Published var tier90PlusNPA: [LoanWithDetails] = []
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let portfolioService = LoanPortfolioService.shared
    private let npaService = NPAService.shared
    
    init() {}
    
    /// Loads active loans and groups them into 30/60/90+ day overdue buckets
    func loadOverdueAccounts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetched = try await portfolioService.fetchLoans()
            // We want loans that are active or restructured or npa AND have overdue days > 0
            // Or if status is npa
            let delinquent = fetched.filter {
                $0.loan.status == .npa || $0.loan.overdueDays > 0
            }
            
            self.overdueLoans = delinquent
            
            // Bucket them
            self.tier30To59 = delinquent.filter { $0.loan.overdueDays >= 30 && $0.loan.overdueDays < 60 }
            self.tier60To89 = delinquent.filter { $0.loan.overdueDays >= 60 && $0.loan.overdueDays < 90 }
            self.tier90PlusNPA = delinquent.filter { $0.loan.overdueDays >= 90 || $0.loan.status == .npa }
            
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func restructureLoan(
        loan: Loan,
        revisedRate: Double,
        revisedTenure: Int,
        waivedPenalty: Double,
        reason: String
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            try await npaService.restructureLoan(
                loan: loan,
                revisedRate: revisedRate,
                revisedTenure: revisedTenure,
                waivedPenalty: waivedPenalty,
                reason: reason
            )
            await loadOverdueAccounts()
            isLoading = false
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    func writeOffLoan(loan: Loan, reason: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            try await npaService.writeOffLoan(loan: loan, reason: reason)
            await loadOverdueAccounts()
            isLoading = false
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    func escalateLoan(loan: Loan, reason: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            try await npaService.escalateToAdmin(loan: loan, reason: reason)
            isLoading = false
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
}
