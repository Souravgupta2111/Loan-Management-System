//
//  ReportsView.swift
//  LMS Staff
//
//  Reports generator and exporter (PDF / CSV) with visual branch performance graphs.
//

import SwiftUI
import Charts

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ReportsView: View {
    @StateObject private var dashboardVM = ManagerDashboardViewModel()
    
    @State private var selectedReportType: String = "Portfolio Summary"
    @State private var startDate = Date().addingTimeInterval(-2592000) // 30 days ago
    @State private var endDate = Date()
    @State private var isGenerating: Bool = false
    
    // Sharing state
    @State private var showShareSheet: Bool = false
    @State private var shareURL: URL? = nil
    
    let reportTypes = ["Portfolio Summary", "Disbursement Trend", "Repayment Trend", "NPA Report"]
    @State private var selectedDisbursementPeriod: String = "monthly"

    
    var productVolumeBreakdown: [(product: String, amount: Double)] {
        var breakdown: [String: Double] = [:]
        for item in dashboardVM.activeLoansList {
            let productName = item.product.name
            let amount = item.loan.principalAmount
            breakdown[productName, default: 0.0] += amount
        }
        return breakdown.map { (product: $0.key, amount: $0.value) }.sorted { $0.amount > $1.amount }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Branch Performance & Reports")
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
                .padding(.horizontal, StaffSpacing.lg)
                .padding(.top, StaffSpacing.lg)
                .padding(.bottom, StaffSpacing.md)
            
            Divider()
                .background(Color.staffBorder)
            
            if dashboardVM.isLoading {
                Spacer()
                ProgressView("Loading performance data...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .staffAccent))
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                GeometryReader { geo in
                    ScrollView {
                        HStack(alignment: .top, spacing: StaffSpacing.lg) {
                            
                            // Left Column: Visual Performance Graphs (60% width)
                            VStack(alignment: .leading, spacing: StaffSpacing.lg) {
                                Text("Branch Performance Summary")
                                    .font(.staffBody)
                                    .fontWeight(.bold)
                                    .foregroundColor(.staffTextPrimary)
                                
                                switch selectedReportType {
                                case "Portfolio Summary":
                                    PortfolioSummaryCharts(dashboardVM: dashboardVM, productVolumeBreakdown: productVolumeBreakdown)
                                case "Disbursement Trend":
                                    DisbursementTrendChart(dashboardVM: dashboardVM, selectedPeriod: $selectedDisbursementPeriod)
                                case "Repayment Trend":
                                    RepaymentTrendChart(dashboardVM: dashboardVM)
                                case "NPA Report":
                                    NPAReportChart(dashboardVM: dashboardVM)
                                default:
                                    EmptyView()
                                }
                            }
                            .frame(width: geo.size.width * 0.58)
                            
                            // Right Column: Export and Parameters Config (40% width)
                            VStack(alignment: .leading, spacing: StaffSpacing.lg) {
                                Text("Export Configuration")
                                    .font(.staffBody)
                                    .fontWeight(.bold)
                                    .foregroundColor(.staffTextPrimary)
                                
                                StaffCard {
                                    VStack(alignment: .leading, spacing: StaffSpacing.md) {
                                        Text("Configurations")
                                            .font(.staffTitle)
                                            .foregroundColor(.staffTextPrimary)
                                        
                                        Divider()
                                        
                                        // Type Picker
                                        Text("Report Type")
                                            .font(.staffCaption)
                                            .foregroundColor(.staffTextSecondary)
                                        Picker("Report Type", selection: $selectedReportType) {
                                            ForEach(reportTypes, id: \.self) { type in
                                                Text(type)
                                            }
                                        }
                                        .pickerStyle(SegmentedPickerStyle())
                                        
                                        // Date Range Picker
                                        VStack(alignment: .leading, spacing: StaffSpacing.sm) {
                                            DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                                                .foregroundColor(.staffTextPrimary)
                                            DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                                                .foregroundColor(.staffTextPrimary)
                                        }
                                        .padding(.top, StaffSpacing.md)
                                    }
                                }
                                
                                StaffCard {
                                    VStack(alignment: .leading, spacing: StaffSpacing.md) {
                                        Text("Compilation Summary")
                                            .font(.staffTitle)
                                            .foregroundColor(.staffTextPrimary)
                                        
                                        Divider()
                                        
                                        VStack(spacing: StaffSpacing.sm) {
                                            KYCRow(label: "Target Scope", value: "HQ - Main Branch Consolidated")
                                            KYCRow(label: "Filtered Span", value: "\(formatSpanDate(startDate)) to \(formatSpanDate(endDate))")
                                            KYCRow(label: "Total Branch Portfolio", value: "₹\(formatAmount(dashboardVM.totalDisbursed))")
                                        }
                                    }
                                }
                                
                                // Export triggers
                                VStack(spacing: StaffSpacing.md) {
                                    StaffButton(
                                        title: "Compile & Export CSV",
                                        style: .primary,
                                        icon: "tablecells",
                                        isLoading: isGenerating
                                    ) {
                                        Task {
                                            await compileAndExportReport(format: "CSV")
                                        }
                                    }
                                    
                                    StaffButton(
                                        title: "Compile & Export PDF",
                                        style: .primary,
                                        icon: "doc.text.fill",
                                        isLoading: isGenerating
                                    ) {
                                        Task {
                                            await compileAndExportReport(format: "PDF")
                                        }
                                    }
                                }
                            }
                            .frame(width: geo.size.width * 0.38)
                        }
                        .padding(StaffSpacing.lg)
                    }
                }
            }
        }
        .background(Color.staffBackground)
        .onAppear {
            Task {
                await dashboardVM.loadDashboard()
            }
        }
        .sheet(isPresented: $showShareSheet, onDismiss: { shareURL = nil }) {
            if let url = shareURL {
                ShareSheet(activityItems: [url])
            }
        }
    }
    
    // MARK: - Actions
    
    private func compileAndExportReport(format: String) async {
        isGenerating = true
        
        // Simulate background report compile processing
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        do {
            let loans = try await LoanPortfolioService.shared.fetchLoans()
            let rawLoans = loans.map(\.loan)
            
            let tempDir = FileManager.default.temporaryDirectory
            let filename = "\(selectedReportType.replacingOccurrences(of: " ", with: "_"))_\(Int(Date().timeIntervalSince1970))"
            
            if format == "CSV" {
                let csvString = ReportService.shared.generateCSVReport(loansList: rawLoans)
                let fileURL = tempDir.appendingPathComponent("\(filename).csv")
                try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
                self.shareURL = fileURL
            } else {
                let pdfData = PDFReportGenerator.shared.generateReportPDF(
                    reportType: selectedReportType,
                    dashboardVM: dashboardVM,
                    productVolumeBreakdown: productVolumeBreakdown,
                    selectedPeriod: selectedDisbursementPeriod,
                    startDate: startDate,
                    endDate: endDate
                )
                
                let fileURL = tempDir.appendingPathComponent("\(filename).pdf")
                try pdfData.write(to: fileURL)
                self.shareURL = fileURL
            }
            
            self.showShareSheet = true
        } catch {
            print("Error compiling report: \(error)")
        }
        
        isGenerating = false
    }
    
    private func formatSpanDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatAmount(_ amount: Double) -> String {
        if amount >= 10_000_000 {
            return String(format: "%.1fCr", amount / 10_000_000)
        } else if amount >= 100_000 {
            return String(format: "%.1fL", amount / 100_000)
        } else if amount >= 1_000 {
            return String(format: "%.0fK", amount / 1_000)
        }
        return String(format: "%.0f", amount)
    }
    
    private func colorForStatus(_ status: String) -> Color {
        switch status.lowercased() {
        case "active": return .staffGreen
        case "npa": return .staffRed
        case "restructured": return .staffAmber
        case "closed": return .staffTextSecondary
        case "written off": return .staffRed.opacity(0.6)
        case "pending acceptance": return .staffAccent
        default: return .staffTextSecondary
        }
    }
}

