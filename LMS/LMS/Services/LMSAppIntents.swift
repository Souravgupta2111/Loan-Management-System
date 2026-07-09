//
//  LMSAppIntents.swift
//  LMS
//
//  Siri & Shortcuts automations for the borrower app.
//
//  Two kinds of intents live here:
//   1. "Open" intents (openAppWhenRun = true) that jump into a flow, routed via
//      IntentRouter.shared.
//   2. "Inline" intents (openAppWhenRun = false) that answer a question by
//      speaking a dialog WITHOUT foregrounding the app. They read the shared
//      App Group snapshot that WidgetDataProvider keeps up to date, so the
//      numbers match the home-screen widgets exactly.
//
//  Because the project uses Xcode file-system-synchronized groups, this file is
//  compiled into the LMS target automatically — no extension target required.
//

import AppIntents
import Foundation

// MARK: - Shared snapshot reader + formatting helpers

enum BorrowerSiri {

    /// Read the latest borrower snapshot the app published to the App Group.
    static func snapshot() -> WidgetSnapshotDTO? {
        guard let defaults = UserDefaults(suiteName: WidgetKeys.appGroupID),
              let data = defaults.data(forKey: WidgetKeys.snapshot),
              let snap = try? JSONDecoder().decode(WidgetSnapshotDTO.self, from: data)
        else { return nil }
        return snap
    }

    /// Dialog shown when there's no cached data yet (e.g. before first sign-in).
    static let noData = "I couldn't find your loan details yet. Open Loanz and sign in, then try again."

    // MARK: Currency

