//
//  StaffWidgets.swift
//  StaffWidgets (Widget Extension for LMS Staff)
//
//  Role-aware staff widgets — neutral liquid glass (adaptive), no brand tint.
//  Reads the snapshot the staff app publishes to the shared App Group.
//  Deep links use the lmsstaffapp:// scheme (routed in the staff ContentView).
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Shared keys + DTO (mirror StaffWidgetKeys / DTO in the app)

enum SWKeys {
    static let appGroupID = "group.com.sourav.hi123.LMS-Staff"
    static let snapshot = "staffwidget.snapshot"
    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }
}

struct StaffAuditEntryDTO: Codable, Identifiable {
    var id: String
    var action: String
    var actor: String
    var role: String?
    var date: Date
}

struct StaffWidgetSnapshotDTO: Codable {
    var role: String
    var officerPending: Int
    var officerSubmitted: Int
    var officerUnderReview: Int
    var oldestName: String?
    var oldestDays: Int?
    var activeLoans: Int
    var totalDisbursed: Double
    var npaPercentage: Double
    var collectionEfficiency: Double
    var pendingApprovals: Int
    var overdueEmis: Int
    var npaCount: Int
    var totalBorrowers: Int
    var staffCount: Int
    var branchCount: Int
    var auditAlerts24h: Int
    var auditEntries: [StaffAuditEntryDTO] = []
    var generated: Date

    static let sample = StaffWidgetSnapshotDTO(
        role: "sample", officerPending: 7, officerSubmitted: 4, officerUnderReview: 3,
        oldestName: "Ravi Kumar", oldestDays: 3, activeLoans: 128, totalDisbursed: 48_500_000,
        npaPercentage: 4.2, collectionEfficiency: 92, pendingApprovals: 9, overdueEmis: 15,
        npaCount: 6, totalBorrowers: 342, staffCount: 18, branchCount: 5, auditAlerts24h: 23,
        auditEntries: [
            StaffAuditEntryDTO(id: "1", action: "loan_approved", actor: "Priya Nair", role: "manager", date: Date().addingTimeInterval(-1_200)),
            StaffAuditEntryDTO(id: "2", action: "application_rejected", actor: "Amit Shah", role: "officer", date: Date().addingTimeInterval(-5_400)),
            StaffAuditEntryDTO(id: "3", action: "loan_disbursed", actor: "Priya Nair", role: "manager", date: Date().addingTimeInterval(-9_000)),
            StaffAuditEntryDTO(id: "4", action: "staff_created", actor: "System Admin", role: "admin", date: Date().addingTimeInterval(-18_000)),
            StaffAuditEntryDTO(id: "5", action: "password_reset", actor: "System Admin", role: "admin", date: Date().addingTimeInterval(-32_000)),
            StaffAuditEntryDTO(id: "6", action: "application_assigned", actor: "Priya Nair", role: "manager", date: Date().addingTimeInterval(-54_000))
        ],
        generated: .now
    )

    static func load() -> StaffWidgetSnapshotDTO {
        guard let d = SWKeys.defaults, let data = d.data(forKey: SWKeys.snapshot),
              let snap = try? JSONDecoder().decode(StaffWidgetSnapshotDTO.self, from: data)
        else { return sample }
        return snap
    }
}

// MARK: - Formatting

func swInrCompact(_ v: Double) -> String {
    if v >= 10_000_000 { return String(format: "₹%.1fCr", v / 10_000_000) }
    if v >= 100_000 { return String(format: "₹%.1fL", v / 100_000) }
    if v >= 1_000 { return String(format: "₹%.0fK", v / 1_000) }
    return "₹\(Int(v))"
}

// MARK: - Staff theme greens (mirror the staff app's mint palette)

extension Color {
    static let swMintCanvas = Color(.sRGB, red: 0.945, green: 0.973, blue: 0.941, opacity: 1) // #F1F8F0
    static let swMintTint   = Color(.sRGB, red: 0.875, green: 0.953, blue: 0.902, opacity: 1) // #DFF3E6
    static let swGreen      = Color(.sRGB, red: 0.180, green: 0.588, blue: 0.345, opacity: 1) // #2E9658
    static let swDarkGreen  = Color(.sRGB, red: 0.086, green: 0.220, blue: 0.153, opacity: 1) // deep green
}