// MARK: - Subviews for Charts

struct PortfolioSummaryCharts: View {
    @ObservedObject var dashboardVM: ManagerDashboardViewModel
    let productVolumeBreakdown: [(product: String, amount: Double)]
    
    var body: some View {
        VStack(spacing: StaffSpacing.md) {
            HStack(alignment: .top, spacing: StaffSpacing.md) {
                // Portfolio Breakdown Donut
                if !dashboardVM.portfolioBreakdown.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Portfolio Status Mix")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.staffTextSecondary)
                        
                        Chart(dashboardVM.portfolioBreakdown, id: \.status) { item in
                            SectorMark(
                                angle: .value("Amount", item.amount),
                                innerRadius: .ratio(0.6),
                                angularInset: 1.5
                            )
                            .foregroundStyle(ReportsView.colorForStatus(item.status))
                        }
                        .frame(height: 120)
                        
                        // Legend
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(dashboardVM.portfolioBreakdown, id: \.status) { item in
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(ReportsView.colorForStatus(item.status))
                                        .frame(width: 8, height: 8)
                                    Text("\(item.status): \(item.count)")
                                        .font(.caption)
                                        .foregroundColor(.staffTextSecondary)
                                }
                            }
                        }
                    }
                    .padding(StaffSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .background(Color.staffSurface)
                    .cornerRadius(StaffCorner.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: StaffCorner.md)
                            .stroke(Color.staffBorder, lineWidth: 1)
                    )
                }
                
                // Product Distribution Bar Chart
                if !productVolumeBreakdown.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Loan Product Volume (INR)")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.staffTextSecondary)
                        
                        Chart(productVolumeBreakdown, id: \.product) { item in
                            BarMark(
                                x: .value("Volume", item.amount),
                                y: .value("Product", item.product)
                            )
                            .foregroundStyle(Color.staffAccent)
                        }
                        .frame(height: 120)
                        .chartXAxis {
                            AxisMarks { value in
                                AxisValueLabel {
                                    if let amount = value.as(Double.self) {
                                        Text(ReportsView.formatAmount(amount))
                                    }
                                }
                            }
                        }
                    }
                    .padding(StaffSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .background(Color.staffSurface)
                    .cornerRadius(StaffCorner.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: StaffCorner.md)
                            .stroke(Color.staffBorder, lineWidth: 1)
                    )
                }
            }
            
            // Application Stages Chart
            if !dashboardVM.applicationStageBreakdown.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Application Pipeline Stages")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.staffTextSecondary)
                    
                    Chart(dashboardVM.applicationStageBreakdown, id: \.status) { item in
                        BarMark(
                            x: .value("Count", item.count),
                            y: .value("Stage", item.status)
                        )
                        .foregroundStyle(ReportsView.colorForStatus(item.status))
                        .annotation(position: .trailing) {
                            Text("\(item.count)")
                                .font(.caption2)
                                .foregroundColor(.staffTextSecondary)
                        }
                    }
                    .frame(height: 150)
                }
                .padding(StaffSpacing.md)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(Color.staffSurface)
                .cornerRadius(StaffCorner.md)
                .overlay(
                    RoundedRectangle(cornerRadius: StaffCorner.md)
                        .stroke(Color.staffBorder, lineWidth: 1)
                )
            }
        }
    }
}

