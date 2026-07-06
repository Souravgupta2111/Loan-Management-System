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
    @State private var showChartsSection: Bool = false
    
    // Navigation
    @State private var navigationPath = NavigationPath()
    
    var currentQueue: [ApplicationWithBorrower] {
        switch selectedSegment {
        case .pendingReview: return vm.recommendedApplications
        case .sentBack: return vm.sentBackApplications
        case .rejected: return vm.rejectedApplications
        case .approved: return vm.approvedApplications
        }
    }
    
    // Detail sheet for inspecting an application
    @State private var showDetailSheet: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Manager Console")
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
                .padding(.horizontal, StaffSpacing.lg)
                .padding(.top, StaffSpacing.lg)
            
            VStack(spacing: StaffSpacing.sm) {
                // KPI summary widgets
                kpiCardsSection
                
                // Inline Charts
                if showChartsSection {
                    chartsSection
                }
                
                // Charts toggle
                Button(action: { withAnimation(.easeInOut(duration: 0.25)) { showChartsSection.toggle() } }) {
                    HStack {
                        Image(systemName: showChartsSection ? "chevron.up" : "chart.bar.fill")
                        Text(showChartsSection ? "Hide Insights" : "Show Insights")
                    }
                    .font(.staffCaption)
                    .foregroundColor(.staffAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
            }
            .padding(.horizontal, StaffSpacing.lg)
            .padding(.top, StaffSpacing.sm)
            
            // Segment Control
            Picker("Queue", selection: $selectedSegment) {
                ForEach(ManagerQueueSegment.allCases, id: \.self) { seg in
                    Text("\(seg.rawValue) (\(countFor(seg)))").tag(seg)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, StaffSpacing.lg)
            .padding(.vertical, StaffSpacing.sm)
            .onChange(of: selectedSegment) { _ in
                selectedApp = nil
            }
            
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
                List(currentQueue) { app in
                    Button {
                        selectedApp = app
                        showDetailSheet = true
                    } label: {
                        queueListRow(app)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
                .background(Color.staffBackground)
            }
        }
        .background(Color.staffBackground)
        .onAppear {
            Task { await vm.loadDashboard() }
        }
        .sheet(isPresented: $showDetailSheet) {
            if let app = selectedApp {
                NavigationStack {
                    if selectedSegment == .pendingReview {
                        recommendationInspectorSection(app)
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarLeading) {
                                    Button("Close") { showDetailSheet = false }
                                }
                            }
                    } else {
                        readOnlyInspectorSection(app)
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarLeading) {
                                    Button("Close") { showDetailSheet = false }
                                }
                            }
                    }
                }
            }
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
    
    // MARK: - Inline Charts
    
    private var chartsSection: some View {
        VStack(spacing: StaffSpacing.sm) {
            // Collection Efficiency Sparkline
            if !vm.collectionTrends.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Collection Efficiency Trend")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.staffTextSecondary)
                    
                    Chart(vm.collectionTrends) { item in
                        LineMark(
                            x: .value("Month", item.month),
                            y: .value("Eff", item.efficiency)
                        )
                        .foregroundStyle(Color.staffGreen)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        
                        AreaMark(
                            x: .value("Month", item.month),
                            y: .value("Eff", item.efficiency)
                        )
                        .foregroundStyle(
                            LinearGradient(colors: [Color.staffGreen.opacity(0.3), Color.staffGreen.opacity(0.02)], startPoint: .top, endPoint: .bottom)
                        )
                    }
                    .frame(height: 60)
                    .chartYScale(domain: 0...100)
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                }
                .padding(10)
                .background(Color.staffSurface)
                .cornerRadius(StaffCorner.md)
            }
            
            HStack(spacing: StaffSpacing.sm) {
                // Portfolio Breakdown Donut
                if !vm.portfolioBreakdown.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Portfolio Mix")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.staffTextSecondary)
                        
                        Chart(vm.portfolioBreakdown, id: \.status) { item in
                            SectorMark(
                                angle: .value("Amount", item.amount),
                                innerRadius: .ratio(0.55),
                                angularInset: 1.5
                            )
                            .foregroundStyle(colorForStatus(item.status))
                            .annotation(position: .overlay) {
                                if item.count > 0 {
                                    Text("\(item.count)")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .frame(height: 90)
                        
                        // Legend
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(vm.portfolioBreakdown, id: \.status) { item in
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(colorForStatus(item.status))
                                        .frame(width: 6, height: 6)
                                    Text("\(item.status): \(item.count)")
                                        .font(.system(size: 9))
                                        .foregroundColor(.staffTextSecondary)
                                }
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.staffSurface)
                    .cornerRadius(StaffCorner.md)
                }
                
                // NPA Aging Bars
                VStack(alignment: .leading, spacing: 4) {
                    Text("NPA Aging")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.staffTextSecondary)
                    
                    let totalNPA = vm.npaAgingBuckets.reduce(0) { $0 + $1.count }
                    
                    if totalNPA == 0 {
                        Text("No NPA loans")
                            .font(.system(size: 10))
                            .foregroundColor(.staffGreen)
                            .frame(maxWidth: .infinity, minHeight: 90, alignment: .center)
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
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.staffTextSecondary)
                                }
                            }
                        }
                        .frame(height: 90)
                        .chartXAxis(.hidden)
                        .chartYAxis {
                            AxisMarks { _ in
                                AxisValueLabel()
                                    .font(.system(size: 8))
                                    .foregroundStyle(Color.staffTextSecondary)
                            }
                        }
                    }
                }
                .padding(10)
                .background(Color.staffSurface)
                .cornerRadius(StaffCorner.md)
            }
        }
    }
    
    // MARK: - Queue List Row
    
    @ViewBuilder
    private func queueListRow(_ app: ApplicationWithBorrower) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(app.borrower.fullName)
                    .font(.staffBody)
                    .fontWeight(.bold)
                    .foregroundColor(.staffTextPrimary)
                Spacer()
                Text("₹\(String(format: "%.0f", app.application.requestedAmount))")
                    .font(.staffBody)
                    .fontWeight(.bold)
                    .foregroundColor(.staffAccent)
            }
            
            HStack {
                Text(app.application.applicationNumber ?? "APP-NEW")
                    .font(.staffCaption)
                    .foregroundColor(.staffTextSecondary)
                Spacer()
                
                if selectedSegment == .sentBack {
                    Text("Sent Back")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.staffAmber)
                } else if selectedSegment == .rejected {
                    Text("✕ Rejected")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.staffRed)
                } else if selectedSegment == .approved {
                    Text("✓ Approved")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.staffGreen)
                } else {
                    Text("Tenure: \(app.application.requestedTenureMonths)m")
                        .font(.system(size: 12))
                        .foregroundColor(.staffTextSecondary)
                }
            }
        }
        .padding(16)
        .background(Color.staffSurface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.staffBorder, lineWidth: 1)
        )
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
