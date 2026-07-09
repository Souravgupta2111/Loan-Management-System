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
    @Published var selectedStatusFilter: String = "Under Review" {
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
        let activeApps = applications.filter { $0.application.status != .disbursed }
        statsPendingCount = activeApps.filter { $0.application.status == .submitted }.count
        statsUnderReviewCount = activeApps.filter { $0.application.status == .underReview }.count
        statsApprovedCount = activeApps.filter { $0.application.status == .sentBack }.count
        statsRejectedCount = activeApps.filter { $0.application.status == .rejected }.count
    }
    
    private func statusPriority(_ status: ApplicationStatus) -> Int {
        switch status {
        case .submitted:         return 1
        case .sentBack:          return 2
        case .pendingAcceptance: return 3
        default:                 return 4
        }
    }
    
    private func applyFilters(search: String, filter: String) {
        var result = applications
        
        // Exclude disbursed loans completely except when viewing All (like in Messages)
        if filter != "All" {
            result = result.filter { $0.application.status != .disbursed }
        }
        
        // Apply status filter
        if filter != "All" {
            result = result.filter { app in
                if filter == "Under Review" {
                    return app.application.status == .submitted
                } else if filter == "Submitted" {
                    return app.application.status == .underReview
                } else {
                    return app.application.status.displayName == filter
                }
            }
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
        
        if filter != "All" {
            // Sort by status priority: submitted first, then sentBack, then pendingAcceptance, and then others
            result.sort { app1, app2 in
                let p1 = statusPriority(app1.application.status)
                let p2 = statusPriority(app2.application.status)
                if p1 != p2 {
                    return p1 < p2
                }
                // Tie-breaker: latest message or date
                let date1 = lastMessageTimes[app1.application.id] ?? (app1.application.createdAt ?? .distantPast)
                let date2 = lastMessageTimes[app2.application.id] ?? (app2.application.createdAt ?? .distantPast)
                return date1 > date2
            }
        } else {
            // Sort strictly by latest message (or creation date) for the Chat support room list
            result.sort { app1, app2 in
                let date1 = lastMessageTimes[app1.application.id] ?? (app1.application.createdAt ?? .distantPast)
                let date2 = lastMessageTimes[app2.application.id] ?? (app2.application.createdAt ?? .distantPast)
                return date1 > date2
            }
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