struct DisbursementTrendChart: View {
    @ObservedObject var dashboardVM: ManagerDashboardViewModel
    @Binding var selectedPeriod: String
    
    let periods = ["daily", "weekly", "monthly", "yearly"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.md) {
            Picker("Period", selection: $selectedPeriod) {
                ForEach(periods, id: \.self) { period in
                    Text(period.capitalized)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            let data = dashboardVM.disbursementTrends[selectedPeriod] ?? []
            
            if !data.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Disbursement Volume (INR) - \(selectedPeriod.capitalized)")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.staffTextSecondary)
                    
                    Chart(data, id: \.period) { item in
                        BarMark(
                            x: .value("Period", item.period),
                            y: .value("Amount", item.amount)
                        )
                        .foregroundStyle(Color.staffTeal)
                    }
                    .frame(height: 250)
                    .chartYAxis {
                        AxisMarks { value in
                            AxisValueLabel {
                                if let amount = value.as(Double.self) {
                                    Text(ReportsView.formatAmount(amount))
                                }
                            }
                        }
                    }
                }
                .padding(StaffSpacing.md)
                .background(Color.staffSurface)
                .cornerRadius(StaffCorner.md)
                .overlay(
                    RoundedRectangle(cornerRadius: StaffCorner.md)
                        .stroke(Color.staffBorder, lineWidth: 1)
                )
            } else {
                Text("No disbursement data available for this period.")
                    .font(.caption)
                    .foregroundColor(.staffTextSecondary)
                    .padding()
            }
        }
    }
}