    private static let inrFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_IN")
        f.maximumFractionDigits = 0
        return f
    }()

    /// Full Indian-grouped rupee string, e.g. "₹2,24,382".
    static func inr(_ amount: Double) -> String {
        let n = NSNumber(value: amount.rounded())
        return "₹" + (inrFormatter.string(from: n) ?? String(Int(amount)))
    }

    /// Compact rupee string using lakh / crore, e.g. "₹12.4L", "₹4.85Cr".
    static func inrCompact(_ amount: Double) -> String {
        let a = abs(amount)
        if a >= 1_00_00_000 { return "₹" + trimmed(amount / 1_00_00_000) + "Cr" }
        if a >= 1_00_000 { return "₹" + trimmed(amount / 1_00_000) + "L" }
        return inr(amount)
    }

    private static func trimmed(_ value: Double) -> String {
        let s = String(format: "%.2f", value)
        // Drop trailing zeros / dot: 4.50 -> 4.5, 12.00 -> 12
        return s.replacingOccurrences(of: "\\.?0+$", with: "", options: .regularExpression)
    }

    // MARK: Dates

    /// "July 9th" style date.
    static func pretty(_ date: Date) -> String {
        let cal = Calendar.current
        let day = cal.component(.day, from: date)
        let monthIdx = cal.component(.month, from: date) - 1
        let month = DateFormatter().monthSymbols[safe: monthIdx] ?? ""
        return "\(month) \(day)\(ordinal(day))"
    }

    private static func ordinal(_ day: Int) -> String {
        if (11...13).contains(day % 100) { return "th" }
        switch day % 10 {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }

    // MARK: Credit score band

    static func creditBand(_ score: Int) -> String {
        switch score {
        case ..<580: return "poor"
        case 580..<670: return "fair"
        case 670..<740: return "good"
        case 740..<800: return "very good"
        default: return "excellent"
        }
    }

    /// The soonest-due active loan (prefers a future due date, else the earliest).
    static func nextDueLoan(_ snap: WidgetSnapshotDTO) -> WidgetLoanDTO? {
        let withDates = snap.loans.filter { $0.nextDue != nil }
        let now = Date()
        let upcoming = withDates.filter { ($0.nextDue ?? now) >= Calendar.current.startOfDay(for: now) }
        let pool = upcoming.isEmpty ? withDates : upcoming
        return pool.min { ($0.nextDue ?? .distantFuture) < ($1.nextDue ?? .distantFuture) }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Inline: Next EMI

struct NextEMIInlineIntent: AppIntent {
    static var title: LocalizedStringResource = "When Is My Next EMI"
    static var description = IntentDescription("Tells you your next EMI amount and due date.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let snap = BorrowerSiri.snapshot() else {
            return .result(dialog: IntentDialog(stringLiteral: BorrowerSiri.noData))
        }
        guard let loan = BorrowerSiri.nextDueLoan(snap), let due = loan.nextDue else {
            return .result(dialog: "You have no upcoming EMIs. You're all caught up.")
        }
        let dialog = "Your next EMI of \(BorrowerSiri.inr(loan.emiAmount)) is due on \(BorrowerSiri.pretty(due)) for your \(loan.name)."
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}

// MARK: - Inline: Total Outstanding

struct TotalOutstandingInlineIntent: AppIntent {
    static var title: LocalizedStringResource = "How Much Do I Owe"
    static var description = IntentDescription("Tells you your total outstanding balance.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let snap = BorrowerSiri.snapshot() else {
            return .result(dialog: IntentDialog(stringLiteral: BorrowerSiri.noData))
        }
        let total = snap.loans.reduce(0) { $0 + $1.outstanding }
        let count = snap.loans.count
        guard count > 0 else {
            return .result(dialog: "You have no active loans right now.")
        }
        let noun = count == 1 ? "active loan" : "active loans"
        let dialog = "Your total outstanding balance is \(BorrowerSiri.inr(total)) across \(count) \(noun)."
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}

// MARK: - Inline: Credit Score

struct CreditScoreInlineIntent: AppIntent {
    static var title: LocalizedStringResource = "What's My Credit Score"
    static var description = IntentDescription("Tells you your current credit score.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let snap = BorrowerSiri.snapshot() else {
            return .result(dialog: IntentDialog(stringLiteral: BorrowerSiri.noData))
        }
        guard let score = snap.creditScore else {
            return .result(dialog: "I don't have your credit score yet. Open Loanz to refresh it.")
        }
        let dialog = "Your credit score is \(score). That's considered \(BorrowerSiri.creditBand(score))."
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}

// MARK: - Inline: Loan Count

struct LoanCountInlineIntent: AppIntent {
    static var title: LocalizedStringResource = "How Many Loans Do I Have"
    static var description = IntentDescription("Tells you how many loans you have.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let snap = BorrowerSiri.snapshot() else {
            return .result(dialog: IntentDialog(stringLiteral: BorrowerSiri.noData))
        }
        let active = snap.loans.count
        let closed = snap.closedLoans ?? 0
        let total = active + closed
        guard total > 0 else {
            return .result(dialog: "You don't have any loans yet. You can apply right from Loanz.")
        }
        let totalNoun = total == 1 ? "loan" : "loans"
        let dialog = "You have \(total) \(totalNoun) — \(active) active and \(closed) closed."
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}

// MARK: - Inline: EMI This Month

struct EMIThisMonthInlineIntent: AppIntent {
    static var title: LocalizedStringResource = "What's My EMI This Month"
    static var description = IntentDescription("Tells you this month's EMI and repayment progress.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let snap = BorrowerSiri.snapshot() else {
            return .result(dialog: IntentDialog(stringLiteral: BorrowerSiri.noData))
        }
        guard let loan = BorrowerSiri.nextDueLoan(snap), let due = loan.nextDue else {
            return .result(dialog: "You have no EMI due this month.")
        }
        let percent = Int(loan.paidPercent.rounded())
        let dialog = "\(BorrowerSiri.inr(loan.emiAmount)) due \(BorrowerSiri.pretty(due)) for your \(loan.name). You've repaid \(percent)% so far."
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}

// MARK: - Inline: Loan Status

struct LoanStatusInlineIntent: AppIntent {
    static var title: LocalizedStringResource = "Show My Loan Status"
    static var description = IntentDescription("Summarizes your active loans and any application in progress.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let snap = BorrowerSiri.snapshot() else {
            return .result(dialog: IntentDialog(stringLiteral: BorrowerSiri.noData))
        }
        var parts: [String] = []
        for loan in snap.loans {
            parts.append("Your \(loan.name) is \(loan.status.lowercased()).")
        }
        if let stage = snap.applicationStage {
            let name = snap.applicationLoanName ?? "loan"
            parts.append("Your \(name) application is \(BorrowerSiri.humanStage(stage)).")
        }
        if parts.isEmpty {
            return .result(dialog: "You have no active loans or applications right now.")
        }
        return .result(dialog: IntentDialog(stringLiteral: parts.joined(separator: " ")))
    }
}

extension BorrowerSiri {
    /// Turn a raw application status into human words.
    static func humanStage(_ raw: String) -> String {
        switch raw.lowercased() {
        case "submitted": return "submitted"
        case "under_review": return "under review"
        case "sent_back": return "sent back for changes"
        case "approved": return "approved"
        case "pending_acceptance": return "awaiting your acceptance"
        case "pending_disbursal": return "pending disbursal"
        case "rejected": return "not approved"
        default: return raw.replacingOccurrences(of: "_", with: " ")
        }
    }
}

// MARK: - Inline: Eligibility

struct LoanEligibilityInlineIntent: AppIntent {
    static var title: LocalizedStringResource = "Am I Eligible for a Loan"
    static var description = IntentDescription("Gives a quick eligibility read based on your credit score.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let snap = BorrowerSiri.snapshot() else {
            return .result(dialog: IntentDialog(stringLiteral: BorrowerSiri.noData))
        }
        guard let score = snap.creditScore else {
            return .result(dialog: "I don't have your credit score yet, so I can't estimate eligibility. Open Loanz to check available products.")
        }
        let band = BorrowerSiri.creditBand(score)
        let outlook: String
        switch score {
        case 740...: outlook = "you're likely eligible for most loan products at competitive rates"
        case 670..<740: outlook = "you're eligible for many loan products"
        case 580..<670: outlook = "you may qualify for some products, though rates could be higher"
        default: outlook = "eligibility may be limited — improving your score would help"
        }
        let dialog = "Based on your credit score of \(score), which is \(band), \(outlook). Open Loanz to see the products you qualify for."
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}

// MARK: - Open: Apply for a Loan

struct ApplyForLoanIntent: AppIntent {
    static var title: LocalizedStringResource = "Apply for a Loan"
    static var description = IntentDescription("Opens the loan application flow.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        IntentRouter.shared.startLoanApplication()
        return .result(dialog: "Let's start your loan application.")
    }
}

// MARK: - Open AI Advisor

struct OpenAdvisorIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask Loan Advisor"
    static var description = IntentDescription(
        "Opens your AI Financial Advisor, optionally with a question."
    )

    // Foreground the app so the advisor UI can appear.
    static var openAppWhenRun: Bool = true

    @Parameter(
        title: "Question",
        description: "What you want to ask the advisor",
        requestValueDialog: "What would you like to ask your advisor?"
    )
    var question: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Ask the loan advisor \(\.$question)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = question?.trimmingCharacters(in: .whitespacesAndNewlines)
        IntentRouter.shared.openAdvisor(prefill: (trimmed?.isEmpty == false) ? trimmed : nil)
        return .result(dialog: "Opening your AI Financial Advisor.")
    }
}

