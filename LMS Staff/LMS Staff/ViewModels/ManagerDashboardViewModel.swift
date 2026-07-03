//
//  ManagerDashboardViewModel.swift
//  LMS Staff
//
//  ViewModel for branch managers, managing approvals, segmented queues, and dashboard analytics.
//

import Foundation
import Combine
import Supabase
import PostgREST

@MainActor
class ManagerDashboardViewModel: ObservableObject {
    
    // MARK: - Segment Control Queues
    
    @Published var recommendedApplications: [ApplicationWithBorrower] = []
    @Published var sentBackApplications: [ApplicationWithBorrower] = []
    @Published var rejectedApplications: [ApplicationWithBorrower] = []
    @Published var approvedApplications: [ApplicationWithBorrower] = []
    
    @Published var chatApplications: [ApplicationWithBorrower] = []
    
    // MARK: - Portfolio KPIs
    
    @Published var activeLoansList: [LoanWithDetails] = []
    @Published var activeLoansCount: Int = 0
    @Published var totalDisbursed: Double = 0.0
    @Published var npaRatio: Double = 0.0
    @Published var collectionEfficiency: Double = 100.0
    
    // MARK: - Chart Data
    
    @Published var collectionTrends: [CollectionTrendItem] = []
    @Published var portfolioBreakdown: [(status: String, count: Int, amount: Double)] = []
    @Published var npaAgingBuckets: [(range: String, count: Int, amount: Double)] = []
    
    @Published var availableOfficers: [StaffWithUser] = []
    
    @Published var isLoading: Bool = false
    @Published var isActionLoading: Bool = false
    @Published var errorMessage: String?
    
    private let appService = ApplicationService.shared
    private let reportService = ReportService.shared
    
    init() {}
    
    /// Loads portfolio aggregation dashboard numbers, recommendation queues, and chart data
    func loadDashboard() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 1. Fetch consolidated reports metrics
            let report = try await reportService.compileConsolidatedReport()
            self.totalDisbursed = report.totalDisbursed
            self.npaRatio = report.npaRatio
            self.collectionEfficiency = report.collectionEfficiency
            
            // 2. Fetch loans for portfolio
            let allLoans = try await LoanPortfolioService.shared.fetchLoans()
            self.activeLoansList = allLoans.filter {
                $0.loan.status == .active || $0.loan.status == .restructured ||
                $0.loan.status == .npa
            }
            self.activeLoansCount = self.activeLoansList.count
            
            // 3. Compute portfolio breakdown for donut chart
            computePortfolioBreakdown(allLoans)
            
            // 4. Compute NPA aging buckets
            computeNPAAgingBuckets(allLoans)
            
            // 5. Fetch collection trends for sparkline
            self.collectionTrends = try await reportService.fetchCollectionTrends()
            
            // 6. Fetch all applications and segment them
            let allApplications = try await appService.fetchAllApplications()
            self.recommendedApplications = allApplications.filter { $0.application.status == .underReview }
            self.sentBackApplications = allApplications.filter { $0.application.status == .sentBack }
            self.rejectedApplications = allApplications.filter { $0.application.status == .rejected }
            self.approvedApplications = allApplications.filter {
                $0.application.status == .approved || $0.application.status == .pendingAcceptance
            }
            self.chatApplications = allApplications
            await fetchMessageTimestamps()
            
            // 7. Fetch officers
            let allStaff = try await StaffManagementService.shared.fetchStaff()
            self.availableOfficers = allStaff.filter { $0.user.role == .officer }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Chart Computations
    
    private func computePortfolioBreakdown(_ allLoans: [LoanWithDetails]) {
        var statusMap: [String: (count: Int, amount: Double)] = [:]
        let relevantStatuses: [LoanStatus] = [.active, .npa, .restructured, .closed, .writtenOff]
        
        for loan in allLoans {
            guard relevantStatuses.contains(loan.loan.status) else { continue }
            let key = loan.loan.status.displayName
            var current = statusMap[key] ?? (count: 0, amount: 0)
            current.count += 1
            current.amount += loan.loan.outstandingPrincipal + loan.loan.outstandingInterest
            statusMap[key] = current
        }
        
        self.portfolioBreakdown = statusMap.map { (status: $0.key, count: $0.value.count, amount: $0.value.amount) }
            .sorted { $0.amount > $1.amount }
    }
    