struct RepaymentTrendChart: View {
    @ObservedObject var dashboardVM: ManagerDashboardViewModel
    
    var body: some View {
        if !dashboardVM.collectionTrends.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Collection Efficiency Trend (%)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.staffTextSecondary)
                
                Chart(dashboardVM.collectionTrends) { item in
                    LineMark(
                        x: .value("Month", item.month),
                        y: .value("Efficiency", item.efficiency)
                    )
                    .foregroundStyle(Color.staffGreen)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    
                    AreaMark(
                        x: .value("Month", item.month),
                        y: .value("Efficiency", item.efficiency)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [Color.staffGreen.opacity(0.3), Color.staffGreen.opacity(0.01)], startPoint: .top, endPoint: .bottom)
                    )
                }
                .frame(height: 250)
                .chartYScale(domain: 0...100)
            }
            .padding(StaffSpacing.md)
            .background(Color.staffSurface)
            .cornerRadius(StaffCorner.md)
            .overlay(
                RoundedRectangle(cornerRadius: StaffCorner.md)
                    .stroke(Color.staffBorder, lineWidth: 1)
            )
        } else {
            EmptyView()
        }
    }
}

struct NPAReportChart: View {
    @ObservedObject var dashboardVM: ManagerDashboardViewModel
    
    var body: some View {
        if !dashboardVM.npaAgingBuckets.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("NPA Aging Buckets (Amount & Count)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.staffTextSecondary)
                
                Chart(dashboardVM.npaAgingBuckets, id: \.range) { item in
                    BarMark(
                        x: .value("Range", item.range),
                        y: .value("Amount", item.amount)
                    )
                    .foregroundStyle(Color.staffRed)
                    .annotation(position: .top) {
                        Text("\(item.count) loans")
                            .font(.caption2)
                            .foregroundColor(.staffTextSecondary)
                    }
                }
                .frame(height: 250)
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(ReportsView.formatAmount(amount))
                            }
                        }
                    }
                }
            }
            .padding(StaffSpacing.md)
            .background(Color.staffSurface)
            .cornerRadius(StaffCorner.md)
            .overlay(
                RoundedRectangle(cornerRadius: StaffCorner.md)
                    .stroke(Color.staffBorder, lineWidth: 1)
            )
        } else {
            Text("No NPA data available.")
                .font(.caption)
                .foregroundColor(.staffTextSecondary)
                .padding()
        }
    }
}

extension ReportsView {
    static func colorForStatus(_ status: String) -> Color {
        switch status.lowercased() {
        case "active": return .staffGreen
        case "npa": return .staffRed
        case "restructured": return .staffAmber
        case "closed": return .staffTextSecondary
        case "written off": return .staffRed.opacity(0.6)
        case "pending acceptance": return .staffAccent
        case "approved": return .staffGreen
        case "rejected": return .staffRed
        case "sent back": return .staffAmber
        case "under review": return .staffTeal
        default: return .staffTextSecondary
        }
    }
    
    static func formatAmount(_ amount: Double) -> String {
        if amount >= 10_000_000 {
            return String(format: "%.1fCr", amount / 10_000_000)
        } else if amount >= 100_000 {
            return String(format: "%.1fL", amount / 100_000)
        } else if amount >= 1_000 {
            return String(format: "%.0fK", amount / 1_000)
        }
        return String(format: "%.0f", amount)
    }
}

