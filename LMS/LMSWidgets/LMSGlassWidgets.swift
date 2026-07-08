//
//  LMSGlassWidgets.swift
//  LMSWidgets (Widget Extension)
//
//  Borrower home-screen + lock-screen widgets. Neutral liquid glass (adaptive
//  light/dark), no brand-green theming. Reads the snapshot the app publishes to
//  the shared App Group. No @main here — LMSWidgetsBundle owns the entry point.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Shared keys + DTOs (mirror WidgetKeys / DTOs in the app)

enum LMSKeys {
    static let appGroupID = "group.com.sourav.hi123.LMS"
    static let snapshot = "widget.snapshot"
    static let calcAmount = "widget.calc.amount"
    static let calcTenure = "widget.calc.tenure"
    static let loanIndex = "widget.loanIndex"

    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }
}

struct WidgetLoanDTO: Codable {
    var id: String = ""       // loan UUID (for deep-linking to its payment page)
    var name: String
    var loanType: String
    var outstanding: Double
    var emiAmount: Double
    var nextDue: Date?
    var paidPercent: Double
    var status: String
}

struct WidgetEMIDayDTO: Codable {
    var date: Date
    var status: String
}

struct WidgetSnapshotDTO: Codable {
    var loans: [WidgetLoanDTO]
    var creditScore: Int?
    var applicationStage: String?
    var applicationLoanName: String?
    var applicationUpdated: Date?
    var calendar: [WidgetEMIDayDTO]
    var generated: Date

    static let sample = WidgetSnapshotDTO(
        loans: [
            WidgetLoanDTO(name: "Home Loan", loanType: "home", outstanding: 845_000, emiAmount: 12_500,
                          nextDue: Calendar.current.date(byAdding: .day, value: 4, to: .now), paidPercent: 0.42, status: "active"),
            WidgetLoanDTO(name: "Vehicle Loan", loanType: "vehicle", outstanding: 210_000, emiAmount: 8_200,
                          nextDue: Calendar.current.date(byAdding: .day, value: 12, to: .now), paidPercent: 0.66, status: "active"),
            WidgetLoanDTO(name: "Personal Loan", loanType: "personal", outstanding: 96_000, emiAmount: 5_400,
                          nextDue: Calendar.current.date(byAdding: .day, value: 20, to: .now), paidPercent: 0.8, status: "active")
        ],
        creditScore: 762,
        applicationStage: "under_review",
        applicationLoanName: "Home Loan",
        applicationUpdated: .now,
        calendar: (0..<6).map { WidgetEMIDayDTO(date: Calendar.current.date(byAdding: .month, value: $0 - 2, to: .now)!, status: $0 < 2 ? "paid" : "upcoming") },
        generated: .now
    )

    static func load() -> WidgetSnapshotDTO {
        guard let d = LMSKeys.defaults,
              let data = d.data(forKey: LMSKeys.snapshot),
              let snap = try? JSONDecoder().decode(WidgetSnapshotDTO.self, from: data)
        else { return sample }
        return snap
    }
}

// MARK: - Formatting

func inr(_ value: Double) -> String {
    let f = NumberFormatter(); f.numberStyle = .decimal; f.maximumFractionDigits = 0
    f.locale = Locale(identifier: "en_IN")
    return "₹" + (f.string(from: NSNumber(value: value)) ?? "\(Int(value))")
}

func inrCompact(_ v: Double) -> String {
    if v >= 10_000_000 { return String(format: "₹%.1fCr", v / 10_000_000) }
    if v >= 100_000 { return String(format: "₹%.1fL", v / 100_000) }
    if v >= 1_000 { return String(format: "₹%.0fK", v / 1_000) }
    return "₹\(Int(v))"
}

private func daysUntil(_ date: Date?) -> Int? {
    guard let date else { return nil }
    return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now),
                                           to: Calendar.current.startOfDay(for: date)).day
}

private func dueText(_ date: Date?) -> String {
    guard let d = daysUntil(date) else { return "As scheduled" }
    if d < 0 { return "Overdue" }
    if d == 0 { return "Due today" }
    if d == 1 { return "Due tomorrow" }
    return "Due in \(d) days"
}

