//
//  AuditTrailView.swift
//  LMS Staff
//
//  Admin Audit Trail viewer displaying system log entries and user actions.
//

import SwiftUI

struct AuditTrailView: View {
    @State private var logs: [AuditLog] = []
    @State private var searchText: String = ""
    @State private var isLoading: Bool = false
    @State private var isLoadingMore: Bool = false
    @State private var hasMoreLogs: Bool = true
    @State private var offset: Int = 0
    private let pageSize: Int = 30
    
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
                    Task {
                        // Debounce search input
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        await loadAuditLogs()
                    }
                }
            
            Divider()
                .background(Color.staffBorder)
            
            // Logs List Table
            if isLoading {
                Spacer()
                ProgressView()
                    .frame(maxWidth: .infinity)
                Spacer()
            } else if logs.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: "No Audit Entries",
                    message: "No system changes matches the current search query criteria."
                )
                Spacer()
            } else {
                List {
                    ForEach(logs) { log in
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
                    } // Close ForEach
                    
                    if hasMoreLogs {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .listRowBackground(Color.staffBackground)
                        .onAppear {
                            Task {
                                await loadMoreAuditLogs()
                            }
                        }
                    }
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
        offset = 0
        hasMoreLogs = true
        do {
            if searchText.isEmpty {
                await AuditService.shared.seedAuditLogsIfEmpty()
            }
            let fetched = try await AuditService.shared.fetchAuditLogs(offset: offset, limit: pageSize, searchQuery: searchText)
            self.logs = fetched
            if fetched.count < pageSize {
                self.hasMoreLogs = false
            }
        } catch {
            print("Error fetching audit logs: \(error)")
        }
        isLoading = false
    }
    
    private func loadMoreAuditLogs() async {
        guard hasMoreLogs && !isLoadingMore && !isLoading else { return }
        
        isLoadingMore = true
        offset += pageSize
        
        do {
            let fetched = try await AuditService.shared.fetchAuditLogs(offset: offset, limit: pageSize, searchQuery: searchText)
            if fetched.isEmpty {
                self.hasMoreLogs = false
            } else {
                self.logs.append(contentsOf: fetched)
                if fetched.count < pageSize {
                    self.hasMoreLogs = false
                }
            }
        } catch {
            print("Error fetching more audit logs: \(error)")
        }
        isLoadingMore = false
    }
    
    private func formatTimestamp(_ date: Date?) -> String {
        guard let d = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: d)
    }
}
