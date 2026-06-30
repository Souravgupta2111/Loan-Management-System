//
//  OfficerDashboardView.swift
//  LMS Staff
//
//  Main Loan Officer Dashboard: lists assigned applications and allows inspection & decisions.
//

import SwiftUI

struct OfficerDashboardView: View {
    var preselectedFilter: String = "All"
    
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var vm = OfficerDashboardViewModel()
    @State private var selectedApp: ApplicationWithBorrower?
    
    // Sheets/Modals state
    @State private var showRequestDocSheet: Bool = false
    @State private var showRejectSheet: Bool = false
    @State private var showRecommendSheet: Bool = false
    @State private var showSendBackSheet: Bool = false
    @State private var remarks: String = ""
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Column: List & Stats
            VStack(alignment: .leading, spacing: 0) {
                // Dashboard Title
                Text("My Applications")
                    .font(.staffTitle)
                    .foregroundColor(.staffTextPrimary)
                    .padding(.horizontal, StaffSpacing.lg)
                    .padding(.top, StaffSpacing.lg)
                
                // Mini Metric Summary Cards
                HStack(spacing: StaffSpacing.md) {
                    MiniStatCard(title: "New", value: "\(vm.statsPendingCount)", icon: "hourglass", color: .staffAccent)
                    MiniStatCard(title: "Reviewing", value: "\(vm.statsUnderReviewCount)", icon: "eye", color: .staffAmber)
                    MiniStatCard(title: "Approved", value: "\(vm.statsApprovedCount)", icon: "checkmark.circle", color: .staffGreen)
                }
                .padding(StaffSpacing.lg)
                
                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: StaffSpacing.sm) {
                        OfficerFilterChip(title: "All", isSelected: vm.selectedStatusFilter == "All") { vm.selectedStatusFilter = "All" }
                        OfficerFilterChip(title: "Submitted", isSelected: vm.selectedStatusFilter == "Submitted") { vm.selectedStatusFilter = "Submitted" }
                        OfficerFilterChip(title: "Under Review", isSelected: vm.selectedStatusFilter == "Under Review") { vm.selectedStatusFilter = "Under Review" }
                        OfficerFilterChip(title: "Sent Back", isSelected: vm.selectedStatusFilter == "Sent Back") { vm.selectedStatusFilter = "Sent Back" }
                    }
                    .padding(.horizontal, StaffSpacing.lg)
                }
                .padding(.bottom, StaffSpacing.md)
                
                // Search field
                TextField("Search borrower or application...", text: $vm.searchText)
                    .padding(12)
                    .background(Color.staffSurface)
                    .cornerRadius(StaffCorner.md)
                    .foregroundColor(.staffTextPrimary)
                    .padding(.horizontal, StaffSpacing.lg)
                    .padding(.bottom, StaffSpacing.md)
                
                Divider()
                    .background(Color.staffBorder)
                
                // List of applications
                if vm.isLoading {
                    Spacer()
                    ProgressView("Loading applications...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .staffAccent))
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else if vm.filteredApplications.isEmpty {
                    Spacer()
                    EmptyStateView(
                        icon: "doc.text.magnifyingglass",
                        title: "No Applications Found",
                        message: "There are no applications matching the current filters."
                    )
                    Spacer()
                } else {
                    List(vm.filteredApplications, selection: $selectedApp) { app in
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
                        .tag(app)
                        .listRowBackground(Color.staffSurface)
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
            
            // Right Column: Detail Inspector
            if let app = selectedApp {
                ApplicationDetailView(
                    appWithBorrower: app,
                    onStatusUpdated: {
                        Task {
                            if let staff = authViewModel.currentStaff {
                                await vm.loadApplications(forOfficerId: staff.id)
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
            if vm.selectedStatusFilter == "All" && preselectedFilter != "All" {
                vm.selectedStatusFilter = preselectedFilter
            }
            Task {
                if let staff = authViewModel.currentStaff {
                    await vm.loadApplications(forOfficerId: staff.id)
                }
            }
        }
    }
}

// MARK: - MiniStatCard Helper View
struct MiniStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.xs) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
                Text(value)
                    .font(.staffBody)
                    .fontWeight(.bold)
                    .foregroundColor(.staffTextPrimary)
            }
            Text(title)
                .font(.staffCaption)
                .foregroundColor(.staffTextSecondary)
        }
        .padding(StaffSpacing.md)
        .frame(maxWidth: .infinity)
        .background(Color.staffSurface)
        .cornerRadius(StaffCorner.md)
        .overlay(
            RoundedRectangle(cornerRadius: StaffCorner.md)
                .stroke(Color.staffBorder, lineWidth: 1)
        )
    }
}

// MARK: - FilterChip Helper View
struct OfficerFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.staffCaption)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.staffAccent : Color.staffSurface)
                .foregroundColor(isSelected ? .white : .staffTextSecondary)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.staffAccent : Color.staffBorder, lineWidth: 1)
                )
        }
    }
}
