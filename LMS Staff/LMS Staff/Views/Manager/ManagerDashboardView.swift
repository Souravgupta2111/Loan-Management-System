//
//  ManagerDashboardView.swift
//  LMS Staff
//
//  Manager Dashboard with segmented queues, inline analytics charts, and approval workflow.
//

import SwiftUI
import Charts

enum ManagerDashboardMode {
    case standard
    case recommendations
}

enum ManagerQueueSegment: String, CaseIterable {
    case pendingReview = "Pending Review"
    case sentBack = "Sent Back"
    case rejected = "Rejected"
    case approved = "Approved"
}

struct ManagerDashboardView: View {
    var preselectedView: ManagerDashboardMode = .standard
    
    @StateObject private var vm = ManagerDashboardViewModel()
    @State private var selectedApp: ApplicationWithBorrower?
    @State private var selectedSegment: ManagerQueueSegment = .pendingReview
    
    // Approval terms state
    @State private var showApprovalSheet: Bool = false
    @State private var approvedAmount: Double = 0.0
    @State private var approvedTenure: Int = 12
    @State private var approvedRate: Double = 10.0
    
    // Reject & Send back modals
    @State private var showRejectSheet: Bool = false
    @State private var showSendBackSheet: Bool = false
    @State private var remarks: String = ""
    
    @State private var showMetricDetailSheet: Bool = false
    @State private var metricDetailTitle: String = ""
    @State private var metricDetailData: MetricDataType = .loans([])
    
