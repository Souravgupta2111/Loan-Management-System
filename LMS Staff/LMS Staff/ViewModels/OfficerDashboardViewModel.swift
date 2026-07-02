//
//  OfficerDashboardViewModel.swift
//  LMS Staff
//
//  ViewModel for the Loan Officer Dashboard.
//

import Foundation
import SwiftUI
import Combine
import Supabase
import PostgREST

@MainActor
class OfficerDashboardViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var applications: [ApplicationWithBorrower] = [] {
        didSet {
            applyFilters(search: searchText, filter: selectedStatusFilter)
        }
    }
    private var lastMessageTimes: [UUID: Date] = [:]
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
            await fetchMessageTimestamps()
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Helper calculations
    
    private func calculateStats() {
        statsPendingCount = applications.filter { $0.application.status == .submitted || $0.application.status == .sentBack }.count
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
        
        // Sort by latest message
        result.sort { app1, app2 in
            let date1 = lastMessageTimes[app1.application.id] ?? .distantPast
            let date2 = lastMessageTimes[app2.application.id] ?? .distantPast
            return date1 > date2
        }
        
        self.filteredApplications = result
    }
    
    private func fetchMessageTimestamps() async {
        let appIds = applications.map { $0.application.id }
        guard !appIds.isEmpty else { return }
        
        struct MessageTimestamp: Decodable {
            let application_id: UUID
            let sent_at: String
        }
        
        do {
            let timestamps: [MessageTimestamp] = try await SupabaseManager.shared.client
                .from("messages")
                .select("application_id, sent_at")
                .in("application_id", values: appIds.map { $0.uuidString })
                .execute()
                .value
                
            var latestTimes: [UUID: Date] = [:]
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let fallbackFormatter = ISO8601DateFormatter()
            
            for ts in timestamps {
                if let date = isoFormatter.date(from: ts.sent_at) ?? fallbackFormatter.date(from: ts.sent_at) {
                    if let current = latestTimes[ts.application_id] {
                        if date > current { latestTimes[ts.application_id] = date }
                    } else {
                        latestTimes[ts.application_id] = date
                    }
                }
            }
            self.lastMessageTimes = latestTimes
            
            // Re-apply filters to sort
            applyFilters(search: searchText, filter: selectedStatusFilter)
            
        } catch {
            print("Failed to fetch message timestamps: \\(error)")
        }
    }
}