private func statusColor(_ status: String) -> Color {
    switch status.lowercased() {
    case "paid": return .green
    case "overdue": return .red
    case "due": return .orange
    default: return .secondary
    }
}

// MARK: - Glass backgrounds (neutral / dark)

/// Liquid glass — frosted material with a soft sheen and a hairline rim so it
/// reads as a real glass card. Adapts to the system appearance: light glass in
/// light mode, dark glass in dark mode. Text uses `.primary`/`.secondary`, which
/// invert automatically for legibility on either.
// App theme greens (mirrors the borrower app's background palette).
extension Color {
    static let lmsSage      = Color(.sRGB, red: 0.906, green: 0.937, blue: 0.898, opacity: 1) // #E7EFE5
    static let lmsMint      = Color(.sRGB, red: 0.784, green: 0.902, blue: 0.816, opacity: 1) // #C8E6D0
    static let lmsGreen     = Color(.sRGB, red: 0.176, green: 0.545, blue: 0.306, opacity: 1) // #2D8B4E
    static let lmsDarkGreen = Color(.sRGB, red: 0.106, green: 0.216, blue: 0.153, opacity: 1) // deep green
}

/// Green liquid glass — frosted `.ultraThinMaterial` tinted with the borrower
/// app's sage/mint background so it reads as the app's own green glass, with a
/// green hairline rim. Stays translucent (glass) in both light and dark.
struct LiquidGlassBG: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay {
                if scheme == .dark {
                    LinearGradient(colors: [Color.lmsDarkGreen.opacity(0.62), Color.lmsDarkGreen.opacity(0.38)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                } else {
                    LinearGradient(colors: [Color.lmsSage.opacity(0.75), Color.lmsMint.opacity(0.58)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            .overlay(
                ContainerRelativeShape()
                    .strokeBorder(Color.lmsGreen.opacity(scheme == .dark ? 0.40 : 0.28), lineWidth: 2)
            )
    }
}

extension View {
    /// Standard glass widget container: consistent inner padding + fill + glass bg.
    /// Use instead of hand-writing `.frame(...).containerBackground(...)`.
    func glassWidget(_ alignment: Alignment = .topLeading) -> some View {
        self
            .padding(.horizontal, 20)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .containerBackground(for: .widget) { LiquidGlassBG() }
    }
}

// MARK: - Interactive App Intents (run in-place, no app launch)

struct CalcAdjustIntent: AppIntent {
    static var title: LocalizedStringResource = "Adjust loan calculator"

    @Parameter(title: "Field") var field: String
    @Parameter(title: "Direction") var direction: Int

    init() {}
    init(field: String, direction: Int) { self.field = field; self.direction = direction }

    func perform() async throws -> some IntentResult {
        guard let d = LMSKeys.defaults else { return .result() }
        if field == "amount" {
            let cur = d.object(forKey: LMSKeys.calcAmount) as? Double ?? 500_000
            let next = min(max(cur + Double(direction) * 50_000, 50_000), 10_000_000)
            d.set(next, forKey: LMSKeys.calcAmount)
        } else {
            let cur = d.object(forKey: LMSKeys.calcTenure) as? Int ?? 24
            let next = min(max(cur + direction * 6, 6), 360)
            d.set(next, forKey: LMSKeys.calcTenure)
        }
        return .result()
    }
}

struct CycleLoanIntent: AppIntent {
    static var title: LocalizedStringResource = "Show next loan"
    @Parameter(title: "Count") var count: Int

    init() {}
    init(count: Int) { self.count = count }

    func perform() async throws -> some IntentResult {
        guard let d = LMSKeys.defaults, count > 0 else { return .result() }
        let cur = d.integer(forKey: LMSKeys.loanIndex)
        d.set((cur + 1) % count, forKey: LMSKeys.loanIndex)
        return .result()
    }
}

// MARK: - Timeline

struct LMSEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshotDTO
    let calcAmount: Double
    let calcTenure: Int
    let loanIndex: Int
}

struct LMSProvider: TimelineProvider {
    private func currentEntry(preview: Bool) -> LMSEntry {
        let d = LMSKeys.defaults
        return LMSEntry(
            date: .now,
            snapshot: preview ? .sample : .load(),
            calcAmount: d?.object(forKey: LMSKeys.calcAmount) as? Double ?? 500_000,
            calcTenure: d?.object(forKey: LMSKeys.calcTenure) as? Int ?? 24,
            loanIndex: d?.integer(forKey: LMSKeys.loanIndex) ?? 0
        )
    }

    func placeholder(in context: Context) -> LMSEntry { currentEntry(preview: true) }
    func getSnapshot(in context: Context, completion: @escaping (LMSEntry) -> Void) {
        completion(currentEntry(preview: context.isPreview))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<LMSEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .hour, value: 2, to: .now) ?? .now
        completion(Timeline(entries: [currentEntry(preview: false)], policy: .after(next)))
    }
}

private extension WidgetSnapshotDTO {
    var nextEMILoan: WidgetLoanDTO? {
        loans.filter { $0.nextDue != nil }.min { ($0.nextDue ?? .distantFuture) < ($1.nextDue ?? .distantFuture) }
    }
    var totalOutstanding: Double { loans.reduce(0) { $0 + $1.outstanding } }
}

// MARK: - Next EMI (small + medium, interactive Pay)

struct NextEMIView: View {
    @Environment(\.widgetFamily) var family
    var entry: LMSEntry

    var body: some View {
        let loan = entry.snapshot.nextEMILoan
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Next EMI", systemImage: "calendar")
                    .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                if let loan, let d = daysUntil(loan.nextDue) {
                    Text(d < 0 ? "Overdue" : "\(max(d,0))d")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(d < 0 ? Color.red : (d <= 3 ? Color.orange : Color.secondary))
                }
            }

            if let loan {
                HStack(alignment: .firstTextBaseline) {
                    Text(inr(loan.emiAmount)).font(.title2.weight(.bold)).minimumScaleFactor(0.6).lineLimit(1)
                    Spacer()
                    Text(dueText(loan.nextDue)).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                }
                Text(loan.name).font(.caption2).foregroundStyle(.secondary).lineLimit(1)

                if family == .systemMedium {
                    Spacer(minLength: 8)
                    Link(destination: payURL(loan)) {
                        Text("Pay Now")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.lmsGreen)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(.thinMaterial, in: Capsule())
                            .overlay(Capsule().stroke(Color.lmsGreen.opacity(0.35), lineWidth: 2))
                    }
                    .padding(.bottom, 6)
                } else {
                    Spacer(minLength: 0)
                }
            } else {
                Text("No EMIs due").font(.headline)
                Text("You're all caught up").font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
        .glassWidget()
        .widgetURL(URL(string: "lmsapp://emi"))
    }

    private func payURL(_ loan: WidgetLoanDTO) -> URL {
        guard !loan.id.isEmpty else { return URL(string: "lmsapp://pay")! }
        var c = URLComponents(); c.scheme = "lmsapp"; c.host = "pay"
        c.queryItems = [URLQueryItem(name: "loanId", value: loan.id)]
        return c.url ?? URL(string: "lmsapp://pay")!
    }
}

struct NextEMIWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextEMIWidget", provider: LMSProvider()) { NextEMIView(entry: $0) }
            .configurationDisplayName("Next EMI")
            .description("Your upcoming EMI, with a quick Pay action.")
            .supportedFamilies([.systemSmall, .systemMedium])
            .contentMarginsDisabled()
    }
}

