//
//  OfficerReportsViewModel.swift
//  LMS Staff
//
//  ViewModel for the Officer Reports analytics dashboard.
//  Fetches the officer's assigned loans and computes all metrics from real Supabase data.
//

import Foundation
import Combine

// MARK: - Chart Data Models

struct OfcLoanStatusSlice: Identifiable {
    let id = UUID()
    let status: String
    let count: Int
    let amount: Double
}

struct OfcProductMixItem: Identifiable {
    let id = UUID()
    let productName: String
    let count: Int
    let totalAmount: Double
}

struct OfcOverdueAgingBucket: Identifiable {
    let id = UUID()
    let label: String
    let count: Int
    let amount: Double
    let sortOrder: Int
}

struct OfcMonthlyDisbursement: Identifiable {
    let id = UUID()
    let month: String
    let amount: Double
}

struct CustomerResponseItem: Identifiable, Hashable {
    let id = UUID()
    let status: String
    let count: Int
}

struct ApprovedTrendPoint: Identifiable, Codable {
    let id: UUID
    let label: String
    let amount: Double
    
    init(id: UUID = UUID(), label: String, amount: Double) {
        self.id = id
        self.label = label
        self.amount = amount
    }
}

@MainActor
class OfficerReportsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    // Key metrics
    @Published var totalPortfolioValue: Double = 0
    @Published var activeLoansCount: Int = 0
    @Published var npaRatio: Double = 0
    @Published var collectionEfficiency: Double = 0
    @Published var totalDisbursed: Double = 0
    @Published var avgInterestRate: Double = 0
    @Published var totalLoansCount: Int = 0
    @Published var totalApplicationsCount: Int = 0
    @Published var npaCount: Int = 0
    @Published var restructuredCount: Int = 0
    @Published var closedCount: Int = 0
    @Published var totalOverdueAmount: Double = 0
    
    // Chart data
    @Published var statusSlices: [OfcLoanStatusSlice] = []
    @Published var productMix: [OfcProductMixItem] = []
    @Published var collectionTrends: [CollectionTrendItem] = []
    @Published var overdueAging: [OfcOverdueAgingBucket] = []
    @Published var monthlyDisbursements: [OfcMonthlyDisbursement] = []
    @Published var customerResponses: [CustomerResponseItem] = []
    @Published var approvedWeekly: [ApprovedTrendPoint] = []
    @Published var approvedMonthly: [ApprovedTrendPoint] = []
    @Published var approvedYearly: [ApprovedTrendPoint] = []
    
    // Loans table
    @Published var loans: [LoanWithDetails] = []
    
    // State
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let portfolioService = LoanPortfolioService.shared
    private let reportService = ReportService.shared
    
    init() {}
    
    // MARK: - Load Data
    
    func loadReports(forOfficerId officerId: UUID) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch officer's loans, applications, and collection trends in parallel
            async let loansTask = portfolioService.fetchLoans(officerId: officerId)
            async let appsTask = ApplicationService.shared.fetchApplications(forOfficerId: officerId)
            async let trendsTask = reportService.fetchCollectionTrends()
            async let efficiencyTask = reportService.fetchOverallCollectionEfficiency()
            
            let (fetchedLoans, fetchedApps, trends, overallEfficiency) = try await (loansTask, appsTask, trendsTask, efficiencyTask)
            
            self.loans = fetchedLoans
            self.collectionTrends = trends
            
            computeMetrics(from: fetchedLoans, overallEfficiency: overallEfficiency)
            computeChartData(from: fetchedLoans, applications: fetchedApps)
            
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Metric Computation
    
    private func computeMetrics(from loans: [LoanWithDetails], overallEfficiency: Double) {
        let allLoans = loans.map { $0.loan }
        totalLoansCount = allLoans.count
        
        // Active portfolio loans (active, NPA, restructured)
        let portfolioLoans = allLoans.filter { $0.status == .active || $0.status == .npa || $0.status == .restructured }
        
        // Key counts
        activeLoansCount = allLoans.filter { $0.status == .active }.count
        npaCount = allLoans.filter { $0.status == .npa }.count
        restructuredCount = allLoans.filter { $0.status == .restructured }.count
        closedCount = allLoans.filter { $0.status == .closed }.count
        
        // Total portfolio value (outstanding principal + interest)
        totalPortfolioValue = portfolioLoans.reduce(0.0) { $0 + $1.outstandingPrincipal + $1.outstandingInterest }
        
        // Total disbursed
        totalDisbursed = allLoans.reduce(0.0) { $0 + $1.principalAmount }
        
        // NPA ratio
        let npaPortfolio = allLoans.filter { $0.status == .npa }.reduce(0.0) { $0 + $1.outstandingPrincipal + $1.outstandingInterest }
        npaRatio = totalPortfolioValue > 0 ? (npaPortfolio / totalPortfolioValue) * 100.0 : 0.0
        
        // Average interest rate across active portfolio
        if !portfolioLoans.isEmpty {
            avgInterestRate = portfolioLoans.reduce(0.0) { $0 + $1.interestRate } / Double(portfolioLoans.count)
        }
        
        // Total overdue
        totalOverdueAmount = portfolioLoans.reduce(0.0) { $0 + $1.totalOverdue }
        
        // Collection efficiency from EMI data (all-time overall calculation)
        collectionEfficiency = overallEfficiency
    }
    
    private func computeChartData(from loans: [LoanWithDetails], applications: [ApplicationWithBorrower]) {
        let allLoans = loans.map { $0.loan }
        
        // 1. Calculate active applications count (excluding draft, disbursed, pending disbursal, and pending acceptance)
        let activeApps = applications.filter {
            $0.application.status != .disbursed &&
            $0.application.status != .draft &&
            $0.application.status != .pendingDisbursal &&
            $0.application.status != .pendingAcceptance
        }
        totalApplicationsCount = activeApps.count
        
        // 2. Status Distribution (Applications + Loans)
        var statusGroups: [String: (count: Int, amount: Double)] = [:]
        
        // Add all applications that match filters
        for app in applications {
            let status = app.application.status
            if status != .disbursed &&
               status != .draft &&
               status != .pendingDisbursal &&
               status != .pendingAcceptance {
                let key = status.displayName
                var entry = statusGroups[key] ?? (count: 0, amount: 0)
                entry.count += 1
                entry.amount += app.application.requestedAmount
                statusGroups[key] = entry
            }
        }
        
        // Add all active/disbursed loans
        for loan in allLoans {
            let status = loan.status
            if status != .pendingAcceptance {
                let key = status.displayName
                var entry = statusGroups[key] ?? (count: 0, amount: 0)
                entry.count += 1
                entry.amount += loan.outstandingPrincipal
                statusGroups[key] = entry
            }
        }
        
        statusSlices = statusGroups.map { OfcLoanStatusSlice(status: $0.key, count: $0.value.count, amount: $0.value.amount) }
            .sorted { $0.count > $1.count }
        
        // NOTE: `totalLoansCount` is the actual loan count set in computeMetrics.
        // Do NOT overwrite it with the status-slice total here — that mixes in
        // pending applications and makes this KPI disagree with other screens.
        
        // 2. Product Mix
        var productGroups: [String: (count: Int, amount: Double)] = [:]
        for item in loans {
            let key = item.product.name
            var entry = productGroups[key] ?? (count: 0, amount: 0)
            entry.count += 1
            entry.amount += item.loan.principalAmount
            productGroups[key] = entry
        }
        productMix = productGroups.map { OfcProductMixItem(productName: $0.key, count: $0.value.count, totalAmount: $0.value.amount) }
            .sorted { $0.totalAmount > $1.totalAmount }
        
        // 3. Overdue Aging Buckets
        let overdueLoans = allLoans.filter { $0.overdueDays > 0 }
        var buckets: [String: (count: Int, amount: Double, order: Int)] = [
            "0-30 Days": (0, 0, 0),
            "31-60 Days": (0, 0, 1),
            "61-90 Days": (0, 0, 2),
            "90+ Days": (0, 0, 3)
        ]
        for loan in overdueLoans {
            let bucket: String
            if loan.overdueDays <= 30 { bucket = "0-30 Days" }
            else if loan.overdueDays <= 60 { bucket = "31-60 Days" }
            else if loan.overdueDays <= 90 { bucket = "61-90 Days" }
            else { bucket = "90+ Days" }
            
            buckets[bucket]!.count += 1
            buckets[bucket]!.amount += loan.totalOverdue
        }
        overdueAging = buckets
            .filter { $0.value.count > 0 || true } // Show all buckets for chart context
            .map { OfcOverdueAgingBucket(label: $0.key, count: $0.value.count, amount: $0.value.amount, sortOrder: $0.value.order) }
            .sorted { $0.sortOrder < $1.sortOrder }
        
        // 4. Monthly Disbursements
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM yy"
        
        var monthlyGroups: [String: (amount: Double, sortKey: String)] = [:]
        for loan in allLoans {
            guard let disbDateStr = loan.disbursementDate,
                  let disbDate = dateFormatter.date(from: disbDateStr) else { continue }
            let displayMonth = displayFormatter.string(from: disbDate)
            let sortKey = String(disbDateStr.prefix(7))
            var entry = monthlyGroups[displayMonth] ?? (amount: 0, sortKey: sortKey)
            entry.amount += loan.principalAmount
            monthlyGroups[displayMonth] = entry
        }
        monthlyDisbursements = monthlyGroups
            .map { OfcMonthlyDisbursement(month: $0.key, amount: $0.value.amount) }
            .sorted { lhs, rhs in
                let lhsKey = monthlyGroups[lhs.month]?.sortKey ?? ""
                let rhsKey = monthlyGroups[rhs.month]?.sortKey ?? ""
                return lhsKey < rhsKey
            }
        
        // 5. Customer Responses (waiting status - Purely Database-Driven)
        let sentBackCount = applications.filter { $0.application.status == .sentBack }.count
        let pendingAcceptanceCount = applications.filter { $0.application.status == .pendingAcceptance }.count
        let underReviewCount = applications.filter { $0.application.status == .underReview }.count
        let submittedCount = applications.filter { $0.application.status == .submitted }.count
        
        customerResponses = [
            CustomerResponseItem(status: "Documents Awaited", count: sentBackCount),
            CustomerResponseItem(status: "Customer Contacted", count: pendingAcceptanceCount),
            CustomerResponseItem(status: "Follow-up Scheduled", count: underReviewCount),
            CustomerResponseItem(status: "Ready for Review", count: submittedCount)
        ]
        
        // 6. Approved Loans Trend (Purely Database-Driven)
        let calendar = Calendar.current
        let now = Date()
        
        var weeklyMap: [String: Double] = ["Week 1": 0, "Week 2": 0, "Week 3": 0, "Week 4": 0, "Week 5": 0]
        var monthlyMap: [String: Double] = [:]
        var yearlyMap: [String: Double] = [:]
        
        let orderedMonths = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        
        let dbDateFormatter = DateFormatter()
        dbDateFormatter.dateFormat = "yyyy-MM-dd"
        
        for loan in allLoans {
            guard let disbDateStr = loan.disbursementDate,
                  let disbDate = dbDateFormatter.date(from: disbDateStr) else { continue }
            
            let amount = loan.principalAmount
            
            // Year group
            let year = String(calendar.component(.year, from: disbDate))
            yearlyMap[year, default: 0] += amount
            
            // Month group (MMM format, e.g. "Jan")
            let monthIndex = calendar.component(.month, from: disbDate) - 1
            if monthIndex >= 0 && monthIndex < 12 {
                let monthName = orderedMonths[monthIndex]
                monthlyMap[monthName, default: 0] += amount
            }
            
            // Week group (if it is in the current month and year)
            if calendar.isDate(disbDate, equalTo: now, toGranularity: .month) &&
               calendar.isDate(disbDate, equalTo: now, toGranularity: .year) {
                let day = calendar.component(.day, from: disbDate)
                let weekKey: String
                if day <= 7 { weekKey = "Week 1" }
                else if day <= 14 { weekKey = "Week 2" }
                else if day <= 21 { weekKey = "Week 3" }
                else if day <= 28 { weekKey = "Week 4" }
                else { weekKey = "Week 5" }
                weeklyMap[weekKey, default: 0] += amount
            }
        }
        
        approvedWeekly = ["Week 1", "Week 2", "Week 3", "Week 4", "Week 5"].map { week in
            ApprovedTrendPoint(label: week, amount: weeklyMap[week] ?? 0)
        }
        
        approvedMonthly = orderedMonths.map { month in
            ApprovedTrendPoint(label: month, amount: monthlyMap[month] ?? 0)
        }
        
        // Show years with data, or show last 3 years if empty
        if yearlyMap.isEmpty {
            let currentYear = calendar.component(.year, from: now)
            approvedYearly = (currentYear-2...currentYear).map { year in
                ApprovedTrendPoint(label: String(year), amount: 0)
            }
        } else {
            approvedYearly = yearlyMap.keys.sorted().map { year in
                ApprovedTrendPoint(label: year, amount: yearlyMap[year] ?? 0)
            }
        }
    }
    
    // MARK: - Formatting Helpers
    
    func formatCurrency(_ value: Double) -> String {
        if value >= 10_000_000 {
            return String(format: "₹%.1fCr", value / 10_000_000)
        } else if value >= 100_000 {
            return String(format: "₹%.1fL", value / 100_000)
        } else if value >= 1000 {
            return String(format: "₹%.1fK", value / 1000)
        }
        return String(format: "₹%.0f", value)
    }
    
    func formatPercent(_ value: Double) -> String {
        return String(format: "%.1f%%", value)
    }
}