// MARK: - Glass background (mint-tinted, adaptive)

/// Mint-green liquid glass matching the staff app's background, with a green rim.
/// Stays translucent (frosted material) in both light and dark.
struct StaffGlassBG: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay {
                if scheme == .dark {
                    LinearGradient(colors: [Color.swDarkGreen.opacity(0.62), Color.swDarkGreen.opacity(0.38)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                } else {
                    LinearGradient(colors: [Color.swMintCanvas.opacity(0.82), Color.swMintTint.opacity(0.62)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            .overlay(
                ContainerRelativeShape()
                    .strokeBorder(Color.swGreen.opacity(scheme == .dark ? 0.40 : 0.28), lineWidth: 1)
            )
    }
}

extension View {
    /// Standard glass widget container: consistent inner padding + fill + glass bg.
    func glassWidget(_ alignment: Alignment = .topLeading) -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .containerBackground(for: .widget) { StaffGlassBG() }
    }
}

// MARK: - Timeline

struct SWEntry: TimelineEntry {
    let date: Date
    let snapshot: StaffWidgetSnapshotDTO
}

struct SWProvider: TimelineProvider {
    func placeholder(in context: Context) -> SWEntry { SWEntry(date: .now, snapshot: .sample) }
    func getSnapshot(in context: Context, completion: @escaping (SWEntry) -> Void) {
        completion(SWEntry(date: .now, snapshot: context.isPreview ? .sample : .load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SWEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .minute, value: 60, to: .now) ?? .now
        completion(Timeline(entries: [SWEntry(date: .now, snapshot: .load())], policy: .after(next)))
    }
}

private func wrongRole(_ snap: StaffWidgetSnapshotDTO, _ allowed: [String]) -> Bool {
    // "sample" is the placeholder/gallery snapshot — show it for every widget so
    // the gallery preview never shows a "Sign in as…" hint on unrelated roles.
    if snap.role == "sample" { return false }
    return !allowed.contains(snap.role)
}

private struct SignInHint: View {
    let role: String
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "person.crop.circle.badge.questionmark").font(.title2).foregroundStyle(.secondary)
            Text("Sign in as \(role)").font(.caption).foregroundStyle(.secondary)
        }
        .glassWidget(.center)
    }
}

private func swHeader(_ title: String, _ icon: String) -> some View {
    Label(title, systemImage: icon).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
}

// ============================================================================
// OFFICER
// ============================================================================

struct OfficerQueueView: View {
    var entry: SWEntry
    var body: some View {
        let s = entry.snapshot
        if wrongRole(s, ["officer"]) { SignInHint(role: "officer") } else {
            VStack(alignment: .leading, spacing: 8) {
                swHeader("My Review Queue", "tray.full")
                Text("\(s.officerPending)").font(.system(size: 44, weight: .bold)).minimumScaleFactor(0.5)
                Text("applications pending").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    pill("\(s.officerSubmitted) new", .blue)
                    pill("\(s.officerUnderReview) reviewing", .orange)
                }
                Spacer(minLength: 0)
            }
            .glassWidget()
            .widgetURL(URL(string: "lmsstaffapp://applications"))
        }
    }
    private func pill(_ text: String, _ color: Color) -> some View {
        Text(text).font(.caption2.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.18), in: Capsule()).foregroundStyle(color)
    }
}