// MARK: - Loan Summary (large, up to 3 loans + cycle)

struct LoanSummaryView: View {
    var entry: LMSEntry
    var body: some View {
        let loans = entry.snapshot.loans
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Loan Summary", systemImage: "indianrupeesign.circle")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Text("Total \(inrCompact(entry.snapshot.totalOutstanding))")
                    .font(.caption.weight(.bold)).foregroundStyle(.secondary)
            }

            if loans.isEmpty {
                Spacer()
                Text("No active loans").font(.headline).frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(Array(loans.prefix(3).enumerated()), id: \.offset) { _, loan in
                    loanRow(loan)
                }
                Spacer(minLength: 0)
                if loans.count > 3 {
                    Text("+\(loans.count - 3) more").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .glassWidget()
        .widgetURL(URL(string: "lmsapp://loans"))
    }

    private func loanRow(_ loan: WidgetLoanDTO) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: iconFor(loan.loanType)).font(.caption).foregroundStyle(.secondary)
                Text(loan.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                Spacer()
                Text(inrCompact(loan.outstanding)).font(.subheadline.weight(.bold))
            }
            ProgressView(value: min(max(loan.paidPercent, 0), 1))
                .tint(Color.primary.opacity(0.7))
            HStack {
                Text("\(Int(loan.paidPercent * 100))% repaid").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                if loan.nextDue != nil {
                    Text("EMI \(inrCompact(loan.emiAmount)) · \(dueText(loan.nextDue))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func iconFor(_ type: String) -> String {
        switch type.lowercased() {
        case "home": return "house.fill"
        case "vehicle": return "car.fill"
        case "business": return "briefcase.fill"
        case "education": return "graduationcap.fill"
        case "personal": return "person.fill"
        case "gold": return "gift.fill"
        case "agriculture": return "leaf.fill"
        default: return "indianrupeesign.circle.fill"
        }
    }
}

struct LoanSummaryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LoanSummaryWidget", provider: LMSProvider()) { LoanSummaryView(entry: $0) }
            .configurationDisplayName("Loan Summary")
            .description("All your active loans and balances at a glance.")
            .supportedFamilies([.systemLarge])
    }
}

