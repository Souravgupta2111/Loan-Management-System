//
//  AdminDashboardView.swift
//  LMS Staff
//
//  Admin dashboard showing consolidated institutional numbers and audit log feeds.
//

import SwiftUI

struct AdminDashboardView: View {
    @StateObject private var vm = AdminDashboardViewModel()
    
    @State private var showMetricDetailSheet: Bool = false
    @State private var metricDetailTitle: String = ""
    @State private var metricDetailData: MetricDataType = .applications([])
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: StaffSpacing.lg) {
                    Spacer(minLength: StaffSpacing.md)
                    
                    // Consolidation Grid widgets
                    VStack(spacing: StaffSpacing.md) {
                        HStack(spacing: StaffSpacing.md) {
                            Button(action: {
                                metricDetailTitle = "Consolidated Application"
                                metricDetailData = .applications(vm.allApplicationsList)
                                showMetricDetailSheet = true
                            }) {
                                MetricBlockCard(title: "Consolidated Application", value: "\(vm.totalApplicationsCount)", icon: "doc.text.fill", color: .staffAccent)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: {
                                metricDetailTitle = "Awaiting Action"
                                metricDetailData = .applications(vm.pendingReviewsList)
                                showMetricDetailSheet = true
                            }) {
                                MetricBlockCard(title: "Awaiting Action", value: "\(vm.pendingReviewsCount)", icon: "hourglass", color: .staffAmber)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            MetricBlockCard(title: "System NPA Ratio", value: String(format: "%.2f%%", vm.systemNpaRatio), icon: "exclamationmark.triangle.fill", color: .staffRed)
                        }
                        HStack(spacing: StaffSpacing.md) {
                            Button(action: {
                                metricDetailTitle = "Approved Count"
                                metricDetailData = .applications(vm.approvedList)
                                showMetricDetailSheet = true
                            }) {
                                MetricBlockCard(title: "Approved Count", value: "\(vm.approvedCount)", icon: "checkmark.circle.fill", color: .staffGreen)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: {
                                metricDetailTitle = "Rejected Count"
                                metricDetailData = .applications(vm.rejectedList)
                                showMetricDetailSheet = true
                            }) {
                                MetricBlockCard(title: "Rejected Count", value: "\(vm.rejectedCount)", icon: "xmark.circle.fill", color: .staffRed)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: {
                                metricDetailTitle = "Disbursed Count"
                                metricDetailData = .applications(vm.disbursedList)
                                showMetricDetailSheet = true
                            }) {
                                MetricBlockCard(title: "Disbursed Count", value: "\(vm.disbursedCount)", icon: "banknote.fill", color: .staffAccent)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, StaffSpacing.lg)
                    
                    // Recent Audit Activity Log
                    StaffCard {
                        VStack(alignment: .leading, spacing: StaffSpacing.md) {
                            Text("Recent Security Audit Trail")
                                .font(.staffTitle)
                                .foregroundColor(.staffTextPrimary)
                            
                            Divider()
                            
                            if vm.isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else if vm.recentActivities.isEmpty {
                                EmptyStateView(
                                    icon: "clock.arrow.circlepath",
                                    title: "Audit Trail Clean",
                                    message: "No recent transactions logged in security database."
                                )
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(vm.recentActivities) { log in
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(log.changeSummary ?? "System Change")
                                                    .font(.staffBody)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.staffTextPrimary)
                                                
                                                Text("Table: \(log.tableName) | Action: \(log.action)")
                                                    .font(.staffCaption)
                                                    .foregroundColor(.staffTextSecondary)
                                            }
                                            
                                            Spacer()
                                            
                                            Text(formatDate(log.createdAt))
                                                .font(.caption)
                                                .foregroundColor(.staffTextSecondary)
                                        }
                                        .padding(.vertical, 8)
                                        
                                        Divider()
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, StaffSpacing.lg)
                }
            }
            .navigationTitle("System Overview")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.staffBackground)
            .navigationDestination(isPresented: $showMetricDetailSheet) {
                MetricDetailSheet(title: metricDetailTitle, data: metricDetailData)
            }
        }
        .onAppear {
            Task {
                await vm.loadDashboard()
            }
        }
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let d = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: d)
    }
}

// MARK: - MetricBlockCard Helper Subview
struct MetricBlockCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.sm) {
            HStack {
                Image(systemName: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title.weight(.bold))
                .foregroundColor(.staffTextPrimary)
            
            Text(title)
                .font(.staffCaption)
                .foregroundColor(.staffTextSecondary)
        }
        .padding(StaffSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(Color.staffSurface)
        .cornerRadius(StaffCorner.md)
        .overlay(
            RoundedRectangle(cornerRadius: StaffCorner.md)
                .stroke(Color.staffBorder, lineWidth: 1)
        )
    }
}