    // Chart expand state

    
    var currentQueue: [ApplicationWithBorrower] {
        switch selectedSegment {
        case .pendingReview: return vm.recommendedApplications
        case .sentBack: return vm.sentBackApplications
        case .rejected: return vm.rejectedApplications
        case .approved: return vm.approvedApplications
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left column: KPIs, Charts, Queue list
            VStack(alignment: .leading, spacing: 0) {
                Text("Manager Console")
                    .font(.staffTitle)
                    .foregroundColor(.staffTextPrimary)
                    .padding(.horizontal, StaffSpacing.lg)
                    .padding(.top, StaffSpacing.lg)
                
                ScrollView {
                    VStack(spacing: StaffSpacing.sm) {
                        // KPI summary widgets
                        kpiCardsSection
                    }
                    .padding(.horizontal, StaffSpacing.lg)
                    .padding(.top, StaffSpacing.sm)
                }
                
                // Queue Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: StaffSpacing.sm) {
                        ForEach(ManagerQueueSegment.allCases, id: \.self) { seg in
                            let count = countFor(seg)
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedSegment = seg
                                    selectedApp = nil
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Text(seg.rawValue)
                                    if count > 0 {
                                        Text("\(count)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(selectedSegment == seg ? .staffAccent : .staffTextSecondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(selectedSegment == seg ? Color.white : Color.staffBackground)
                                            .clipShape(Capsule())
                                    }
                                }
                                .font(.staffCaption)
                                .fontWeight(selectedSegment == seg ? .bold : .medium)
                                .foregroundColor(selectedSegment == seg ? .white : .staffTextPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(selectedSegment == seg ? Color.staffAccent : Color.staffSurface)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(selectedSegment == seg ? Color.clear : Color.staffBorder, lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, StaffSpacing.lg)
                }
                .padding(.vertical, StaffSpacing.sm)
                
                Divider()
                    .background(Color.staffBorder)
                
                // Queue List
                if vm.isLoading {
                    Spacer()
                    ProgressView()
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else if currentQueue.isEmpty {
                    Spacer()
                    EmptyStateView(
                        icon: emptyIcon(for: selectedSegment),
                        title: emptyTitle(for: selectedSegment),
                        message: emptyMessage(for: selectedSegment)
                    )
                    Spacer()
                } else {
                    List(currentQueue, selection: $selectedApp) { app in
                        queueListRow(app)
                            .tag(app)
                            .listRowBackground(Color.staffSurface)
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden)
                    .background(Color.staffBackground)
                }
            }
            .frame(width: 400)
            .background(Color.staffBackground)
            
            Divider()
                .background(Color.staffBorder)
            
            // Right column: Detail pane
            if let app = selectedApp {
                if selectedSegment == .pendingReview {
                    recommendationInspectorSection(app)
                } else {
                    readOnlyInspectorSection(app)
                }
            } else {
                fullWidthAnalyticsDashboard
            }
        }
        .background(Color.staffBackground)
        .onAppear {
            Task { await vm.loadDashboard() }
        }
        .sheet(isPresented: $showApprovalSheet) {
            approvalTermsSheet
        }
        .sheet(isPresented: $showRejectSheet) {
            rejectionRemarksSheet
        }
        .sheet(isPresented: $showSendBackSheet) {
            sendBackRemarksSheet
        }
        .sheet(isPresented: $showMetricDetailSheet) {
            NavigationStack {
                MetricDetailSheet(title: metricDetailTitle, data: metricDetailData)
            }
        }
    }
    
    // MARK: - KPI Cards
    
    private var kpiCardsSection: some View {
        VStack(spacing: StaffSpacing.sm) {
            HStack(spacing: StaffSpacing.sm) {
                Button(action: {
                    metricDetailTitle = "Active Portfolio"
                    metricDetailData = .loans(vm.activeLoansList)
                    showMetricDetailSheet = true
                }) {
                    MiniStatCard(title: "Portfolio", value: "₹\(formatAmount(vm.totalDisbursed))", icon: "briefcase.fill", color: .staffAccent)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    metricDetailTitle = "Active Loans"
                    metricDetailData = .loans(vm.activeLoansList)
                    showMetricDetailSheet = true
                }) {
                    MiniStatCard(title: "Active Loans", value: "\(vm.activeLoansCount)", icon: "person.2.fill", color: .staffAmber)
                }
                .buttonStyle(PlainButtonStyle())
            }
            HStack(spacing: StaffSpacing.sm) {
                Button(action: {
                    metricDetailTitle = "Collection Efficiency"
                    metricDetailData = .loans(vm.activeLoansList)
                    showMetricDetailSheet = true
                }) {
                    MiniStatCard(title: "Collection", value: String(format: "%.1f%%", vm.collectionEfficiency), icon: "chart.bar.fill", color: .staffGreen)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    metricDetailTitle = "NPA Ratio"
                    metricDetailData = .loans(vm.activeLoansList.filter { $0.loan.status == .npa })
                    showMetricDetailSheet = true
                }) {
                    MiniStatCard(title: "NPA", value: String(format: "%.1f%%", vm.npaRatio), icon: "exclamationmark.triangle.fill", color: .staffRed)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // MARK: - Full Width Analytics Dashboard
    
    private var fullWidthAnalyticsDashboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: StaffSpacing.xl) {
                Text("Portfolio Analytics")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.staffTextPrimary)
                    .padding(.bottom, StaffSpacing.md)
                
                // Collection Efficiency Sparkline (Big)
                if !vm.collectionTrends.isEmpty {
                    VStack(alignment: .leading, spacing: StaffSpacing.md) {
                        Text("Collection Efficiency Trend (Past 6 Months)")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.staffTextPrimary)
                        
                        Chart(vm.collectionTrends) { item in
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
                                LinearGradient(colors: [Color.staffGreen.opacity(0.4), Color.staffGreen.opacity(0.0)], startPoint: .top, endPoint: .bottom)
                            )
                            
                            PointMark(
                                x: .value("Month", item.month),
                                y: .value("Efficiency", item.efficiency)
                            )
                            .foregroundStyle(Color.staffGreen)
                            .annotation(position: .top) {
                                Text(String(format: "%.1f%%", item.efficiency))
                                    .font(.caption)
                                    .foregroundColor(.staffTextSecondary)
                            }
                        }
                        .frame(height: 250)
                        .chartYScale(domain: 0...100)
                    }
                    .padding(StaffSpacing.xl)
                    .background(Color.staffSurface)
                    .cornerRadius(StaffCorner.lg)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                }
                
                HStack(alignment: .top, spacing: StaffSpacing.xl) {
                    // Portfolio Breakdown Donut
                    if !vm.portfolioBreakdown.isEmpty {
                        VStack(alignment: .leading, spacing: StaffSpacing.md) {
                            Text("Portfolio Mix by Status")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.staffTextPrimary)
                            
                            Chart(vm.portfolioBreakdown, id: \.status) { item in
                                SectorMark(
                                    angle: .value("Amount", item.amount),
                                    innerRadius: .ratio(0.55),
                                    angularInset: 2.0
                                )
                                .foregroundStyle(colorForStatus(item.status))
                                .annotation(position: .overlay) {
                                    if item.count > 0 {
                                        Text("\(item.count)")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .frame(height: 250)
                            
                            // Legend
                            HStack(spacing: StaffSpacing.lg) {
                                ForEach(vm.portfolioBreakdown, id: \.status) { item in
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(colorForStatus(item.status))
                                            .frame(width: 10, height: 10)
                                        Text("\(item.status)")
                                            .font(.subheadline)
                                            .foregroundColor(.staffTextSecondary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .padding(StaffSpacing.xl)
                        .frame(maxWidth: .infinity)
                        .background(Color.staffSurface)
                        .cornerRadius(StaffCorner.lg)
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                    }
                    
                    // NPA Aging Bars
                    VStack(alignment: .leading, spacing: StaffSpacing.md) {
                        Text("NPA Aging Buckets")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.staffTextPrimary)
                        
                        let totalNPA = vm.npaAgingBuckets.reduce(0) { $0 + $1.count }
                        
                        if totalNPA == 0 {
                            Text("No NPA loans currently in the portfolio. Excellent!")
                                .font(.body)
                                .foregroundColor(.staffGreen)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        } else {
                            Chart(vm.npaAgingBuckets, id: \.range) { item in
                                BarMark(
                                    x: .value("Count", item.count),
                                    y: .value("Range", item.range)
                                )
                                .foregroundStyle(npaBarColor(item.range))
                                .annotation(position: .trailing) {
                                    if item.count > 0 {
                                        Text("\(item.count)")
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.staffTextPrimary)
                                    }
                                }
                            }
                            .frame(height: 250)
                        }
                    }
                    .padding(StaffSpacing.xl)
                    .frame(maxWidth: .infinity)
                    .background(Color.staffSurface)
                    .cornerRadius(StaffCorner.lg)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                }
            }
            .padding(StaffSpacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.staffSurface.opacity(0.1))
    }
    
    // MARK: - Queue List Row
    
    @ViewBuilder
    private func queueListRow(_ app: ApplicationWithBorrower) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(app.borrower.fullName)
                    .font(.staffBody)
                    .fontWeight(.bold)
                    .foregroundColor(.staffTextPrimary)
                Spacer()
                Text("₹\(String(format: "%.0f", app.application.requestedAmount))")
                    .font(.staffCaption)
                    .fontWeight(.bold)
                    .foregroundColor(.staffAccent)
            }
            
            HStack {
                Text(app.application.applicationNumber ?? "APP-NEW")
                    .font(.staffCaption)
                    .foregroundColor(.staffTextSecondary)
                Spacer()
                
                if selectedSegment == .sentBack {
                    Text("↩ Sent Back")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.staffAmber)
                } else if selectedSegment == .rejected {
                    Text("✕ Rejected")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.staffRed)
                } else if selectedSegment == .approved {
                    Text("✓ Approved")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.staffGreen)
                } else {
                    Text("Tenure: \(app.application.requestedTenureMonths)m")
                        .font(.system(size: 10))
                        .foregroundColor(.staffTextSecondary)
                }
            }
        }
        .padding(.vertical, 6)
    }
    
    // MARK: - Inspection Panel (Actionable — Pending Review)
    
    @ViewBuilder
    private func recommendationInspectorSection(_ item: ApplicationWithBorrower) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.borrower.fullName)
                        .font(.staffTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.staffTextPrimary)
                    Text("App Number: \(item.application.applicationNumber ?? "N/A") | Product: \(item.product.name)")
                        .font(.staffCaption)
                        .foregroundColor(.staffTextSecondary)
                }
                Spacer()
            }
            .padding(StaffSpacing.lg)
            .background(Color.staffSurface)
            
            ScrollView {
                VStack(alignment: .leading, spacing: StaffSpacing.lg) {
                    // Application particulars
                    StaffCard {
                        VStack(alignment: .leading, spacing: StaffSpacing.md) {
                            Text("Proposal Particulars")
                                .font(.staffTitle)
                                .foregroundColor(.staffTextPrimary)
                            
                            Divider()
                            
                            KYCRow(label: "Requested Amount", value: "₹\(String(format: "%.2f", item.application.requestedAmount))")
                            KYCRow(label: "Requested Tenure", value: "\(item.application.requestedTenureMonths) Months")
                            KYCRow(label: "Borrower Monthly Income", value: computeMonthlyIncomeDisplay(item))
                            KYCRow(label: "Borrower Credit Score", value: item.profile?.creditScore != nil ? "\(item.profile!.creditScore!)" : "N/A")
                        }
                    }
                    
                    // Product specifics guidelines
                    StaffCard {
                        VStack(alignment: .leading, spacing: StaffSpacing.md) {
                            Text("Loan Product Constraints")
                                .font(.staffTitle)
                                .foregroundColor(.staffTextPrimary)
                            
                            Divider()
                            
                            KYCRow(label: "Rate Limits", value: item.product.formattedRateRange)
                            KYCRow(label: "Tenure limits", value: item.product.formattedTenureRange)
                            KYCRow(label: "Processing Fee Pct", value: "\(item.product.processingFeePct)%")
                        }
                    }
                }
                .padding(StaffSpacing.lg)
            }
            
            Divider()
                .background(Color.staffBorder)
            
            // Bottom Action Bar — No Reassign button
            HStack(spacing: StaffSpacing.md) {
                StaffButton(title: "Send Back", style: .outline, icon: "arrow.uturn.left") {
                    showSendBackSheet = true
                }
                
                StaffButton(title: "Reject", style: .destructive, icon: "xmark.circle") {
                    showRejectSheet = true
                }
                
                Spacer()
                
                StaffButton(title: "Verify & Approve", style: .success, icon: "checkmark.seal.fill") {
                    // Compute recommended amount for slider
                    let income = computeMonthlyIncome(item)
                    let creditScore = item.profile?.creditScore ?? 0
                    let empType = item.profile?.employmentType ?? .salaried
                    
                    let suggestion = UnderwritingService.shared.calculateSuggestion(
                        monthlyIncome: income,
                        creditScore: creditScore,
                        employmentType: empType,
                        requestedAmount: item.application.requestedAmount,
                        product: item.product,
                        existingEMIs: 0,
                        isIncomeVerified: item.profile?.incomeVerified ?? false
                    )
                    
                    // Use suggestion, falling back to requested amount — never zero
                    let suggestionAmount = suggestion.suggestedAmount > 0 ? suggestion.suggestedAmount : item.application.requestedAmount
                    let suggestionTenure = suggestion.suggestedTenureMonths > 0 ? suggestion.suggestedTenureMonths : item.application.requestedTenureMonths
                    let suggestionRate = suggestion.suggestedInterestRate > 0 ? suggestion.suggestedInterestRate : item.product.minInterestRate
                    
                    approvedAmount = max(item.product.minAmount, min(suggestionAmount, item.product.maxAmount))
                    approvedTenure = max(item.product.minTenureMonths, min(suggestionTenure, item.product.maxTenureMonths))
                    approvedRate = max(item.product.minInterestRate, min(suggestionRate, item.product.maxInterestRate))
                    showApprovalSheet = true
                }
                .frame(width: 240)
            }
            .padding(StaffSpacing.lg)
            .background(Color.staffSurface)
        }
    }
    
    // MARK: - Read-Only Inspector (Sent Back, Rejected, Approved)
    
    @ViewBuilder
    private func readOnlyInspectorSection(_ item: ApplicationWithBorrower) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(item.borrower.fullName)
                            .font(.staffTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.staffTextPrimary)
                        StaffStatusBadge(status: item.application.status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                    }
                    Text("App: \(item.application.applicationNumber ?? "N/A") | Product: \(item.product.name)")
                        .font(.staffCaption)
                        .foregroundColor(.staffTextSecondary)
                }
                Spacer()
            }
            .padding(StaffSpacing.lg)
            .background(Color.staffSurface)
            
            ScrollView {
                VStack(alignment: .leading, spacing: StaffSpacing.lg) {
                    StaffCard {
                        VStack(alignment: .leading, spacing: StaffSpacing.md) {
                            Text("Application Details")
                                .font(.staffTitle)
                                .foregroundColor(.staffTextPrimary)
                            Divider()
                            KYCRow(label: "Requested Amount", value: "₹\(String(format: "%.2f", item.application.requestedAmount))")
                            KYCRow(label: "Requested Tenure", value: "\(item.application.requestedTenureMonths) Months")
                            KYCRow(label: "Monthly Income", value: computeMonthlyIncomeDisplay(item))
                            KYCRow(label: "Credit Score", value: item.profile?.creditScore != nil ? "\(item.profile!.creditScore!)" : "N/A")
                            KYCRow(label: "Status", value: item.application.status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                        }
                    }
                    
                    // Show reason if sent back or rejected
                    if selectedSegment == .sentBack || selectedSegment == .rejected {
                        StaffCard {
                            VStack(alignment: .leading, spacing: StaffSpacing.md) {
                                HStack {
                                    Image(systemName: selectedSegment == .rejected ? "xmark.seal.fill" : "arrow.uturn.left.circle.fill")
                                        .foregroundColor(selectedSegment == .rejected ? .staffRed : .staffAmber)
                                    Text(selectedSegment == .rejected ? "Rejection Reason" : "Send-Back Remarks")
                                        .font(.staffTitle)
                                        .foregroundColor(.staffTextPrimary)
                                }
                                Divider()
                                Text(item.application.rejectionReason ?? "No reason provided")
                                    .font(.staffBody)
                                    .foregroundColor(.staffTextPrimary)
                                    .italic()
                            }
                        }
                    }
                }
                .padding(StaffSpacing.lg)
            }
        }
    }
    
    // MARK: - Action Sheets
    
    private var approvalTermsSheet: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.lg) {
            Text("Sanction Terms Configuration")
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
            
            if let item = selectedApp {
                VStack(alignment: .leading, spacing: StaffSpacing.xl) {
                    
                    VStack(alignment: .leading, spacing: StaffSpacing.sm) {
                        Text("Approved Amount: ₹\(String(format: "%.2f", approvedAmount))")
                            .font(.staffBody)
                            .fontWeight(.medium)
                            .foregroundColor(.staffTextPrimary)
                        Slider(value: $approvedAmount, in: item.product.minAmount...item.product.maxAmount, step: 10000)
                            .tint(.staffAccent)
                    }
                    
                    Divider().background(Color.staffBorder)
                    
                    VStack(alignment: .leading, spacing: StaffSpacing.sm) {
                        Text("Approved Tenure: \(approvedTenure) Months")
                            .font(.staffBody)
                            .fontWeight(.medium)
                            .foregroundColor(.staffTextPrimary)
                        Stepper("\(approvedTenure) Months", value: $approvedTenure, in: item.product.minTenureMonths...item.product.maxTenureMonths, step: 1)
                            .foregroundColor(.staffTextSecondary)
                    }
                    
                    Divider().background(Color.staffBorder)
                    
                    VStack(alignment: .leading, spacing: StaffSpacing.sm) {
                        Text("Approved Interest Rate: \(String(format: "%.2f", approvedRate))% Per Annum")
                            .font(.staffBody)
                            .fontWeight(.medium)
                            .foregroundColor(.staffTextPrimary)
                        Slider(value: $approvedRate, in: item.product.minInterestRate...item.product.maxInterestRate, step: 0.25)
                            .tint(.staffAccent)
                    }
                }
                .padding(StaffSpacing.xl)
                .background(Color.staffSurface)
                .cornerRadius(StaffCorner.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: StaffCorner.lg)
                        .stroke(Color.staffBorder, lineWidth: 1)
                )
            }
            
            HStack(spacing: StaffSpacing.md) {
                StaffButton(title: "Cancel", style: .outline, icon: "xmark", isFullWidth: false) {
                    showApprovalSheet = false
                }
                
                Spacer()
                
                StaffButton(title: "Sanction Approval", style: .primary, icon: "checkmark.seal.fill", isFullWidth: true) {
                    if let app = selectedApp?.application {
                        Task {
                            if await vm.approveApplication(applicationId: app.id, approvedAmount: approvedAmount, tenureMonths: approvedTenure, interestRate: approvedRate) {
                                showApprovalSheet = false
                                selectedApp = nil
                            }
                        }
                    }
                }
                
                if let error = vm.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .padding(30)
        .background(Color.staffBackground.ignoresSafeArea())
    }
    
    private var rejectionRemarksSheet: some View {
        VStack(spacing: StaffSpacing.lg) {
            Text("Rejection Reason")
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
            
            TextEditor(text: $remarks)
                .frame(height: 120)
                .padding(8)
                .background(Color.staffSurface)
                .cornerRadius(StaffCorner.md)
                .foregroundColor(.staffTextPrimary)
            
            HStack {
                Button("Cancel") { showRejectSheet = false }
                    .foregroundColor(.staffTextSecondary)
                Spacer()
                Button("Reject Proposal") {
                    if let app = selectedApp?.application {
                        Task {
                            if await vm.rejectApplication(applicationId: app.id, reason: remarks) {
                                showRejectSheet = false
                                remarks = ""
                                selectedApp = nil
                            }
                        }
                    }
                }
                .foregroundColor(.staffRed)
                .fontWeight(.bold)
                .disabled(remarks.isEmpty)
            }
        }
        .padding(30)
        .background(Color.staffBackground.ignoresSafeArea())
    }
    
    private var sendBackRemarksSheet: some View {
        VStack(spacing: StaffSpacing.lg) {
            Text("Send Back Remarks")
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
            
            TextEditor(text: $remarks)
                .frame(height: 120)
                .padding(8)
                .background(Color.staffSurface)
                .cornerRadius(StaffCorner.md)
                .foregroundColor(.staffTextPrimary)
            
            HStack {
                Button("Cancel") { showSendBackSheet = false }
                    .foregroundColor(.staffTextSecondary)
                Spacer()
                Button("Send Back to Officer") {
                    if let app = selectedApp?.application {
                        Task {
                            if await vm.sendBackApplication(applicationId: app.id, remarks: remarks) {
                                showSendBackSheet = false
                                remarks = ""
                                selectedApp = nil
                            }
                        }
                    }
                }
                .foregroundColor(.staffAmber)
                .fontWeight(.bold)
                .disabled(remarks.isEmpty)
            }
        }
        .padding(30)
        .background(Color.staffBackground.ignoresSafeArea())
    }
    
    // MARK: - Helpers
    
    private func computeMonthlyIncome(_ item: ApplicationWithBorrower) -> Double {
        if let verified = item.profile?.verifiedAnnualIncome, verified > 0 {
            return verified / 12.0
        }
        if let monthly = item.profile?.monthlyIncome, monthly > 0 {
            return monthly
        }
        // Fallback: use requested amount as rough proxy (shouldn't happen with real data)
        return 0
    }
    
    private func computeMonthlyIncomeDisplay(_ item: ApplicationWithBorrower) -> String {
        let income = computeMonthlyIncome(item)
        if income > 0 {
            return "₹\(String(format: "%.2f", income))"
        }
        return "N/A"
    }
    
    private func countFor(_ segment: ManagerQueueSegment) -> Int {
        switch segment {
        case .pendingReview: return vm.recommendedApplications.count
        case .sentBack: return vm.sentBackApplications.count
        case .rejected: return vm.rejectedApplications.count
        case .approved: return vm.approvedApplications.count
        }
    }
    
    private func emptyIcon(for segment: ManagerQueueSegment) -> String {
        switch segment {
        case .pendingReview: return "checkmark.shield"
        case .sentBack: return "arrow.uturn.left.circle"
        case .rejected: return "xmark.seal"
        case .approved: return "checkmark.seal"
        }
    }
    
    private func emptyTitle(for segment: ManagerQueueSegment) -> String {
        switch segment {
        case .pendingReview: return "Queue Clear"
        case .sentBack: return "No Sent Back Loans"
        case .rejected: return "No Rejected Loans"
        case .approved: return "No Approved Loans"
        }
    }
    
    private func emptyMessage(for segment: ManagerQueueSegment) -> String {
        switch segment {
        case .pendingReview: return "No applications are currently awaiting manager approval."
        case .sentBack: return "No loans have been sent back to officers."
        case .rejected: return "No loan applications have been rejected."
        case .approved: return "No loans have been approved yet."
        }
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
    
    private func npaBarColor(_ range: String) -> Color {
        switch range {
        case "30–60 days": return .staffAmber
        case "60–90 days": return .orange
        case "90–180 days": return .staffRed.opacity(0.7)
        case "180+ days": return .staffRed
        default: return .staffTextSecondary
        }
    }
}
