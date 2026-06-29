//
//  OfficerDashboardViewModel.swift
//  LMS Staff
//
//  ViewModel for the Loan Officer Dashboard.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class OfficerDashboardViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var applications: [ApplicationWithBorrower] = [] {
        didSet {
            applyFilters(search: searchText, filter: selectedStatusFilter)
        }
    }
    @Published var filteredApplications: [ApplicationWithBorrower] = []
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
    
    @Published var statsPendingCount: Int = 0
    @Published var statsUnderReviewCount: Int = 0
    @Published var statsApprovedCount: Int = 0
    @Published var statsRejectedCount: Int = 0
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let applicationService = ApplicationService.shared
    
    init() {}
    
    // MARK: - Load Data
    
    func loadApplications(forOfficerId officerId: UUID) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetched = try await applicationService.fetchApplications(forOfficerId: officerId)
            self.applications = fetched
            calculateStats()
            applyFilters(search: searchText, filter: selectedStatusFilter)
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Helper calculations
    
    private func calculateStats() {
        statsPendingCount = applications.filter { $0.application.status == .submitted }.count
        statsUnderReviewCount = applications.filter { $0.application.status == .underReview }.count
        statsApprovedCount = applications.filter { $0.application.status == .approved || $0.application.status == .disbursed }.count
        statsRejectedCount = applications.filter { $0.application.status == .rejected }.count
    }
    
    private func applyFilters(search: String, filter: String) {
        var result = applications
        
        // Apply status filter
        if filter != "All" {
            result = result.filter { $0.application.status.displayName == filter }
        }
        
        // Apply search query
        if !search.isEmpty {
            let query = search.lowercased()
            result = result.filter {
                $0.borrower.fullName.lowercased().contains(query) ||
                $0.product.name.lowercased().contains(query) ||
                ($0.application.applicationNumber ?? "").lowercased().contains(query)
            }
        }
        
        self.filteredApplications = result
    }
}