// MARK: - Open EMI Schedule

struct CheckEMIScheduleIntent: AppIntent {
    static var title: LocalizedStringResource = "Check EMI Schedule"
    static var description = IntentDescription("Shows your upcoming EMI schedule.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        IntentRouter.shared.switchTab(.schedule)
        return .result(dialog: "Here's your EMI schedule.")
    }
}

// MARK: - Open Pay EMI

struct PayEMIIntent: AppIntent {
    static var title: LocalizedStringResource = "Pay My EMI"
    static var description = IntentDescription("Opens your loans so you can pay an EMI.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        IntentRouter.shared.switchTab(.loans)
        return .result(dialog: "Opening your loans so you can make a payment.")
    }
}

// MARK: - Open Advisor for Credit-Score Improvement

struct ImproveCreditScoreIntent: AppIntent {
    static var title: LocalizedStringResource = "How to Improve My Credit Score"
    static var description = IntentDescription(
        "Asks your AI advisor how to improve your credit score."
    )
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        IntentRouter.shared.openAdvisor(
            prefill: "How can I improve my credit score?"
        )
        return .result(dialog: "Let me pull up tips to improve your credit score.")
    }
}

// MARK: - App Shortcuts (spoken phrases)

struct LMSAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // --- Inline answers (no app open) ---
        AppShortcut(
            intent: NextEMIInlineIntent(),
            phrases: [
                "When is my next EMI in \(.applicationName)",
                "When's my next EMI in \(.applicationName)"
            ],
            shortTitle: "Next EMI",
            systemImageName: "calendar.badge.clock"
        )
        AppShortcut(
            intent: TotalOutstandingInlineIntent(),
            phrases: [
                "How much do I owe in \(.applicationName)",
                "What's my outstanding balance in \(.applicationName)"
            ],
            shortTitle: "Amount Owed",
            systemImageName: "indianrupeesign.circle"
        )
        AppShortcut(
            intent: CreditScoreInlineIntent(),
            phrases: [
                "What's my credit score in \(.applicationName)",
                "Check my credit score in \(.applicationName)"
            ],
            shortTitle: "Credit Score",
            systemImageName: "chart.bar.fill"
        )
        AppShortcut(
            intent: LoanCountInlineIntent(),
            phrases: [
                "How many loans do I have in \(.applicationName)",
                "How many loans in \(.applicationName)"
            ],
            shortTitle: "Loan Count",
            systemImageName: "number.circle"
        )
        AppShortcut(
            intent: EMIThisMonthInlineIntent(),
            phrases: [
                "What's my EMI this month in \(.applicationName)",
                "What is my EMI this month in \(.applicationName)"
            ],
            shortTitle: "EMI This Month",
            systemImageName: "calendar"
        )
        AppShortcut(
            intent: LoanStatusInlineIntent(),
            phrases: [
                "Show my loan status in \(.applicationName)",
                "What's my loan status in \(.applicationName)"
            ],
            shortTitle: "Loan Status",
            systemImageName: "list.bullet.rectangle"
        )
        AppShortcut(
            intent: LoanEligibilityInlineIntent(),
            phrases: [
                "Am I eligible for a loan in \(.applicationName)",
                "Am I eligible for a home loan in \(.applicationName)"
            ],
            shortTitle: "Eligibility",
            systemImageName: "checkmark.seal"
        )

        // --- Actions that open the app ---
        AppShortcut(
            intent: ApplyForLoanIntent(),
            phrases: [
                "Apply for a loan in \(.applicationName)",
                "Start a loan application in \(.applicationName)"
            ],
            shortTitle: "Apply for a Loan",
            systemImageName: "square.and.pencil"
        )
        AppShortcut(
            intent: OpenAdvisorIntent(),
            phrases: [
                "Ask my loan advisor in \(.applicationName)",
                "Open my loan advisor in \(.applicationName)",
                "Talk to \(.applicationName) advisor"
            ],
            shortTitle: "Ask Advisor",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: PayEMIIntent(),
            phrases: [
                "Pay my EMI in \(.applicationName)",
                "Make a loan payment in \(.applicationName)"
            ],
            shortTitle: "Pay EMI",
            systemImageName: "creditcard"
        )
        // Note: Apple limits AppShortcutsProvider to 10 entries. CheckEMISchedule
        // and ImproveCreditScore intents remain available in the Shortcuts app.
    }
}
