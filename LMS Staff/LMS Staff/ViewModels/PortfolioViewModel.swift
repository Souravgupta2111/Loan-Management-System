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
    
    @Published var loans: [LoanWithDetails] = []
    @Published var filteredLoans: [LoanWithDetails] = []
    @Published var searchText: String = ""
    @Published var selectedStatusFilter: String = "All"
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let portfolioService = LoanPortfolioService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        Publishers.CombineLatest($searchText, $selectedStatusFilter)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] search, filter in
                self?.applyFilters(search: search, filter: filter)
            }
            .store(in: &cancellables)
    }
    
    func loadPortfolio(forOfficerId officerId: UUID? = nil) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetched = try await portfolioService.fetchLoans(officerId: officerId)
            self.loans = fetched
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
        var result = loans
        
        if filter != "All" {
            result = result.filter { $0.loan.status.displayName == filter }
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
