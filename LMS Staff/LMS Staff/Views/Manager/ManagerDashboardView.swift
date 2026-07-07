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
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @StateObject private var vm = ManagerDashboardViewModel()
    @State private var selectedApp: ApplicationWithBorrower?
    @State private var selectedSegment: ManagerQueueSegment = .pendingReview
    
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
    
    // AI Analytics
    @State private var showAIAnalytics: Bool = false
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
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
            .fullScreenCover(isPresented: $showDetailSheet) {
                if let app = selectedApp {
                    NavigationStack {
                        ApplicationDetailView(appWithBorrower: app, onStatusUpdated: {
                            showDetailSheet = false
                            Task { await vm.loadDashboard() }
                        })
                        .environmentObject(authViewModel)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Close") { showDetailSheet = false }
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showMetricDetailSheet) {
                NavigationStack {
                    MetricDetailSheet(title: metricDetailTitle, data: metricDetailData)
                }
            }
            .sheet(isPresented: $showAIAnalytics) {
                NavigationStack {
                    AIAnalyticsView()
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Close") { showAIAnalytics = false }
                            }
                        }
                }
            }
            
            // Floating AI Button
            Button(action: { showAIAnalytics = true }) {
                ZStack {
                    Circle()
                        .fill(Color.staffAccent)
                        .frame(width: 56, height: 56)
                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                    Image(systemName: "sparkles")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(.trailing, 24)
            .padding(.bottom, 24)
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
                        .font(.caption.weight(.bold))
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
                            .font(.caption.weight(.bold))
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
                                        .font(.caption.weight(.bold))
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
                                        .font(.caption)
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
                        .font(.caption.weight(.bold))
                        .foregroundColor(.staffTextSecondary)
                    
                    let totalNPA = vm.npaAgingBuckets.reduce(0) { $0 + $1.count }
                    
                    if totalNPA == 0 {
                        Text("No NPA loans")
                            .font(.caption)
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
                                        .font(.caption.weight(.bold))
                                        .foregroundColor(.staffTextSecondary)
                                }
                            }
                        }
                        .frame(height: 90)
                        .chartXAxis(.hidden)
                        .chartYAxis {
                            AxisMarks { _ in
                                AxisValueLabel()
                                    .font(.caption)
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
                    Text("↩ Sent Back")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.staffAmber)
                } else if selectedSegment == .rejected {
                    Text("✕ Rejected")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.staffRed)
                } else if selectedSegment == .approved {
                    Text("✓ Approved")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.staffGreen)
                } else {
                    Text("Tenure: \(app.application.requestedTenureMonths)m")
                        .font(.caption)
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
    
    // MARK: - Helpers
    
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
