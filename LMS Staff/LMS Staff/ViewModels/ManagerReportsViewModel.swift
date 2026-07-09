//
//  ManagerReportsViewModel.swift
//  LMS Staff
//
//  ViewModel for the Manager Reports analytics dashboard.
//  Fetches consolidated branch-wide active loans, applications, and trends from Supabase.
//

import Foundation
import Combine

struct ProductMetricsItem: Identifiable, Hashable {
    let id = UUID()
    let productName: String
    let avgInterestRate: Double
    let avgLoanAmount: Double
}

struct ManagerApprovedTrendPoint: Identifiable, Codable {
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
class ManagerReportsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    // Key metrics
    @Published var totalPortfolioValue: Double = 0
    @Published var activeLoansCount: Int = 0
    @Published var npaRatio: Double = 0
    @Published var collectionEfficiency: Double = 0
    @Published var totalDisbursed: Double = 0
    @Published var avgInterestRate: Double = 0
    @Published var totalLoansCount: Int = 0
    @Published var npaCount: Int = 0
    @Published var restructuredCount: Int = 0
    @Published var closedCount: Int = 0
    @Published var totalOverdueAmount: Double = 0
    
    // Chart data
    @Published var statusSlices: [LoanStatusSlice] = []
    @Published var productMix: [ProductMixItem] = []
    @Published var collectionTrends: [CollectionTrendItem] = []
    @Published var overdueAging: [OverdueAgingBucket] = []
    @Published var monthlyDisbursements: [MonthlyDisbursement] = []
    @Published var productMetrics: [ProductMetricsItem] = []
    @Published var disbursementWeekly: [ManagerApprovedTrendPoint] = []
    @Published var disbursementMonthly: [ManagerApprovedTrendPoint] = []
    @Published var disbursementYearly: [ManagerApprovedTrendPoint] = []
    
    // Loans table
    @Published var loans: [LoanWithDetails] = []
    
    // State
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let portfolioService = LoanPortfolioService.shared
    private let reportService = ReportService.shared
    
    init() {}
    
    // MARK: - Load Data
    
    func loadReports() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch all loans, applications, and collection trends in parallel (consolidated)
            async let loansTask = portfolioService.fetchLoans()
            async let appsTask = ApplicationService.shared.fetchAllApplications()
            async let trendsTask = reportService.fetchCollectionTrends()
            
            let (fetchedLoans, fetchedApps, trends) = try await (loansTask, appsTask, trendsTask)
            
            self.loans = fetchedLoans
            self.collectionTrends = trends
            
            computeMetrics(from: fetchedLoans)
            computeChartData(from: fetchedLoans, applications: fetchedApps)
            
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Metric Computation
    
    private func computeMetrics(from loans: [LoanWithDetails]) {
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
        
        // Collection efficiency from EMI data
        if let lastTrend = collectionTrends.last {
            collectionEfficiency = lastTrend.efficiency
        } else {
            collectionEfficiency = 100.0
        }
    }
    