// MARK: - EMI Calendar (large)

struct EMICalendarView: View {
    var entry: LMSEntry
    private let cols = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.year, .month], from: now)
        let firstOfMonth = cal.date(from: comps)!
        let range = cal.range(of: .day, in: .month, for: firstOfMonth)!
        let leading = (cal.component(.weekday, from: firstOfMonth) - cal.firstWeekday + 7) % 7

        // Map day-of-month -> status for the visible month.
        var statusByDay: [Int: String] = [:]
        for e in entry.snapshot.calendar where cal.isDate(e.date, equalTo: firstOfMonth, toGranularity: .month) {
            statusByDay[cal.component(.day, from: e.date)] = e.status
        }

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(monthTitle(now), systemImage: "calendar")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                legendDot(.green, "Paid"); legendDot(.orange, "Due"); legendDot(.red, "Late")
            }
            LazyVGrid(columns: cols, spacing: 4) {
                ForEach(Array(["S","M","T","W","T","F","S"].enumerated()), id: \.offset) { _, d in
                    Text(d).font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
                }
                ForEach(0..<leading, id: \.self) { _ in Color.clear.frame(height: 20) }
                ForEach(1...range.count, id: \.self) { day in
                    dayCell(day: day, status: statusByDay[day], isToday: cal.component(.day, from: now) == day)
                }
            }
            Spacer(minLength: 0)
        }
        .glassWidget()
        .widgetURL(URL(string: "lmsapp://emi"))
    }

    private func dayCell(day: Int, status: String?, isToday: Bool) -> some View {
        let color = status.map { statusColor($0) }
        return Text("\(day)")
            .font(.system(size: 11, weight: isToday ? .bold : .regular))
            .frame(maxWidth: .infinity, minHeight: 20)
            .background {
                if let color {
                    Circle().fill(color.opacity(0.9)).frame(width: 22, height: 22)
                } else if isToday {
                    Circle().stroke(Color.primary.opacity(0.4)).frame(width: 22, height: 22)
                }
            }
            .foregroundStyle(color != nil ? Color.white : Color.primary)
    }

    private func legendDot(_ c: Color, _ label: String) -> some View {
        HStack(spacing: 2) {
            Circle().fill(c).frame(width: 6, height: 6)
            Text(label).font(.system(size: 8)).foregroundStyle(.secondary)
        }
    }

    private func monthTitle(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f.string(from: d)
    }
}

struct EMICalendarWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "EMICalendarWidget", provider: LMSProvider()) { EMICalendarView(entry: $0) }
            .configurationDisplayName("EMI Calendar")
            .description("This month's EMIs — paid, due and overdue.")
            .supportedFamilies([.systemLarge])
    }
}

// MARK: - Application Tracker (medium)

struct ApplicationTrackerView: View {
    var entry: LMSEntry
    private let stages = ["Applied", "Review", "Approved", "Disbursed"]

