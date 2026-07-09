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
                            
                            Button(action: {
                                metricDetailTitle = "NPA Loans"
                                metricDetailData = .loans(vm.npaList)
                                showMetricDetailSheet = true
                            }) {
                                MetricBlockCard(title: "System NPA Ratio", value: String(format: "%.2f%%", vm.systemNpaRatio), icon: "exclamationmark.triangle.fill", color: .staffRed)
                            }
                            .buttonStyle(PlainButtonStyle())
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
                                .accessibilityAddTraits(.isHeader)
                            
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
                                        auditLogRow(log)
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
    
    @ViewBuilder
    private func auditLogRow(_ log: AuditLog) -> some View {
        HStack(alignment: .top, spacing: StaffSpacing.md) {
            // Action Icon
            ZStack {
                Circle()
                    .fill(actionColor(log.action).opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: actionIcon(log.action))
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(actionColor(log.action))
            }
            .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 4) {
                // Action title + table badge
                HStack(spacing: 6) {
                    Text(formatActionName(log.action))
                        .font(.staffBody)
                        .fontWeight(.bold)
                        .foregroundColor(.staffTextPrimary)
                    
                    Text(log.tableName)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.staffAccent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.staffAccent.opacity(0.1))
                        .cornerRadius(4)
                }
                
                // Change summary
                Text(log.changeSummary ?? "System configuration updated")
                    .font(.staffCaption)
                    .foregroundColor(.staffTextPrimary)
                    .lineLimit(3)
                
                // Actor + Timestamp footer
                HStack(spacing: 8) {
                    // Actor info
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .accessibilityHidden(true)
                        if let actorId = log.actorId, let name = vm.actorNames[actorId] {
                            Text(name)
                                .fontWeight(.medium)
                        } else {
                            Text("System")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.staffTextSecondary)
                    
                    // Role Badge
                    if let role = log.actorRole {
                        Text(role.rawValue.capitalized)
                            .font(.caption.weight(.bold))
                            .foregroundColor(roleBadgeColor(role))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(roleBadgeColor(role).opacity(0.12))
                            .cornerRadius(3)
                    }
                    
                    Spacer()
                    
                    // Timestamp
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .accessibilityHidden(true)
                        Text(formatTimestamp(log.createdAt))
                    }
                    .font(.caption)
                    .foregroundColor(.staffTextSecondary)
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, StaffSpacing.md)
        .accessibilityElement(children: .combine)
    }
    
    private func formatTimestamp(_ date: Date?) -> String {
        guard let d = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy 'at' h:mm a"
        return formatter.string(from: d)
    }
    
    private func formatActionName(_ action: String) -> String {
        action.replacingOccurrences(of: "_", with: " ")
              .split(separator: " ")
              .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
              .joined(separator: " ")
    }
    
    private func actionIcon(_ action: String) -> String {
        let a = action.uppercased()
        if a.contains("CREATE") || a.contains("INSERT") { return "plus.circle.fill" }
        if a.contains("UPDATE") || a.contains("EDIT") { return "pencil.circle.fill" }
        if a.contains("DELETE") || a.contains("REMOVE") { return "trash.circle.fill" }
        if a.contains("APPROVE") { return "checkmark.seal.fill" }
        if a.contains("REJECT") { return "xmark.seal.fill" }
        if a.contains("RESET") { return "key.fill" }
        if a.contains("ASSIGN") { return "person.badge.plus" }
        if a.contains("DISBURSE") { return "banknote.fill" }
        if a.contains("LOGIN") || a.contains("AUTH") { return "lock.shield.fill" }
        if a.contains("STATUS") { return "arrow.triangle.2.circlepath" }
        if a.contains("SEND_BACK") || a.contains("SENT_BACK") { return "arrow.uturn.left.circle.fill" }
        if a.contains("SYSTEM") { return "gearshape.fill" }
        if a.contains("ESCALATE") { return "arrow.up.circle.fill" }
        return "doc.text.fill"
    }
    
    private func actionColor(_ action: String) -> Color {
        let a = action.uppercased()
        if a.contains("CREATE") || a.contains("INSERT") { return .staffGreen }
        if a.contains("APPROVE") || a.contains("DISBURSE") { return .staffGreen }
        if a.contains("DELETE") || a.contains("REJECT") { return .staffRed }
        if a.contains("RESET") { return .staffAmber }
        if a.contains("SEND_BACK") || a.contains("SENT_BACK") { return .staffAmber }
        if a.contains("UPDATE") || a.contains("ASSIGN") { return .staffAccent }
        return .staffTextSecondary
    }
    
    private func roleBadgeColor(_ role: UserRole) -> Color {
        switch role {
        case .admin: return .staffRed
        case .manager: return .staffAmber
        case .officer: return .staffAccent
        case .borrower: return .staffGreen
        }
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(value)")
    }
}