struct OfficerQueueWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "OfficerQueueWidget", provider: SWProvider()) { OfficerQueueView(entry: $0) }
            .configurationDisplayName("My Review Queue")
            .description("Applications assigned to you, pending review.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct OldestPendingView: View {
    var entry: SWEntry
    var body: some View {
        let s = entry.snapshot
        if wrongRole(s, ["officer"]) { SignInHint(role: "officer") } else {
            VStack(alignment: .leading, spacing: 6) {
                swHeader("Oldest Pending", "clock.badge.exclamationmark")
                if let name = s.oldestName, let days = s.oldestDays {
                    Text(name).font(.headline).lineLimit(1)
                    Text("Waiting \(days) day\(days == 1 ? "" : "s")")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(days >= 5 ? Color.red : (days >= 3 ? Color.orange : Color.secondary))
                    Text("Review to keep SLA on track").font(.caption2).foregroundStyle(.secondary)
                } else {
                    Spacer()
                    Text("Nothing waiting").font(.headline).frame(maxWidth: .infinity)
                    Spacer()
                }
                Spacer(minLength: 0)
            }
            .glassWidget()
            .widgetURL(URL(string: "lmsstaffapp://applications"))
        }
    }
}

struct OldestPendingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "OldestPendingWidget", provider: SWProvider()) { OldestPendingView(entry: $0) }
            .configurationDisplayName("Oldest Pending")
            .description("The longest-waiting application in your queue.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct CopilotQuickAskView: View {
    private let prompts: [(String, String)] = [
        ("Summarize this borrower's risk", "shield"),
        ("Draft a rejection reason", "xmark.square"),
        ("What's pending my review?", "tray.full"),
        ("Suggest questions to ask", "questionmark.bubble")
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            swHeader("AI Copilot", "sparkles")
            ForEach(prompts, id: \.0) { text, icon in
                Link(destination: askURL(text)) {
                    HStack(spacing: 8) {
                        Image(systemName: icon).font(.caption2).frame(width: 15)
                        Text(text).font(.caption2.weight(.medium)).lineLimit(1)
                        Spacer(minLength: 4)
                        Image(systemName: "arrow.up.right").font(.system(size: 8)).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: Capsule())
                }
            }
        }
        .glassWidget()
    }
    private func askURL(_ q: String) -> URL {
        var c = URLComponents(); c.scheme = "lmsstaffapp"; c.host = "assistant"
        c.queryItems = [URLQueryItem(name: "q", value: q)]
        return c.url ?? URL(string: "lmsstaffapp://assistant")!
    }
}

struct CopilotQuickAskWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CopilotQuickAskWidget", provider: SWProvider()) { _ in CopilotQuickAskView() }
            .configurationDisplayName("AI Copilot")
            .description("One-tap prompts for your underwriting copilot.")
            .supportedFamilies([.systemMedium])
    }
}

// ============================================================================
// MANAGER (also serves Admin, which has portfolio data)
// ============================================================================

struct PortfolioPulseView: View {
    var entry: SWEntry
    var body: some View {
        let s = entry.snapshot
        if wrongRole(s, ["manager", "admin"]) { SignInHint(role: "manager") } else {
            VStack(alignment: .leading, spacing: 12) {
                swHeader("Portfolio Pulse", "chart.pie.fill")
                HStack(spacing: 12) {
                    metric("Active Loans", "\(s.activeLoans)", .primary)
                    metric("Disbursed", swInrCompact(s.totalDisbursed), .primary)
                }
                HStack(spacing: 12) {
                    metric("NPA", String(format: "%.1f%%", s.npaPercentage), s.npaPercentage > 5 ? .red : .orange)
                    metric("Collection", String(format: "%.0f%%", s.collectionEfficiency), s.collectionEfficiency >= 90 ? .green : .orange)
                }
                Spacer(minLength: 0)
                Text("\(s.pendingApprovals) approvals pending").font(.caption).foregroundStyle(.secondary)
            }
            .glassWidget()
            .widgetURL(URL(string: "lmsstaffapp://portfolio"))
        }
    }
    private func metric(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title3.weight(.bold)).foregroundStyle(color).minimumScaleFactor(0.6).lineLimit(1)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct PortfolioPulseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PortfolioPulseWidget", provider: SWProvider()) { PortfolioPulseView(entry: $0) }
            .configurationDisplayName("Portfolio Pulse")
            .description("Active loans, disbursed, NPA and collection efficiency.")
            .supportedFamilies([.systemLarge])
    }
}

