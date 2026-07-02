//
//  PortfolioViewModel.swift
//  LMS Staff
//
//  ViewModel for managing active loan portfolios and overdue repayment listings.
//

import Foundation
import Combine

@MainActor
class PortfolioViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var loans: [LoanWithDetails] = [] {
        didSet {
            applyFilters(search: searchText, filter: selectedStatusFilter)
        }
    }
    @Published var collectionTrends: [CollectionTrendItem] = []
    @Published var filteredLoans: [LoanWithDetails] = []
    @Published var searchText: String = "" {
        didSet {
            applyFilters(search: searchText, filter: selectedStatusFilter)
        }
    }
    @Published var selectedStatusFilter: String = "All" {
        didSet {
            applyFilters(search: searchText, filter: selectedStatusFilter)
        }
    }
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let portfolioService = LoanPortfolioService.shared
    
    init() {}
    
    func loadPortfolio(forOfficerId officerId: UUID? = nil) async {
        isLoading = true
        errorMessage = nil
        
        do {
            async let fetchedLoansTask = portfolioService.fetchLoans(officerId: officerId)
            async let fetchedTrendsTask = ReportService.shared.fetchCollectionTrends()
            
            let (fetched, trends) = try await (fetchedLoansTask, fetchedTrendsTask)
            
            self.loans = fetched
            self.collectionTrends = trends
            applyFilters(search: searchText, filter: selectedStatusFilter)
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func flagLoanAsOverdue(loanId: UUID, reason: String, officerId: UUID? = nil) async -> Bool {
        do {
            try await portfolioService.flagOverdue(loanId: loanId, reason: reason)
            await loadPortfolio(forOfficerId: officerId)
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
    
    private func applyFilters(search: String, filter: String) {
        // Active portfolios should only display Active, Restructured, and NPA loans
        var result = loans.filter { $0.loan.status == .active || $0.loan.status == .restructured || $0.loan.status == .npa }
        
        if filter != "All" {
            result = result.filter { $0.loan.status.displayName.lowercased() == filter.lowercased() }
        }
        
        if !search.isEmpty {
            let query = search.lowercased()
            result = result.filter {
                $0.borrower.fullName.lowercased().contains(query) ||
                ($0.loan.loanNumber ?? "").lowercased().contains(query) ||
                $0.product.name.lowercased().contains(query)
            }
        }
        
        self.filteredLoans = result
    }
}
