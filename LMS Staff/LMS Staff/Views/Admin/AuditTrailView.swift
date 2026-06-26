//
//  AuditTrailView.swift
//  LMS Staff
//
//  Admin Audit Trail viewer displaying system log entries and user actions.
//

import SwiftUI

struct AuditTrailView: View {
    @State private var logs: [AuditLog] = []
    @State private var filteredLogs: [AuditLog] = []
    @State private var searchText: String = ""
    @State private var isLoading: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Security Audit Trail Log")
                    .font(.staffTitle)
                    .foregroundColor(.staffTextPrimary)
                Spacer()
                Button("Refresh Logs") {
                    Task {
                        await loadAuditLogs()
                    }
                }
                .font(.staffBody)
                .foregroundColor(.staffAccent)
            }
            .padding(StaffSpacing.lg)
            .background(Color.staffSurface)
            
            TextField("Search by actor, action, table or summary description...", text: $searchText)
                .padding(12)
                .background(Color.staffSurface)
                .cornerRadius(StaffCorner.md)
                .foregroundColor(.staffTextPrimary)
                .padding(StaffSpacing.lg)
                .onChange(of: searchText) { _ in
                    applyFilters()
                }
            
            Divider()
                .background(Color.staffBorder)
            
            // Logs List Table
            if isLoading {
                Spacer()
                ProgressView()
                    .frame(maxWidth: .infinity)
                Spacer()
            } else if filteredLogs.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: "No Audit Entries",
                    message: "No system changes matches the current search query criteria."
                )
                Spacer()
            } else {
                List(filteredLogs) { log in
                    VStack(alignment: .leading, spacing: StaffSpacing.xs) {
                        HStack {
                            Text(log.action)
                                .font(.staffBody)
                                .fontWeight(.bold)
                                .foregroundColor(.staffAccent)
                            Spacer()
                            Text("Table: \(log.tableName)")
                                .font(.staffCaption)
                                .foregroundColor(.staffTextSecondary)
                        }
                        
                        Text(log.changeSummary ?? "System Configuration Updated")
                            .font(.staffCaption)
                            .foregroundColor(.staffTextPrimary)
                            .padding(.top, 2)
                        
                        HStack {
                            Text("Actor User ID: \(log.actorId?.uuidString.prefix(8) ?? "System")")
                                .font(.system(size: 9))
                                .foregroundColor(.staffTextSecondary.opacity(0.7))
                            Spacer()
                            Text(formatTimestamp(log.createdAt))
                                .font(.system(size: 9))
                                .foregroundColor(.staffTextSecondary.opacity(0.7))
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.staffSurface)
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
                .background(Color.staffBackground)
            }
        }
        .background(Color.staffBackground)
        .task {
            await loadAuditLogs()
        }
    }
    
    private func loadAuditLogs() async {
        isLoading = true
        do {
            let fetched = try await AuditService.shared.fetchAuditLogs(limit: 100)
            self.logs = fetched
            self.filteredLogs = fetched
        } catch {
            print("Error fetching audit logs: \(error)")
        }
        isLoading = false
    }
    
    private func applyFilters() {
        if searchText.isEmpty {
            filteredLogs = logs
        } else {
            let query = searchText.lowercased()
            filteredLogs = logs.filter {
                $0.action.lowercased().contains(query) ||
                $0.tableName.lowercased().contains(query) ||
                ($0.changeSummary ?? "").lowercased().contains(query)
            }
        }
    }
    
    private func formatTimestamp(_ date: Date?) -> String {
        guard let d = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: d)
    }
}
