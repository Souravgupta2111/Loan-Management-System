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
    var generated: Date

    static let sample = StaffWidgetSnapshotDTO(
        role: "manager", officerPending: 7, officerSubmitted: 4, officerUnderReview: 3,
        oldestName: "Ravi Kumar", oldestDays: 3, activeLoans: 128, totalDisbursed: 48_500_000,
        npaPercentage: 4.2, collectionEfficiency: 92, pendingApprovals: 9, overdueEmis: 15,
        npaCount: 6, totalBorrowers: 342, staffCount: 18, branchCount: 5, auditAlerts24h: 23,
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

// MARK: - Glass background (neutral, adaptive)

struct StaffGlassBG: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay {
                if scheme == .dark {
                    LinearGradient(colors: [Color.black.opacity(0.38), Color.black.opacity(0.16)],
                                   startPoint: .top, endPoint: .bottom)
                } else {
                    LinearGradient(colors: [Color.white.opacity(0.40), Color.white.opacity(0.08)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            .overlay(
                ContainerRelativeShape()
                    .strokeBorder(Color.primary.opacity(scheme == .dark ? 0.18 : 0.12), lineWidth: 1)
            )
    }
}

extension View {
    /// Standard glass widget container: consistent inner padding + fill + glass bg.
    func glassWidget(_ alignment: Alignment = .topLeading) -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .padding(14)
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
    !allowed.contains(snap.role)
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
            VStack(alignment: .leading, spacing: 12) {
                swHeader("System Overview", "square.grid.2x2.fill")
                HStack(spacing: 12) {
                    tile("Active Loans", "\(s.activeLoans)", "indianrupeesign.circle")
                    tile("Borrowers", "\(s.totalBorrowers)", "person.2.fill")
                }
                HStack(spacing: 12) {
                    tile("Staff", "\(s.staffCount)", "person.3.fill")
                    tile("Branches", "\(s.branchCount)", "building.2.fill")
                }
                Spacer(minLength: 0)
            }
            .glassWidget()
        }
    }
    private func tile(_ title: String, _ value: String, _ icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.title3).foregroundStyle(.secondary).frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.title3.weight(.bold)).minimumScaleFactor(0.6).lineLimit(1)
                Text(title).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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

struct AuditAlertsView: View {
    var entry: SWEntry
    var body: some View {
        let s = entry.snapshot
        if wrongRole(s, ["admin"]) { SignInHint(role: "admin") } else {
            VStack(alignment: .leading, spacing: 6) {
                swHeader("Audit Activity", "clock.arrow.circlepath")
                Text("\(s.auditAlerts24h)").font(.system(size: 40, weight: .bold)).minimumScaleFactor(0.5)
                Text("critical actions · 24h").font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .glassWidget()
        }
    }
}

struct AuditAlertsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AuditAlertsWidget", provider: SWProvider()) { AuditAlertsView(entry: $0) }
            .configurationDisplayName("Audit Activity")
            .description("Critical actions logged in the last 24 hours.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
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
        AuditAlertsWidget()
        StaffLockWidget()
    }
}
