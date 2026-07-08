//
//  AuditTrailView.swift
//  LMS Staff
//
//  Admin System Activity Log — displays real systemwide activity with proper timestamps,
//  actor names, role badges, and action icons. Lazy-loads 30 items at a time.
//

import SwiftUI
import Supabase
import PostgREST

struct AuditTrailView: View {
    @State private var logs: [AuditLog] = []
    @State private var actorNames: [UUID: String] = [:]
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
                VStack(alignment: .leading, spacing: 2) {
                    Text("System Activity Log")
                        .font(.staffTitle)
                        .foregroundColor(.staffTextPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text("\(logs.count) entries loaded")
                        .font(.staffCaption)
                        .foregroundColor(.staffTextSecondary)
                }
                Spacer()
                Button(action: {
                    Task { await loadAuditLogs() }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                    .font(.staffBody)
                    .foregroundColor(.staffAccent)
                }
            }
            .padding(StaffSpacing.lg)
            .background(Color.staffSurface)
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.staffTextSecondary)
                    .accessibilityHidden(true)
                TextField("Search actions, tables, or descriptions...", text: $searchText)
                    .foregroundColor(.staffTextPrimary)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.staffTextSecondary)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(12)
            .background(Color.staffSurface)
            .cornerRadius(StaffCorner.md)
            .padding(.horizontal, StaffSpacing.lg)
            .padding(.vertical, StaffSpacing.sm)
            .onChange(of: searchText) { _ in
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    await loadAuditLogs()
                }
            }
            
            Divider()
                .background(Color.staffBorder)
            
            // Logs List
            if isLoading {
                Spacer()
                ProgressView("Loading activity logs...")
                    .frame(maxWidth: .infinity)
                Spacer()
            } else if logs.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: "No Activity Recorded",
                    message: searchText.isEmpty
                        ? "No system activity has been recorded yet. Actions like logins, loan updates, and staff changes will appear here."
                        : "No activity matches '\(searchText)'. Try a different search term."
                )
                Spacer()
            } else {
                List {
                    ForEach(logs) { log in
                        auditLogRow(log)
                            .listRowBackground(Color.staffSurface)
                            .listRowSeparator(.hidden)
                    }
                    
                    // Load More Trigger
                    if hasMoreLogs {
                        HStack {
                            Spacer()
                            if isLoadingMore {
                                ProgressView()
                                    .padding(.vertical, 12)
                            }
                            Spacer()
                        }
                        .listRowBackground(Color.staffBackground)
                        .onAppear {
                            Task { await loadMoreAuditLogs() }
                        }
                    } else if logs.count >= pageSize {
                        HStack {
                            Spacer()
                            Text("All \(logs.count) entries loaded")
                                .font(.staffCaption)
                                .foregroundColor(.staffTextSecondary)
                                .padding(.vertical, 12)
                            Spacer()
                        }
                        .listRowBackground(Color.staffBackground)
                    }
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
                .background(Color.white)
            }
        }
        .background(Color.white)
        .task {
            await loadAuditLogs()
        }
    }
    
    // MARK: - Row View
    
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
                        if let actorId = log.actorId, let name = actorNames[actorId] {
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
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
    
    // MARK: - Data Loading
    
    private func loadAuditLogs() async {
        isLoading = true
        offset = 0
        hasMoreLogs = true
        do {
            let fetched = try await AuditService.shared.fetchAuditLogs(offset: offset, limit: pageSize, searchQuery: searchText)
            self.logs = fetched
            if fetched.count < pageSize {
                self.hasMoreLogs = false
            }
            await resolveActorNames(for: fetched)
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
                await resolveActorNames(for: fetched)
            }
        } catch {
            print("Error fetching more audit logs: \(error)")
        }
        isLoadingMore = false
    }
    
    /// Resolves actor UUIDs to display names from users table
    private func resolveActorNames(for logs: [AuditLog]) async {
        let unknownIds = Set(logs.compactMap { $0.actorId }).subtracting(actorNames.keys)
        guard !unknownIds.isEmpty else { return }
        
        struct UserNameRecord: Decodable {
            let id: UUID
            let full_name: String
        }
        
        do {
            let records: [UserNameRecord] = try await SupabaseManager.shared.database
                .from("users")
                .select("id, full_name")
                .in("id", values: unknownIds.map { $0.uuidString })
                .execute()
                .value
            
            for record in records {
                actorNames[record.id] = record.full_name
            }
        } catch {
            print("Failed to resolve actor names: \(error)")
        }
    }
    
    // MARK: - Formatting Helpers
    
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