struct PendingApprovalsView: View {
    var entry: SWEntry
    var body: some View {
        let s = entry.snapshot
        if wrongRole(s, ["manager", "admin"]) { SignInHint(role: "manager") } else {
            VStack(alignment: .leading, spacing: 6) {
                swHeader("Pending Approvals", "checkmark.circle")
                Text("\(s.pendingApprovals)").font(.system(size: 44, weight: .bold)).minimumScaleFactor(0.5)
                Text("awaiting your decision").font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .glassWidget()
            .widgetURL(URL(string: "lmsstaffapp://disbursements"))
        }
    }
}

struct PendingApprovalsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PendingApprovalsWidget", provider: SWProvider()) { PendingApprovalsView(entry: $0) }
            .configurationDisplayName("Pending Approvals")
            .description("Applications awaiting your approval.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct NPAAlertView: View {
    var entry: SWEntry
    var body: some View {
        let s = entry.snapshot
        if wrongRole(s, ["manager", "admin"]) { SignInHint(role: "manager") } else {
            VStack(alignment: .leading, spacing: 8) {
                swHeader("NPA & Overdue", "exclamationmark.triangle.fill")
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(s.npaCount)").font(.title.weight(.bold)).foregroundStyle(Color.red)
                        Text("NPA loans").font(.caption2).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(s.overdueEmis)").font(.title.weight(.bold)).foregroundStyle(Color.orange)
                        Text("overdue EMIs").font(.caption2).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                Text(String(format: "NPA %.1f%% of portfolio", s.npaPercentage))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .glassWidget()
            .widgetURL(URL(string: "lmsstaffapp://npa"))
        }
    }
}

struct NPAAlertWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NPAAlertWidget", provider: SWProvider()) { NPAAlertView(entry: $0) }
            .configurationDisplayName("NPA & Overdue")
            .description("Non-performing assets and overdue EMIs.")
            .supportedFamilies([.systemMedium])
    }
}

// ============================================================================
// ADMIN
// ============================================================================

struct SystemOverviewView: View {
    var entry: SWEntry
    var body: some View {
        let s = entry.snapshot
        if wrongRole(s, ["admin"]) { SignInHint(role: "admin") } else {
            VStack(alignment: .leading, spacing: 10) {
                swHeader("System Overview", "square.grid.2x2.fill")
                Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                    GridRow {
                        tile("Active Loans", "\(s.activeLoans)", "indianrupeesign.circle.fill")
                        tile("Borrowers", "\(s.totalBorrowers)", "person.2.fill")
                    }
                    GridRow {
                        tile("Staff", "\(s.staffCount)", "person.3.fill")
                        tile("Branches", "\(s.branchCount)", "building.2.fill")
                    }
                }
                Spacer(minLength: 0)
            }
            .glassWidget()
        }
    }
    private func tile(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(Color.swGreen)
            Text(value)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct SystemOverviewWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SystemOverviewWidget", provider: SWProvider()) { SystemOverviewView(entry: $0) }
            .configurationDisplayName("System Overview")
            .description("Loans, borrowers, staff and branches at a glance.")
            .supportedFamilies([.systemLarge])
    }
}