    private var currentIndex: Int {
        switch (entry.snapshot.applicationStage ?? "").lowercased() {
        case "submitted", "sent_back": return 1
        case "under_review": return 1
        case "approved", "pending_acceptance", "pending_disbursal": return 2
        case "disbursed", "active": return 3
        default: return 0
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Application", systemImage: "doc.text.magnifyingglass")
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)

            if entry.snapshot.applicationStage == nil {
                Spacer()
                Text("No application in progress").font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                Text(entry.snapshot.applicationLoanName ?? "Your application")
                    .font(.headline).lineLimit(1)
                HStack(spacing: 0) {
                    ForEach(Array(stages.enumerated()), id: \.offset) { i, name in
                        VStack(spacing: 4) {
                            ZStack {
                                Circle().fill(i <= currentIndex ? Color.primary : Color.secondary.opacity(0.3))
                                    .frame(width: 18, height: 18)
                                if i < currentIndex {
                                    Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(Color(.systemBackground))
                                }
                            }
                            Text(name).font(.system(size: 8)).foregroundStyle(i <= currentIndex ? Color.primary : Color.secondary)
                        }
                        if i < stages.count - 1 {
                            Rectangle().fill(i < currentIndex ? Color.primary : Color.secondary.opacity(0.3))
                                .frame(height: 2).frame(maxWidth: .infinity).offset(y: -6)
                        }
                    }
                }
                if let updated = entry.snapshot.applicationUpdated {
                    Text("Updated \(updated.formatted(.dateTime.day().month(.abbreviated)))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .glassWidget()
        .widgetURL(URL(string: "lmsapp://loans"))
    }
}

struct ApplicationTrackerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ApplicationTrackerWidget", provider: LMSProvider()) { ApplicationTrackerView(entry: $0) }
            .configurationDisplayName("Application Tracker")
            .description("Track your loan application through each stage.")
            .supportedFamilies([.systemMedium])
    }
}

// MARK: - AI Quick-Ask (medium)

struct AIQuickAskView: View {
    private let prompts: [(String, String)] = [
        ("When is my next EMI?", "calendar"),
        ("Am I eligible for a loan?", "checkmark.seal"),
        ("How to improve my score?", "chart.line.uptrend.xyaxis"),
        ("Explain my application status", "questionmark.circle")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Ask your advisor", systemImage: "sparkles")
                .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(prompts, id: \.0) { text, icon in
                Link(destination: advisorURL(text)) {
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

    private func advisorURL(_ q: String) -> URL {
        var c = URLComponents(); c.scheme = "lmsapp"; c.host = "advisor"
        c.queryItems = [URLQueryItem(name: "q", value: q)]
        return c.url ?? URL(string: "lmsapp://advisor")!
    }
}

struct AIQuickAskWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AIQuickAskWidget", provider: LMSProvider()) { _ in AIQuickAskView() }
            .configurationDisplayName("Ask AI Advisor")
            .description("One-tap questions for your AI financial advisor.")
            .supportedFamilies([.systemMedium])
    }
}

// MARK: - Credit Score (small)

struct CreditScoreView: View {
    var entry: LMSEntry
    var body: some View {
        let score = entry.snapshot.creditScore
        let fraction = score.map { Double($0 - 300) / 600.0 } ?? 0
        VStack(spacing: 6) {
            Label("Credit Score", systemImage: "chart.bar.fill")
                .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            ZStack {
                Circle().stroke(.secondary.opacity(0.25), lineWidth: 8)
                Circle().trim(from: 0, to: min(max(fraction, 0), 1))
                    .stroke(scoreColor(score), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(score.map { "\($0)" } ?? "—").font(.title2.weight(.bold))
                    Text(band(score)).font(.system(size: 8)).foregroundStyle(.secondary)
                }
            }
            .frame(width: 74, height: 74)
        }
        .glassWidget(.center)
        .widgetURL(URL(string: "lmsapp://advisor?q=How%20can%20I%20improve%20my%20credit%20score%3F"))
    }

    private func scoreColor(_ s: Int?) -> Color {
        guard let s else { return .secondary }
        if s >= 750 { return .green }
        if s >= 650 { return .orange }
        return .red
    }
    private func band(_ s: Int?) -> String {
        guard let s else { return "No data" }
        if s >= 750 { return "Excellent" }
        if s >= 650 { return "Good" }
        return "Needs work"
    }
}

struct CreditScoreWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CreditScoreWidget", provider: LMSProvider()) { CreditScoreView(entry: $0) }
            .configurationDisplayName("Credit Score")
            .description("Your latest credit score.")
            .supportedFamilies([.systemSmall])
    }
}