    private func computeNPAAgingBuckets(_ allLoans: [LoanWithDetails]) {
        let npaLoans = allLoans.filter { $0.loan.status == .npa }
        
        var buckets: [String: (count: Int, amount: Double)] = [
            "30–60 days": (0, 0),
            "60–90 days": (0, 0),
            "90–180 days": (0, 0),
            "180+ days": (0, 0)
        ]
        
        for loan in npaLoans {
            let days = loan.loan.overdueDays
            let outstanding = loan.loan.outstandingPrincipal + loan.loan.outstandingInterest
            if days >= 180 {
                buckets["180+ days"]!.count += 1
                buckets["180+ days"]!.amount += outstanding
            } else if days >= 90 {
                buckets["90–180 days"]!.count += 1
                buckets["90–180 days"]!.amount += outstanding
            } else if days >= 60 {
                buckets["60–90 days"]!.count += 1
                buckets["60–90 days"]!.amount += outstanding
            } else {
                buckets["30–60 days"]!.count += 1
                buckets["30–60 days"]!.amount += outstanding
            }
        }
        
        let order = ["30–60 days", "60–90 days", "90–180 days", "180+ days"]
        self.npaAgingBuckets = order.map { (range: $0, count: buckets[$0]!.count, amount: buckets[$0]!.amount) }
    }
    
    // MARK: - Message Timestamps
    
    private func fetchMessageTimestamps() async {
        let appIds = chatApplications.map { $0.application.id }
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
            
            // Sort by latest message
            self.chatApplications.sort { app1, app2 in
                let date1 = latestTimes[app1.application.id] ?? .distantPast
                let date2 = latestTimes[app2.application.id] ?? .distantPast
                return date1 > date2
            }
            
        } catch {
            print("Failed to fetch message timestamps: \\(error)")
        }
    }
    
    // MARK: - Actions
    
    func approveApplication(applicationId: UUID, approvedAmount: Double, tenureMonths: Int, interestRate: Double) async -> Bool {
        guard !isActionLoading else { return false }
        isActionLoading = true
        defer { isActionLoading = false }
        
        do {
            try await SupabaseManager.shared.database
                .from("loan_applications")
                .update([
                    "requested_amount": AnyEncodable(approvedAmount),
                    "requested_tenure_months": AnyEncodable(tenureMonths),
                    "status": AnyEncodable(ApplicationStatus.pendingAcceptance.rawValue),
                    "decided_at": AnyEncodable(ISO8601DateFormatter().string(from: Date()))
                ])
                .eq("id", value: applicationId)
                .execute()
                
            // Record history
            try await appService.addApprovalHistory(
                applicationId: applicationId,
                action: "approve",
                toStatus: ApplicationStatus.pendingAcceptance.rawValue,
                remarks: "Approved terms: INR \(approvedAmount), Rate: \(interestRate)%, Tenure: \(tenureMonths) months.",
                approvedAmount: approvedAmount,
                approvedTenure: tenureMonths,
                approvedRate: interestRate
            )
            
            await loadDashboard()
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
    
    func rejectApplication(applicationId: UUID, reason: String) async -> Bool {
        guard !isActionLoading else { return false }
        isActionLoading = true
        defer { isActionLoading = false }
        
        do {
            try await appService.updateStatus(applicationId: applicationId, status: .rejected, reason: reason)
            await loadDashboard()
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
    
    func sendBackApplication(applicationId: UUID, remarks: String) async -> Bool {
        do {
            try await appService.updateStatus(applicationId: applicationId, status: .sentBack, reason: remarks)
            await loadDashboard()
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
    
    func reassignOfficer(applicationId: UUID, newOfficerId: UUID) async -> Bool {
        do {
            try await SupabaseManager.shared.database
                .from("loan_applications")
                .update(["assigned_officer_id": AnyEncodable(newOfficerId)])
                .eq("id", value: applicationId)
                .execute()
            
            try await AuditService.shared.logAction(
                action: "REASSIGN",
                tableName: "loan_applications",
                recordId: applicationId,
                summary: "Reassigned to officer \(newOfficerId.uuidString)"
            )
            
            await loadDashboard()
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
}
