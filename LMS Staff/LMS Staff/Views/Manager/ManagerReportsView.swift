//
//  ManagerReportsView.swift
//  LMS Staff
//
//  Visually rich analytics dashboard for branch managers.
//  Features colorful stat cards, Swift Charts (donut, bar, line, area), overdue aging, and a loans table.
//

import SwiftUI
import Charts
import UIKit

struct ManagerReportsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var vm = ManagerReportsViewModel()
    @State private var showShareSheet = false
    @State private var exportFileURL: URL?
    @State private var isExporting = false
    @State private var approvedFilter: ApprovedFilter = .weekly
    
    private enum ApprovedFilter: String, CaseIterable, Identifiable {
        case weekly = "Weekly"
        case monthly = "Monthly"
        case yearly = "Yearly"
        
        var id: String { rawValue }
    }
    
    // Chart color palettes
    private let statusColors: [Color] = [
        Color.staffAccent, // Green — Active
        Color(hex: "#D9534F"), // Red — NPA
        Color(hex: "#C89A24"), // Amber — Restructured
        Color(hex: "#71786F"), // Gray — Closed
        Color.staffPurple, // Teal — Other
        Color(hex: "#B98222"), // Orange
    ]
    
    private let productColors: [Color] = [
        Color.staffAccent,
        Color.staffTeal,
        Color(hex: "#C89A24"),
        Color.staffPurple,
        Color(hex: "#B98222"),
        Color(hex: "#D9534F"),
    ]
    
    private let agingColors: [Color] = [
        Color.staffAccent, // 0-30 green
        Color(hex: "#C89A24"), // 31-60 amber
        Color(hex: "#B98222"), // 61-90 orange
        Color(hex: "#D9534F"), // 90+ red
    ]
    
    var body: some View {
        Group {
            if vm.isLoading {
                ReportsSkeletonView()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: StaffSpacing.xxl) {
                        headerSection
                        keyMetricsGrid
                        chartsRow1
                        disbursementTrendSection
                        loansTableSection
                    }
                    .padding(StaffSpacing.lg)
                    .padding(.bottom, StaffSpacing.mega)
                }
                .background(Color.staffBackground)
            }
        }
        .task {
            await vm.loadReports()
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("My Analytics")
                    .font(.staffTitle)
                    .foregroundColor(.staffTextPrimary)
                Text("Portfolio analytics & performance overview")
                    .font(.staffCaption)
                    .foregroundColor(.staffTextSecondary)
            }
            
            Spacer()
            
            // Export Menu
            Menu {
                Button(action: { exportCSV() }) {
                    Label("Export as CSV", systemImage: "tablecells")
                }
                Button(action: { exportPDF() }) {
                    Label("Export as PDF", systemImage: "doc.richtext")
                }
            } label: {
                HStack(spacing: 6) {
                    if isExporting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Text("Export")
                }
                .font(.staffCaption.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [Color.staffAccent, Color(hex: Color.currentPalette.darkerHex)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(StaffCorner.sm)
                .shadow(color: Color.staffAccent.opacity(0.25), radius: 4, x: 0, y: 2)
            }
            .disabled(isExporting || vm.loans.isEmpty)
            
            Button(action: {
                Task {
                    await vm.loadReports()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .font(.staffCaption.weight(.semibold))
                .foregroundColor(.staffAccent)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.staffAccentBg)
                .cornerRadius(StaffCorner.sm)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = exportFileURL {
                ShareSheet(activityItems: [url])
            }
        }
    }
    
    // MARK: - Key Metrics Grid (6 cards)
    
    private var keyMetricsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: StaffSpacing.md), count: 3), spacing: StaffSpacing.md) {
            ReportMetricCard(
                icon: "briefcase.fill",
                title: "Portfolio Value",
                value: vm.formatCurrency(vm.totalPortfolioValue),
                subtitle: "\(vm.activeLoansCount + vm.npaCount + vm.restructuredCount) active loans",
                accentColor: Color.staffAccent,
                gradientEnd: Color(hex: Color.currentPalette.darkerHex)
            )
            
            ReportMetricCard(
                icon: "checkmark.circle.fill",
                title: "Active Loans",
                value: "\(vm.activeLoansCount)",
                subtitle: "of \(vm.totalLoansCount) total",
                accentColor: Color.staffTeal,
                gradientEnd: Color(hex: "#2E8A5A")
            )
            
            ReportMetricCard(
                icon: "exclamationmark.triangle.fill",
                title: "NPA Ratio",
                value: vm.formatPercent(vm.npaRatio),
                subtitle: "\(vm.npaCount) NPA loans",
                accentColor: vm.npaRatio > 5 ? Color(hex: "#D9534F") : Color(hex: "#C89A24"),
                gradientEnd: vm.npaRatio > 5 ? Color(hex: "#C0392B") : Color(hex: "#A67D1C")
            )
            
            ReportMetricCard(
                icon: "chart.line.uptrend.xyaxis",
                title: "Collection Efficiency",
                value: vm.formatPercent(vm.collectionEfficiency),
                subtitle: "current period",
                accentColor: vm.collectionEfficiency >= 95 ? Color.staffAccent : Color(hex: "#C89A24"),
                gradientEnd: vm.collectionEfficiency >= 95 ? Color(hex: Color.currentPalette.darkerHex) : Color(hex: "#A67D1C")
            )
            
            ReportMetricCard(
                icon: "banknote.fill",
                title: "Total Disbursed",
                value: vm.formatCurrency(vm.totalDisbursed),
                subtitle: "\(vm.totalLoansCount) loans",
                accentColor: Color.staffPurple,
                gradientEnd: Color(hex: "#2D7A4D")
            )
            
            ReportMetricCard(
                icon: "percent",
                title: "Avg Interest Rate",
                value: String(format: "%.2f%%", vm.avgInterestRate),
                subtitle: "across portfolio",
                accentColor: Color(hex: "#B98222"),
                gradientEnd: Color(hex: "#9A6D1B")
            )
        }
    }
    
    // MARK: - Charts Row 1: Donut + Product Mix
    
    private var chartsRow1: some View {
        HStack(alignment: .top, spacing: StaffSpacing.md) {
            // Donut Chart — Status Distribution
            StaffCard {
                VStack(alignment: .leading, spacing: StaffSpacing.md) {
                    HStack {
                        Image(systemName: "chart.pie.fill")
                            .foregroundColor(.staffAccent)
                        Text("Loan Status Distribution")
                            .font(.staffCardTitle)
                            .foregroundColor(.staffTextPrimary)
                    }
                    
                    if vm.statusSlices.isEmpty {
                        Text("No loan data available")
                            .font(.staffCaption)
                            .foregroundColor(.staffTextTertiary)
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                    } else {
                        Chart(vm.statusSlices) { slice in
                            SectorMark(
                                angle: .value("Count", slice.count),
                                innerRadius: .ratio(0.55),
                                angularInset: 2
                            )
                            .foregroundStyle(colorForStatus(slice.status))
                            .cornerRadius(4)
                        }
                        .frame(height: 200)
                        .chartBackground { _ in
                            VStack(spacing: 2) {
                                Text("\(vm.totalLoansCount)")
                                    .font(.staffLargeAmount)
                                    .foregroundColor(.staffTextPrimary)
                                Text("Total")
                                    .font(.staffCaption)
                                    .foregroundColor(.staffTextSecondary)
                            }
                        }
                        
                        // Legend
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                            ForEach(vm.statusSlices) { slice in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(colorForStatus(slice.status))
                                        .frame(width: 10, height: 10)
                                    Text("\(slice.status) (\(slice.count))")
                                        .font(.staffFinePrint)
                                        .foregroundColor(.staffTextSecondary)
                                    Spacer()
                                }
                            }
                        }
                    }
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, minHeight: 380)
            
            // Average Profitability (Interest Rate)
            StaffCard {
                VStack(alignment: .leading, spacing: StaffSpacing.md) {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(Color.staffTeal)
                        Text("Product Mix")
                            .font(.staffCardTitle)
                            .foregroundColor(.staffTextPrimary)
                    }
                    
                    if vm.productMetrics.isEmpty {
                        Text("No product data available")
                            .font(.staffCaption)
                            .foregroundColor(.staffTextTertiary)
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                    } else {
                        Chart(vm.productMetrics) { item in
                            BarMark(
                                x: .value("Interest Rate", item.avgInterestRate),
                                y: .value("Product", item.productName)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [colorForProduct(item.productName), colorForProduct(item.productName).opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(6)
                            .annotation(position: .trailing, spacing: 4) {
                                Text(String(format: "%.1f%%", item.avgInterestRate))
                                    .font(.staffFinePrint.weight(.semibold))
                                    .foregroundColor(.staffTextSecondary)
                            }
                        }
                        .chartXAxis {
                            AxisMarks(position: .bottom) { value in
                                AxisValueLabel {
                                    if let v = value.as(Double.self) {
                                        Text(String(format: "%.0f%%", v))
                                            .font(.staffFinePrint)
                                    }
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks { value in
                                AxisValueLabel {
                                    if let name = value.as(String.self) {
                                        Text(name)
                                            .font(.staffFinePrint)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                        .frame(height: 200)
                    }
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, minHeight: 380)
        }
    }
    
    // MARK: - Disbursement Trend Section (Full-width)
    
    private var chartsRow2: some View {
        HStack(alignment: .top, spacing: StaffSpacing.md) {
            // Overdue Aging Bar Chart
            StaffCard {
                VStack(alignment: .leading, spacing: StaffSpacing.md) {
                    HStack {
                        Image(systemName: "clock.badge.exclamationmark")
                            .foregroundColor(Color(hex: "#D9534F"))
                        Text("Overdue Aging Analysis")
                            .font(.staffCardTitle)
                            .foregroundColor(.staffTextPrimary)
                        Spacer()
                        Text(vm.formatCurrency(vm.totalOverdueAmount))
                            .font(.staffBadge)
                            .foregroundColor(.staffRed)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.staffRedBg)
                            .cornerRadius(StaffCorner.xs)
                    }
                    
                    Chart(vm.overdueAging) { bucket in
                        BarMark(
                            x: .value("Bucket", bucket.label),
                            y: .value("Count", bucket.count)
                        )
                        .foregroundStyle(agingColors[min(bucket.sortOrder, agingColors.count - 1)])
                        .cornerRadius(6)
                        .annotation(position: .top, spacing: 4) {
                            if bucket.count > 0 {
                                Text("\(bucket.count)")
                                    .font(.staffFinePrint.weight(.bold))
                                    .foregroundColor(.staffTextPrimary)
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let v = value.as(Int.self) {
                                    Text("\(v)")
                                        .font(.staffFinePrint)
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            AxisValueLabel {
                                if let label = value.as(String.self) {
                                    Text(label)
                                        .font(.staffFinePrint)
                                }
                            }
                        }
                    }
                    .frame(height: 200)
                    
                    // Aging legend with amounts
                    HStack(spacing: StaffSpacing.md) {
                        ForEach(Array(vm.overdueAging.enumerated()), id: \.element.id) { index, bucket in
                            VStack(spacing: 2) {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(agingColors[min(index, agingColors.count - 1)])
                                        .frame(width: 8, height: 8)
                                    Text(bucket.label)
                                        .font(.staffFinePrint)
                                }
                                Text(vm.formatCurrency(bucket.amount))
                                    .font(.staffFinePrint.weight(.semibold))
                                    .foregroundColor(.staffTextSecondary)
                            }
                        }
                    }
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, minHeight: 380)
            
            // Monthly Disbursements Area Chart
            StaffCard {
                VStack(alignment: .leading, spacing: StaffSpacing.md) {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                            .foregroundColor(Color.staffPurple)
                        Text("Disbursement Timeline")
                            .font(.staffCardTitle)
                            .foregroundColor(.staffTextPrimary)
                        Spacer()
                        Text(vm.formatCurrency(vm.totalDisbursed))
                            .font(.staffBadge)
                            .foregroundColor(.staffGreen)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.staffGreenBg)
                            .cornerRadius(StaffCorner.xs)
                    }
                    
                    if vm.monthlyDisbursements.isEmpty {
                        Text("No disbursement data")
                            .font(.staffCaption)
                            .foregroundColor(.staffTextTertiary)
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                    } else {
                        Chart(vm.monthlyDisbursements) { item in
                            AreaMark(
                                x: .value("Month", item.month),
                                y: .value("Amount", item.amount)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.staffAccent.opacity(0.4), Color.staffAccent.opacity(0.05)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)
                            
                            LineMark(
                                x: .value("Month", item.month),
                                y: .value("Amount", item.amount)
                            )
                            .foregroundStyle(Color.staffAccent)
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                            
                            PointMark(
                                x: .value("Month", item.month),
                                y: .value("Amount", item.amount)
                            )
                            .foregroundStyle(Color.staffAccent)
                            .symbolSize(30)
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                                AxisValueLabel {
                                    if let v = value.as(Double.self) {
                                        Text(vm.formatCurrency(v))
                                            .font(.staffFinePrint)
                                    }
                                }
                            }
                        }
                        .chartXAxis {
                            AxisMarks { value in
                                AxisValueLabel {
                                    if let month = value.as(String.self) {
                                        Text(month)
                                            .font(.staffFinePrint)
                                    }
                                }
                            }
                        }
                        .frame(height: 200)
                    }
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, minHeight: 380)
        }
    }
    
    // MARK: - Collection Efficiency Trend (full-width)
    
    private var collectionTrendSection: some View {
        StaffCard {
            VStack(alignment: .leading, spacing: StaffSpacing.md) {
                HStack {
                    Image(systemName: "chart.xyaxis.line")
                        .foregroundColor(.staffAccent)
                    Text("Disbursement Growth Trend")
                        .font(.staffCardTitle)
                        .foregroundColor(.staffTextPrimary)
                    
                    Spacer()
                    
                    Picker("Filter", selection: $approvedFilter) {
                        ForEach(ApprovedFilter.allCases) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 200)
                }
                
                let trendData: [ManagerApprovedTrendPoint] = {
                    switch approvedFilter {
                    case .weekly: return vm.disbursementWeekly
                    case .monthly: return vm.disbursementMonthly
                    case .yearly: return vm.disbursementYearly
                    }
                }()
                
                if trendData.isEmpty {
                    Text("No disbursement data available")
                        .font(.staffCaption)
                        .foregroundColor(.staffTextTertiary)
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                } else {
                    Chart {
                        ForEach(vm.collectionTrends) { item in
                            AreaMark(
                                x: .value("Month", item.month),
                                yStart: .value("Base", 0),
                                yEnd: .value("Efficiency", item.efficiency)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.staffAccent.opacity(0.3), Color.staffAccent.opacity(0.02)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)
                            
                            LineMark(
                                x: .value("Month", item.month),
                                y: .value("Efficiency", item.efficiency)
                            )
                            .foregroundStyle(Color.staffAccent)
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 3))
                            
                            PointMark(
                                x: .value("Month", item.month),
                                y: .value("Efficiency", item.efficiency)
                            )
                            .foregroundStyle(item.efficiency >= 95 ? Color.staffAccent : Color(hex: "#D9534F"))
                            .symbolSize(40)
                            .annotation(position: .top, spacing: 4) {
                                Text(String(format: "%.0f%%", item.efficiency))
                                    .font(.staffFinePrint.weight(.bold))
                                    .foregroundColor(item.efficiency >= 95 ? .staffGreen : .staffRed)
                            }
                        }
                        
                        LineMark(
                            x: .value("Timeframe", item.label),
                            y: .value("Amount", item.amount)
                        )
                        .foregroundStyle(Color(hex: "#2E9658"))
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        
                        PointMark(
                            x: .value("Timeframe", item.label),
                            y: .value("Amount", item.amount)
                        )
                        .foregroundStyle(Color(hex: "#2E9658"))
                        .symbolSize(40)
                        .annotation(position: .top, spacing: 4) {
                            Text(vm.formatCurrency(item.amount))
                                .font(.staffFinePrint.weight(.bold))
                                .foregroundColor(.staffGreen)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text(vm.formatCurrency(v))
                                        .font(.staffFinePrint)
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            AxisValueLabel {
                                if let label = value.as(String.self) {
                                    Text(label)
                                        .font(.staffFinePrint)
                                }
                            }
                        }
                    }
                    .frame(height: 200)
                }
            }
        }
    }
    
    // MARK: - Loans Summary Table
    
    private var loansTableSection: some View {
        StaffCard {
            VStack(alignment: .leading, spacing: StaffSpacing.md) {
                HStack {
                    Image(systemName: "tablecells.fill")
                        .foregroundColor(.staffAccent)
                    Text("Loans Summary")
                        .font(.staffCardTitle)
                        .foregroundColor(.staffTextPrimary)
                    Spacer()
                    Text("\(vm.loans.count) loans")
                        .font(.staffBadge)
                        .foregroundColor(.staffTextSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.staffSurfaceLight)
                        .cornerRadius(StaffCorner.xs)
                }
                
                if vm.loans.isEmpty {
                    Text("No loans assigned to you.")
                        .font(.staffCaption)
                        .foregroundColor(.staffTextTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, StaffSpacing.xxl)
                } else {
                    // Table Header
                    HStack(spacing: 0) {
                        tableHeaderCell("Loan #", width: 130)
                        tableHeaderCell("Borrower", width: 160)
                        tableHeaderCell("Product", width: 180)
                        tableHeaderCell("Principal", width: 120)
                        tableHeaderCell("Outstanding", width: 120)
                        tableHeaderCell("Rate", width: 80)
                        tableHeaderCell("Status", width: 110)
                        tableHeaderCell("Overdue", width: 80)
                    }
                    .padding(.vertical, 10)
                    .background(Color.staffAccent.opacity(0.08))
                    .cornerRadius(StaffCorner.sm)
                    
                    // Table Rows
                    ForEach(Array(vm.loans.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 0) {
                            Text(item.loan.loanNumber ?? "—")
                                .font(.staffFinePrint.weight(.medium))
                                .foregroundColor(.staffTextPrimary)
                                .frame(width: 130, alignment: .leading)
                            
                            Text(item.borrower.fullName)
                                .font(.staffFinePrint)
                                .foregroundColor(.staffTextPrimary)
                                .lineLimit(1)
                                .frame(width: 160, alignment: .leading)
                            
                            Text(item.product.name)
                                .font(.staffFinePrint)
                                .foregroundColor(.staffTextSecondary)
                                .lineLimit(1)
                                .frame(width: 180, alignment: .leading)
                            
                            Text(vm.formatCurrency(item.loan.principalAmount))
                                .font(.staffFinePrint.weight(.medium))
                                .foregroundColor(.staffTextPrimary)
                                .frame(width: 120, alignment: .trailing)
                            
                            Text(vm.formatCurrency(item.loan.outstandingPrincipal))
                                .font(.staffFinePrint.weight(.medium))
                                .foregroundColor(.staffTextPrimary)
                                .frame(width: 120, alignment: .trailing)
                            
                            Text(String(format: "%.1f%%", item.loan.interestRate))
                                .font(.staffFinePrint)
                                .foregroundColor(.staffTextSecondary)
                                .frame(width: 80, alignment: .center)
                            
                            Text(item.loan.status.displayName)
                                .font(.staffFinePrint.weight(.semibold))
                                .foregroundColor(Color.staffStatusForeground(for: item.loan.status.rawValue))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.staffStatusBackground(for: item.loan.status.rawValue))
                                .cornerRadius(StaffCorner.xs)
                                .frame(width: 110, alignment: .center)
                            
                            Text(item.loan.overdueDays > 0 ? "\(item.loan.overdueDays)d" : "—")
                                .font(.staffFinePrint.weight(.medium))
                                .foregroundColor(item.loan.overdueDays > 0 ? .staffRed : .staffTextTertiary)
                                .frame(width: 80, alignment: .center)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 4)
                        .background(index % 2 == 0 ? Color.clear : Color.staffSurfaceLight.opacity(0.5))
                        .cornerRadius(StaffCorner.xs)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func tableHeaderCell(_ title: String, width: CGFloat) -> some View {
        Text(title)
            .font(.staffFinePrint.weight(.bold))
            .foregroundColor(.staffTextSecondary)
            .textCase(.uppercase)
            .frame(width: width, alignment: title == "Principal" || title == "Outstanding" ? .trailing : .leading)
    }
    
    private func colorForStatus(_ status: String) -> Color {
        let normalized = status.lowercased().replacingOccurrences(of: " ", with: "_")
        switch normalized {
        case "active":
            return Color.staffAccent
        case "approved":
            return Color(hex: "#1E8A5F")
        case "under_review":
            return Color(hex: "#E1B12C")
        case "submitted":
            return Color(hex: "#4F9DDF")
        case "sent_back":
            return Color(hex: "#F39C12")
        case "rejected":
            return Color(hex: "#D9534F")
        case "npa", "written_off":
            return Color(hex: "#C0392B")
        case "pending_acceptance":
            return Color(hex: "#8E44AD")
        case "pending_disbursal":
            return Color(hex: "#00A8FF")
        case "closed", "draft":
            return Color(hex: "#7F8C8D")
        default:
            return Color(hex: "#2E86DE")
        }
    }
    
    private func colorForProduct(_ name: String) -> Color {
        let cleaned = name.lowercased()
        if cleaned.contains("personal") {
            return Color.staffAccent
        } else if cleaned.contains("home") {
            return Color.staffTeal
        } else if cleaned.contains("vehicle") {
            return Color(hex: "#C89A24")
        } else if cleaned.contains("education") {
            return Color(hex: "#B98222")
        } else if cleaned.contains("business") || cleaned.contains("commercial") {
            return Color.staffPurple
        } else {
            let index = abs(name.hashValue) % productColors.count
            return productColors[index]
        }
    }
    
    // MARK: - Export Functions
    
    private func exportCSV() {
        isExporting = true
        let managerName = authViewModel.currentUser?.fullName ?? "Manager"
        let dateStr = formattedDateForFilename()
        let fileName = "LoanReport_\(managerName.replacingOccurrences(of: " ", with: "_"))_\(dateStr).csv"
        
        var csv = "LOAN OFFICER PORTFOLIO REPORT\n"
        csv += "Officer: \(managerName)\n"
        csv += "Generated: \(formattedDateForDisplay())\n\n"
        
        // Summary Metrics
        csv += "KEY METRICS\n"
        csv += "Metric,Value\n"
        csv += "Portfolio Value,\(vm.formatCurrency(vm.totalPortfolioValue))\n"
        csv += "Active Loans,\(vm.activeLoansCount)\n"
        csv += "NPA Ratio,\(vm.formatPercent(vm.npaRatio))\n"
        csv += "Collection Efficiency,\(vm.formatPercent(vm.collectionEfficiency))\n"
        csv += "Total Disbursed,\(vm.formatCurrency(vm.totalDisbursed))\n"
        csv += "Avg Interest Rate,\(String(format: "%.2f%%", vm.avgInterestRate))\n"
        csv += "NPA Loans,\(vm.npaCount)\n"
        csv += "Restructured Loans,\(vm.restructuredCount)\n"
        csv += "Closed Loans,\(vm.closedCount)\n"
        csv += "Total Overdue Amount,\(vm.formatCurrency(vm.totalOverdueAmount))\n\n"
        
        // Status Distribution
        csv += "STATUS DISTRIBUTION\n"
        csv += "Status,Count,Outstanding Amount\n"
        for slice in vm.statusSlices {
            csv += "\(slice.status),\(slice.count),\(String(format: "%.2f", slice.amount))\n"
        }
        csv += "\n"
        
        // Average Profitability & Loan Size
        csv += "PRODUCT METRICS (PROFITABILITY & LOAN SIZE)\n"
        csv += "Product,Average Interest Rate,Average Loan Size\n"
        for item in vm.productMetrics {
            csv += "\"\(item.productName)\",\(String(format: "%.2f%%", item.avgInterestRate)),\(String(format: "%.2f", item.avgLoanAmount))\n"
        }
        csv += "\n"
        
        // Disbursement Trend
        csv += "DISBURSEMENT TREND (WEEKLY)\n"
        csv += "Week,Amount\n"
        for item in vm.disbursementWeekly {
            csv += "\(item.label),\(String(format: "%.2f", item.amount))\n"
        }
        csv += "\n"
        
        csv += "DISBURSEMENT TREND (MONTHLY)\n"
        csv += "Month,Amount\n"
        for item in vm.disbursementMonthly {
            csv += "\(item.label),\(String(format: "%.2f", item.amount))\n"
        }
        csv += "\n"
        
        csv += "DISBURSEMENT TREND (YEARLY)\n"
        csv += "Year,Amount\n"
        for item in vm.disbursementYearly {
            csv += "\(item.label),\(String(format: "%.2f", item.amount))\n"
        }
        csv += "\n"
        
        // Detailed Loans Table
        csv += "DETAILED LOANS\n"
        csv += "Loan Number,Borrower,Product,Principal Amount,Outstanding Principal,Interest Rate,Status,Overdue Days\n"
        for item in vm.loans {
            csv += "\"\(item.loan.loanNumber ?? "—")\","
            csv += "\"\(item.borrower.fullName)\","
            csv += "\"\(item.product.name)\","
            csv += "\(String(format: "%.2f", item.loan.principalAmount)),"
            csv += "\(String(format: "%.2f", item.loan.outstandingPrincipal)),"
            csv += "\(String(format: "%.2f", item.loan.interestRate)),"
            csv += "\"\(item.loan.status.displayName)\","
            csv += "\(item.loan.overdueDays)\n"
        }
        
        saveAndShare(content: csv, fileName: fileName)
    }
    
    private func exportPDF() {
        isExporting = true
        let managerName = authViewModel.currentUser?.fullName ?? "Manager"
        let dateStr = formattedDateForFilename()
        let fileName = "LoanReport_\(managerName.replacingOccurrences(of: " ", with: "_"))_\(dateStr).pdf"
        
        let pageWidth: CGFloat = 842  // A4 landscape
        let pageHeight: CGFloat = 595
        let margin: CGFloat = 40
        let contentWidth = pageWidth - 2 * margin
        
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        
        let data = pdfRenderer.pdfData { context in
            // PAGE 1 — Summary
            context.beginPage()
            var yPos: CGFloat = margin
            
            // Title bar
            let titleBarRect = CGRect(x: margin, y: yPos, width: contentWidth, height: 50)
            UIColor(Color.staffAccent).setFill()
            UIBezierPath(roundedRect: titleBarRect, cornerRadius: 8).fill()
            
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let title = "Loan Officer Portfolio Report"
            title.draw(at: CGPoint(x: margin + 16, y: yPos + 12), withAttributes: titleAttrs)
            yPos += 60
            
            // Subtitle
            let subtitleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: UIColor.darkGray
            ]
            "Officer: \(managerName)  |  Generated: \(formattedDateForDisplay())".draw(at: CGPoint(x: margin, y: yPos), withAttributes: subtitleAttrs)
            yPos += 30
            
            // Divider
            drawLine(at: yPos, from: margin, width: contentWidth, context: context)
            yPos += 15
            
            // Key Metrics Section
            let sectionAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .bold),
                .foregroundColor: UIColor(Color(hex: "#1A1D1A"))
            ]
            "Key Metrics".draw(at: CGPoint(x: margin, y: yPos), withAttributes: sectionAttrs)
            yPos += 28
            
            let metrics: [(String, String)] = [
                ("Portfolio Value", vm.formatCurrency(vm.totalPortfolioValue)),
                ("Active Loans", "\(vm.activeLoansCount)"),
                ("NPA Ratio", vm.formatPercent(vm.npaRatio)),
                ("Collection Efficiency", vm.formatPercent(vm.collectionEfficiency)),
                ("Total Disbursed", vm.formatCurrency(vm.totalDisbursed)),
                ("Avg Interest Rate", String(format: "%.2f%%", vm.avgInterestRate)),
                ("NPA Loans", "\(vm.npaCount)"),
                ("Total Overdue", vm.formatCurrency(vm.totalOverdueAmount))
            ]
            
            // Draw metrics in a 2-column grid
            let colWidth = contentWidth / 2
            let metricLabelAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: UIColor.gray
            ]
            let metricValueAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .bold),
                .foregroundColor: UIColor(Color(hex: "#1A1D1A"))
            ]
            
            for i in stride(from: 0, to: metrics.count, by: 2) {
                let leftMetric = metrics[i]
                leftMetric.0.draw(at: CGPoint(x: margin, y: yPos), withAttributes: metricLabelAttrs)
                leftMetric.1.draw(at: CGPoint(x: margin, y: yPos + 16), withAttributes: metricValueAttrs)
                
                if i + 1 < metrics.count {
                    let rightMetric = metrics[i + 1]
                    rightMetric.0.draw(at: CGPoint(x: margin + colWidth, y: yPos), withAttributes: metricLabelAttrs)
                    rightMetric.1.draw(at: CGPoint(x: margin + colWidth, y: yPos + 16), withAttributes: metricValueAttrs)
                }
                yPos += 44
            }
            
            yPos += 10
            drawLine(at: yPos, from: margin, width: contentWidth, context: context)
            yPos += 15
            
            // Status Distribution
            "Loan Status Distribution".draw(at: CGPoint(x: margin, y: yPos), withAttributes: sectionAttrs)
            yPos += 28
            
            for slice in vm.statusSlices {
                let text = "\(slice.status): \(slice.count) loans — \(vm.formatCurrency(slice.amount)) outstanding"
                text.draw(at: CGPoint(x: margin + 10, y: yPos), withAttributes: subtitleAttrs)
                yPos += 20
            }
            
            yPos += 10
            drawLine(at: yPos, from: margin, width: contentWidth, context: context)
            yPos += 15
            
            // Average Profitability by Product
            "Average Profitability by Product".draw(at: CGPoint(x: margin, y: yPos), withAttributes: sectionAttrs)
            yPos += 28
            
            for item in vm.productMetrics {
                let text = "\(item.productName): Avg Rate: \(String(format: "%.2f%%", item.avgInterestRate)) — Avg Principal: \(vm.formatCurrency(item.avgLoanAmount))"
                text.draw(at: CGPoint(x: margin + 10, y: yPos), withAttributes: subtitleAttrs)
                yPos += 20
            }
            
            // PAGE 2 — Disbursement Growth Trend
            context.beginPage()
            yPos = margin
            
            "Disbursement Growth Trend".draw(at: CGPoint(x: margin, y: yPos), withAttributes: sectionAttrs)
            yPos += 28
            
            let trendHeaderAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .bold),
                .foregroundColor: UIColor(Color(hex: "#1A1D1A"))
            ]
            
            "Weekly Disbursement Trend".draw(at: CGPoint(x: margin, y: yPos), withAttributes: trendHeaderAttrs)
            yPos += 18
            for item in vm.disbursementWeekly {
                let text = "\(item.label): \(vm.formatCurrency(item.amount))"
                text.draw(at: CGPoint(x: margin + 10, y: yPos), withAttributes: subtitleAttrs)
                yPos += 18
            }
            
            yPos += 15
            "Monthly Disbursement Trend".draw(at: CGPoint(x: margin, y: yPos), withAttributes: trendHeaderAttrs)
            yPos += 18
            for item in vm.disbursementMonthly {
                let text = "\(item.label): \(vm.formatCurrency(item.amount))"
                text.draw(at: CGPoint(x: margin + 10, y: yPos), withAttributes: subtitleAttrs)
                yPos += 18
            }
            
            yPos += 15
            "Yearly Disbursement Trend".draw(at: CGPoint(x: margin, y: yPos), withAttributes: trendHeaderAttrs)
            yPos += 18
            for item in vm.disbursementYearly {
                let text = "\(item.label): \(vm.formatCurrency(item.amount))"
                text.draw(at: CGPoint(x: margin + 10, y: yPos), withAttributes: subtitleAttrs)
                yPos += 18
            }
            
            // PAGE 3 — Detailed Loans Table
            context.beginPage()
            yPos = margin
            
            // Table title
            "Detailed Loans".draw(at: CGPoint(x: margin, y: yPos), withAttributes: sectionAttrs)
            yPos += 28
            
            // Table header
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let headerRect = CGRect(x: margin, y: yPos, width: contentWidth, height: 22)
            UIColor(Color.staffAccent).setFill()
            UIBezierPath(roundedRect: headerRect, cornerRadius: 4).fill()
            
            let colWidths: [CGFloat] = [100, 130, 140, 90, 100, 60, 80, 60]
            let headers = ["Loan #", "Borrower", "Product", "Principal", "Outstanding", "Rate", "Status", "Overdue"]
            var xPos = margin + 6
            for (i, header) in headers.enumerated() {
                header.draw(at: CGPoint(x: xPos, y: yPos + 5), withAttributes: headerAttrs)
                xPos += colWidths[i]
            }
            yPos += 26
            
            // Table rows
            let rowAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .regular),
                .foregroundColor: UIColor.darkGray
            ]
            let boldRowAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .medium),
                .foregroundColor: UIColor(Color(hex: "#1A1D1A"))
            ]
            
            for (index, item) in vm.loans.enumerated() {
                if yPos > pageHeight - 60 {
                    context.beginPage()
                    yPos = margin
                }
                
                // Alternating row background
                if index % 2 == 1 {
                    let rowRect = CGRect(x: margin, y: yPos, width: contentWidth, height: 20)
                    UIColor(Color.staffBackground).setFill()
                    UIBezierPath(rect: rowRect).fill()
                }
                
                xPos = margin + 6
                let values = [
                    item.loan.loanNumber ?? "—",
                    item.borrower.fullName,
                    item.product.name,
                    vm.formatCurrency(item.loan.principalAmount),
                    vm.formatCurrency(item.loan.outstandingPrincipal),
                    String(format: "%.1f%%", item.loan.interestRate),
                    item.loan.status.displayName,
                    item.loan.overdueDays > 0 ? "\(item.loan.overdueDays)d" : "—"
                ]
                for (i, value) in values.enumerated() {
                    let attrs = (i == 0 || i == 3 || i == 4) ? boldRowAttrs : rowAttrs
                    let truncated = String(value.prefix(Int(colWidths[i] / 5)))
                    truncated.draw(at: CGPoint(x: xPos, y: yPos + 4), withAttributes: attrs)
                    xPos += colWidths[i]
                }
                yPos += 22
            }
            
            // Footer
            yPos = pageHeight - 30
            let footerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8, weight: .regular),
                .foregroundColor: UIColor.lightGray
            ]
            "Generated by LMS Staff App — \(formattedDateForDisplay())".draw(at: CGPoint(x: margin, y: yPos), withAttributes: footerAttrs)
        }
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? data.write(to: tempURL)
        exportFileURL = tempURL
        isExporting = false
        showShareSheet = true
    }
    
    private func saveAndShare(content: String, fileName: String) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? content.write(to: tempURL, atomically: true, encoding: .utf8)
        exportFileURL = tempURL
        isExporting = false
        showShareSheet = true
    }
    
    private func drawLine(at y: CGFloat, from x: CGFloat, width: CGFloat, context: UIGraphicsPDFRendererContext) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: x, y: y))
        path.addLine(to: CGPoint(x: x + width, y: y))
        UIColor.lightGray.setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }
    
    private func formattedDateForFilename() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd_HHmm"
        return fmt.string(from: Date())
    }
    
    private func formattedDateForDisplay() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "dd MMM yyyy, hh:mm a"
        return fmt.string(from: Date())
    }
}

// MARK: - ReportMetricCard View Component
fileprivate struct ReportMetricCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let accentColor: Color
    let gradientEnd: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.xs) {
            HStack {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [accentColor.opacity(0.15), gradientEnd.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundColor(accentColor)
                }
                Spacer()
            }
            .padding(.bottom, 4)
            
            Text(title)
                .font(.staffCaption)
                .fontWeight(.medium)
                .foregroundColor(.staffTextSecondary)
                .lineLimit(1)
            
            Text(value)
                .font(.staffTitle)
                .fontWeight(.bold)
                .foregroundColor(.staffTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.staffTextTertiary)
                .lineLimit(1)
        }
        .padding(StaffSpacing.md)
        .background(Color.staffSurface)
        .cornerRadius(StaffCorner.md)
        .overlay(
            RoundedRectangle(cornerRadius: StaffCorner.md)
                .stroke(Color.staffBorder, lineWidth: 1)
        )
    }
}

// MARK: - ShareSheet View Representable
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
