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
    case approved = "Approved"
    case rejected = "Rejected"
}

struct ManagerDashboardView: View {
    var preselectedView: ManagerDashboardMode = .standard
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @StateObject private var vm = ManagerDashboardViewModel()
    @State private var selectedApp: ApplicationWithBorrower?
    @State private var selectedSegment: ManagerQueueSegment = .pendingReview
    

    

    
    // Search
    @State private var searchText: String = ""
    

    
    var currentQueue: [ApplicationWithBorrower] {
        switch selectedSegment {
        case .pendingReview: return vm.recommendedApplications
        case .sentBack: return vm.sentBackApplications
        case .rejected: return vm.rejectedApplications
        case .approved: return vm.approvedApplications
        }
    }
    
    var filteredQueue: [ApplicationWithBorrower] {
        if searchText.isEmpty {
            return currentQueue
        }
        let query = searchText.lowercased()
        return currentQueue.filter { app in
            app.borrower.fullName.lowercased().contains(query) ||
            (app.application.applicationNumber ?? "").lowercased().contains(query)
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            HStack(spacing: 0) {
                // MARK: - Left Column: List & Stats
                VStack(alignment: .leading, spacing: 0) {
                    // Dashboard Title
                    Text("Manager Console")
                        .font(.staffTitle)
                        .foregroundColor(.staffTextPrimary)
                        .padding(.horizontal, StaffSpacing.lg)
                        .padding(.top, StaffSpacing.lg)
                    
                    // KPI Section
                    VStack(spacing: StaffSpacing.sm) {
                        // KPI summary widgets
                        kpiCardsSection
                    }
                    .padding(.horizontal, StaffSpacing.lg)
                    .padding(.top, StaffSpacing.sm)
                    
                    // Queue filter chips (horizontally scrollable)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: StaffSpacing.sm) {
                            ForEach(ManagerQueueSegment.allCases, id: \.self) { seg in
                                OfficerFilterChip(
                                    title: seg.rawValue,
                                    isSelected: selectedSegment == seg
                                ) {
                                    selectedSegment = seg
                                    selectedApp = nil
                                }
                            }
                        }
                        .padding(.horizontal, StaffSpacing.lg)
                    }
                    .padding(.top, StaffSpacing.lg)
                    .padding(.bottom, StaffSpacing.md)
                    
                    // Search field
                    TextField("Search borrower or application...", text: $searchText)
                        .padding(12)
                        .background(Color.staffSurface)
                        .cornerRadius(StaffCorner.md)
                        .foregroundColor(.staffTextPrimary)
                        .padding(.horizontal, StaffSpacing.lg)
                        .padding(.bottom, StaffSpacing.md)
                    
                    Divider()
                        .background(Color.staffBorder)
                    
                    // Queue List
                    if vm.isLoading {
                        Spacer()
                        ProgressView("Loading applications...")
                            .progressViewStyle(CircularProgressViewStyle(tint: .staffAccent))
                            .frame(maxWidth: .infinity)
                        Spacer()
                    } else if filteredQueue.isEmpty {
                        Spacer()
                        EmptyStateView(
                            icon: emptyIcon(for: selectedSegment),
                            title: emptyTitle(for: selectedSegment),
                            message: emptyMessage(for: selectedSegment)
                        )
                        Spacer()
                    } else {
                        List(filteredQueue, id: \.application.id) { app in
                            Button(action: {
                                selectedApp = app
                            }) {
                                VStack(alignment: .leading, spacing: StaffSpacing.xs) {
                                    HStack {
                                        Text(app.borrower.fullName)
                                            .font(.staffBody)
                                            .fontWeight(.bold)
                                            .foregroundColor(.staffTextPrimary)
                                        Spacer()
                                        StaffStatusBadge(status: app.application.status.displayName)
                                    }
                                    
                                    HStack {
                                        Text(app.application.applicationNumber ?? "APP-NEW")
                                            .font(.staffCaption)
                                            .foregroundColor(.staffTextSecondary)
                                        Spacer()
                                        Text("INR \(String(format: "%.2f", app.application.requestedAmount))")
                                            .font(.staffCaption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.staffAccent)
                                    }
                                }
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .listRowBackground(
                                selectedApp?.application.id == app.application.id
                                ? Color.staffAccent.opacity(0.15)
                                : Color.staffSurface
                            )
                        }
                        .listStyle(PlainListStyle())
                        .scrollContentBackground(.hidden)
                        .background(Color.staffBackground)
                    }
                }
                .frame(width: 360)
                .background(Color.staffBackground)
                
                Divider()
                    .background(Color.staffBorder)
                
                // MARK: - Right Column: Detail Inspector
                if let app = selectedApp {
                    ApplicationDetailView(
                        appWithBorrower: app,
                        onStatusUpdated: {
                            Task {
                                await vm.loadDashboard()
                                if let selected = selectedApp {
                                    // Try to reselect the same app if it still exists in the queue
                                    selectedApp = currentQueue.first(where: { $0.application.id == selected.application.id })
                                }
                            }
                        }
                    )
                    .id(app.application.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: StaffSpacing.md) {
                        Image(systemName: "hand.tap.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.staffTextSecondary.opacity(0.3))
                        Text("Select an Application to Inspect")
                            .font(.staffTitle)
                            .foregroundColor(.staffTextSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.staffSurface.opacity(0.1))
                }
            }
            .background(Color.staffBackground)
            .onAppear {
                Task { await vm.loadDashboard() }
            }
        }
    }
    
    // MARK: - KPI Cards
    
    private var kpiCardsSection: some View {
        VStack(spacing: StaffSpacing.sm) {
            HStack(spacing: StaffSpacing.sm) {
                MiniStatCard(title: "Portfolio", value: "₹\(formatAmount(vm.totalDisbursed))", icon: "briefcase", color: .staffAccent)
                MiniStatCard(title: "Active Loans", value: "\(vm.activeLoansCount)", icon: "person.2", color: .staffAmber)
            }
            HStack(spacing: StaffSpacing.sm) {
                MiniStatCard(title: "Collection", value: String(format: "%.1f%%", vm.collectionEfficiency), icon: "chart.bar", color: .staffGreen)
                MiniStatCard(title: "NPA", value: String(format: "%.1f%%", vm.npaRatio), icon: "exclamationmark.triangle", color: .staffRed)
            }
        }
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