// MARK: - Loan Calculator (medium, interactive steppers)

struct LoanCalculatorView: View {
    var entry: LMSEntry
    private let rate = 10.5 // annual %, illustrative

    private var emi: Double {
        let p = entry.calcAmount, n = Double(entry.calcTenure), r = rate / 12 / 100
        guard r > 0, n > 0 else { return p / max(n, 1) }
        return (p * r * pow(1 + r, n)) / (pow(1 + r, n) - 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("EMI Calculator", systemImage: "plus.forwardslash.minus")
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)

            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Monthly EMI").font(.caption2).foregroundStyle(.secondary)
                    Text(inr(emi.rounded())).font(.title3.weight(.bold)).minimumScaleFactor(0.6).lineLimit(1)
                }
                Spacer()
                Text("@ \(rate, specifier: "%.1f")%").font(.caption2).foregroundStyle(.secondary)
            }

            stepperRow(label: "Amount", value: inrCompact(entry.calcAmount), field: "amount")
            stepperRow(label: "Tenure", value: "\(entry.calcTenure) mo", field: "tenure")
            Spacer(minLength: 0)
        }
        .glassWidget()
    }

    private func stepperRow(label: String, value: String, field: String) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.caption.weight(.medium)).foregroundStyle(.secondary).frame(width: 56, alignment: .leading)
            Button(intent: CalcAdjustIntent(field: field, direction: -1)) {
                Image(systemName: "minus").font(.caption.weight(.bold)).frame(width: 26, height: 26)
                    .background(.thinMaterial, in: Circle())
            }.buttonStyle(.plain)
            Text(value).font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity)
            Button(intent: CalcAdjustIntent(field: field, direction: 1)) {
                Image(systemName: "plus").font(.caption.weight(.bold)).frame(width: 26, height: 26)
                    .background(.thinMaterial, in: Circle())
            }.buttonStyle(.plain)
        }
    }
}

struct LoanCalculatorWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LoanCalculatorWidget", provider: LMSProvider()) { LoanCalculatorView(entry: $0) }
            .configurationDisplayName("EMI Calculator")
            .description("Estimate an EMI right from your home screen.")
            .supportedFamilies([.systemMedium])
    }
}

// MARK: - Lock Screen accessory trio

struct EMILockView: View {
    @Environment(\.widgetFamily) var family
    var entry: LMSEntry

    var body: some View {
        let loan = entry.snapshot.nextEMILoan
        let days = daysUntil(loan?.nextDue)
        switch family {
        case .accessoryInline:
            Text(loan != nil ? "EMI \(inrCompact(loan!.emiAmount)) · \(dueText(loan?.nextDue))" : "No EMI due")
        case .accessoryCircular:
            Gauge(value: gaugeValue(days)) {
                Image(systemName: "indianrupeesign")
            } currentValueLabel: {
                Text(days.map { "\(max($0, 0))d" } ?? "—").font(.system(size: 12, weight: .bold))
            }
            .gaugeStyle(.accessoryCircular)
            .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        default: // accessoryRectangular
            VStack(alignment: .leading, spacing: 1) {
                Text("Next EMI").font(.caption2).foregroundStyle(.secondary)
                if let loan {
                    Text(inr(loan.emiAmount)).font(.headline)
                    Text(dueText(loan.nextDue)).font(.caption2)
                } else {
                    Text("All caught up").font(.headline)
                }
            }
            .containerBackground(for: .widget) { Color.clear }
        }
    }

    private func gaugeValue(_ days: Int?) -> Double {
        guard let days else { return 0 }
        // Fuller as the due date approaches (0 days = full).
        return min(max(1 - Double(days) / 30.0, 0), 1)
    }
}

struct EMILockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "EMILockWidget", provider: LMSProvider()) { EMILockView(entry: $0) }
            .configurationDisplayName("Next EMI (Lock Screen)")
            .description("Your next EMI on the lock screen.")
            .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}