struct AuditTrailView: View {
    @Environment(\.widgetFamily) var family
    var entry: SWEntry
    var body: some View {
        let s = entry.snapshot
        if wrongRole(s, ["admin"]) { SignInHint(role: "admin") } else {
            VStack(alignment: .leading, spacing: 8) {
                swHeader("System Audit Trail", "clock.arrow.circlepath")
                let rows = Array(s.auditEntries.prefix(family == .systemLarge ? 5 : 3))
                if rows.isEmpty {
                    Spacer(minLength: 0)
                    Text("No recent activity")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                    Spacer(minLength: 0)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { idx, e in
                            auditRow(e)
                            if idx < rows.count - 1 {
                                Divider().overlay(Color.swGreen.opacity(0.12))
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .glassWidget()
            .widgetURL(URL(string: "lmsstaffapp://audit"))
        }
    }

    private func auditRow(_ e: StaffAuditEntryDTO) -> some View {
        HStack(spacing: 9) {
            Image(systemName: swAuditIcon(e.action))
                .font(.caption.weight(.semibold))
                .foregroundStyle(swAuditColor(e.action))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(swPrettyAction(e.action))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(e.actor)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Text(swRelative(e.date))
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 6)
    }
}

struct AuditTrailWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AuditAlertsWidget", provider: SWProvider()) { AuditTrailView(entry: $0) }
            .configurationDisplayName("System Audit Trail")
            .description("Most recent critical actions across the system.")
            .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - Audit formatting helpers

private func swPrettyAction(_ action: String) -> String {
    action.replacingOccurrences(of: "_", with: " ")
        .split(separator: " ")
        .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
        .joined(separator: " ")
}

private func swAuditIcon(_ action: String) -> String {
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
    if a.contains("SEND_BACK") || a.contains("SENT_BACK") { return "arrow.uturn.left.circle.fill" }
    return "doc.text.fill"
}

private func swAuditColor(_ action: String) -> Color {
    let a = action.uppercased()
    if a.contains("APPROVE") || a.contains("DISBURSE") || a.contains("CREATE") || a.contains("INSERT") { return .swGreen }
    if a.contains("DELETE") || a.contains("REJECT") { return .red }
    if a.contains("RESET") || a.contains("SEND_BACK") || a.contains("SENT_BACK") { return .orange }
    return .secondary
}

private func swRelative(_ date: Date) -> String {
    let secs = max(0, Date().timeIntervalSince(date))
    if secs < 60 { return "now" }
    if secs < 3_600 { return "\(Int(secs / 60))m" }
    if secs < 86_400 { return "\(Int(secs / 3_600))h" }
    return "\(Int(secs / 86_400))d"
}

// ============================================================================
// LOCK SCREEN (Officer pending gauge + Manager NPA gauge)
// ============================================================================

struct StaffLockView: View {
    @Environment(\.widgetFamily) var family
    var entry: SWEntry
    var body: some View {
        let s = entry.snapshot
        let isManager = s.role == "manager" || s.role == "admin"
        switch family {
        case .accessoryInline:
            Text(isManager ? "NPA \(String(format: "%.1f%%", s.npaPercentage)) · \(s.pendingApprovals) to approve"
                           : "\(s.officerPending) applications pending")
        case .accessoryCircular:
            Gauge(value: gauge(s, isManager)) {
                Image(systemName: isManager ? "chart.pie" : "tray.full")
            } currentValueLabel: {
                Text(isManager ? String(format: "%.0f", s.npaPercentage) : "\(s.officerPending)")
                    .font(.system(size: 13, weight: .bold))
            }
            .gaugeStyle(.accessoryCircular)
            .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        default:
            VStack(alignment: .leading, spacing: 1) {
                Text(isManager ? "Portfolio" : "My Queue").font(.caption2).foregroundStyle(.secondary)
                if isManager {
                    Text("NPA \(String(format: "%.1f%%", s.npaPercentage))").font(.headline)
                    Text("\(s.pendingApprovals) approvals pending").font(.caption2)
                } else {
                    Text("\(s.officerPending) pending").font(.headline)
                    Text("\(s.officerUnderReview) in review").font(.caption2)
                }
            }
            .containerBackground(for: .widget) { Color.clear }
        }
    }
    private func gauge(_ s: StaffWidgetSnapshotDTO, _ isManager: Bool) -> Double {
        if isManager { return min(max(s.npaPercentage / 15.0, 0), 1) }
        return min(max(Double(s.officerPending) / 20.0, 0), 1)
    }
}

struct StaffLockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StaffLockWidget", provider: SWProvider()) { StaffLockView(entry: $0) }
            .configurationDisplayName("Staff (Lock Screen)")
            .description("Your queue or portfolio on the lock screen.")
            .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Bundle

@main
struct StaffWidgetsBundle: WidgetBundle {
    var body: some Widget {
        OfficerQueueWidget()
        OldestPendingWidget()
        CopilotQuickAskWidget()
        PortfolioPulseWidget()
        PendingApprovalsWidget()
        NPAAlertWidget()
        SystemOverviewWidget()
        AuditTrailWidget()
        StaffLockWidget()
    }
}