    private func computeChartData(from loans: [LoanWithDetails], applications: [ApplicationWithBorrower]) {
        let allLoans = loans.map { $0.loan }
        
        // 1. Status Distribution (Applications + Loans)
        var statusGroups: [String: (count: Int, amount: Double)] = [:]
        
        // Add all applications that are NOT disbursed and NOT draft
        for app in applications {
            if app.application.status != .disbursed && app.application.status != .draft {
                let key = app.application.status.displayName
                var entry = statusGroups[key] ?? (count: 0, amount: 0)
                entry.count += 1
                entry.amount += app.application.requestedAmount
                statusGroups[key] = entry
            }
        }
        
        // Add all active/disbursed loans
        for loan in allLoans {
            let key = loan.status.displayName
            var entry = statusGroups[key] ?? (count: 0, amount: 0)
            entry.count += 1
            entry.amount += loan.outstandingPrincipal
            statusGroups[key] = entry
        }
        
        statusSlices = statusGroups.map { LoanStatusSlice(status: $0.key, count: $0.value.count, amount: $0.value.amount) }
            .sorted { $0.count > $1.count }
        
        self.totalLoansCount = statusSlices.reduce(0) { $0 + $1.count }
        
        // 2. Product Mix
        var productGroups: [String: (count: Int, amount: Double)] = [:]
        for item in loans {
            let key = item.product.name
            var entry = productGroups[key] ?? (count: 0, amount: 0)
            entry.count += 1
            entry.amount += item.loan.principalAmount
            productGroups[key] = entry
        }
        productMix = productGroups.map { ProductMixItem(productName: $0.key, count: $0.value.count, totalAmount: $0.value.amount) }
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
            .map { OverdueAgingBucket(label: $0.key, count: $0.value.count, amount: $0.value.amount, sortOrder: $0.value.order) }
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
            .map { MonthlyDisbursement(month: $0.key, amount: $0.value.amount) }
            .sorted { lhs, rhs in
                let lhsKey = monthlyGroups[lhs.month]?.sortKey ?? ""
                let rhsKey = monthlyGroups[rhs.month]?.sortKey ?? ""
                return lhsKey < rhsKey
            }
        
        // 5. Product Metrics (Average Interest Rate and Average Loan Size) - Purely Database-Driven
        var productGroupDetails: [String: (totalInterest: Double, totalAmount: Double, count: Int)] = [:]
        for item in loans {
            let name = item.product.name
            var entry = productGroupDetails[name] ?? (totalInterest: 0, totalAmount: 0, count: 0)
            entry.totalInterest += item.loan.interestRate
            entry.totalAmount += item.loan.principalAmount
            entry.count += 1
            productGroupDetails[name] = entry
        }
        
        productMetrics = productGroupDetails.map { name, details in
            ProductMetricsItem(
                productName: name,
                avgInterestRate: details.count > 0 ? details.totalInterest / Double(details.count) : 0,
                avgLoanAmount: details.count > 0 ? details.totalAmount / Double(details.count) : 0
            )
        }
        
        // 6. Disbursement Trend (Weekly, Monthly, Yearly) - Purely Database-Driven
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
            
            // Month group
            let monthIndex = calendar.component(.month, from: disbDate) - 1
            if monthIndex >= 0 && monthIndex < 12 {
                let monthName = orderedMonths[monthIndex]
                monthlyMap[monthName, default: 0] += amount
            }
            
            // Week group
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
        
        disbursementWeekly = ["Week 1", "Week 2", "Week 3", "Week 4", "Week 5"].map { week in
            ManagerApprovedTrendPoint(label: week, amount: weeklyMap[week] ?? 0)
        }
        
        disbursementMonthly = orderedMonths.map { month in
            ManagerApprovedTrendPoint(label: month, amount: monthlyMap[month] ?? 0)
        }
        
        if yearlyMap.isEmpty {
            let currentYear = calendar.component(.year, from: now)
            disbursementYearly = (currentYear-2...currentYear).map { year in
                ManagerApprovedTrendPoint(label: String(year), amount: 0)
            }
        } else {
            disbursementYearly = yearlyMap.keys.sorted().map { year in
                ManagerApprovedTrendPoint(label: year, amount: yearlyMap[year] ?? 0)
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

// MARK: - Helper Model Structs

struct LoanStatusSlice: Identifiable, Hashable {
    var id: String { status }
    let status: String
    let count: Int
    let amount: Double
}

struct ProductMixItem: Identifiable, Hashable {
    var id: String { productName }
    let productName: String
    let count: Int
    let totalAmount: Double
}

struct OverdueAgingBucket: Identifiable, Hashable {
    var id: String { label }
    let label: String
    let count: Int
    let amount: Double
    let sortOrder: Int
}

struct MonthlyDisbursement: Identifiable, Hashable {
    var id: String { month }
    let month: String
    let amount: Double
}
