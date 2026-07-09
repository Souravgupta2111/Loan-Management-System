//
//  StaffAppIntents.swift
//  LMS Staff
//
//  Siri & Shortcuts automations for the staff portal (officers & managers).
//
//  Two kinds of intents live here:
//   1. "Open" intents (openAppWhenRun = true) that jump into a screen, routed
//      through StaffIntentRouter, which StaffTabRouter observes.
//   2. "Inline" intents (openAppWhenRun = false) that answer a question by
//      speaking a dialog WITHOUT foregrounding the app. They read the shared
//      App Group snapshot that StaffWidgetDataProvider keeps up to date, so the
//      numbers match the staff widgets exactly.
//
//  App Intents compile into the main target automatically (the project uses
//  Xcode file-system-synchronized groups).
//

import AppIntents
import Foundation

// MARK: - Shared snapshot reader + formatting helpers

enum StaffSiri {

    /// Read the latest staff snapshot the app published to the App Group.
    static func snapshot() -> StaffWidgetSnapshotDTO? {
        guard let defaults = UserDefaults(suiteName: StaffWidgetKeys.appGroupID),
              let data = defaults.data(forKey: StaffWidgetKeys.snapshot),
              let snap = try? JSONDecoder().decode(StaffWidgetSnapshotDTO.self, from: data)
        else { return nil }
        // A cleared/logged-out snapshot uses role "none".
        return snap.role == "none" ? nil : snap
    }

    static let noData = "I couldn't find your portal data yet. Open Loanz Enterprise and sign in, then try again."

    static let notForRole = "That metric is available on a manager or admin account."

    /// Whether portfolio-wide metrics (NPA, collection, overdue) apply to this role.
    static func isPortfolioRole(_ snap: StaffWidgetSnapshotDTO) -> Bool {
        snap.role == "manager" || snap.role == "admin"
    }

    // MARK: Currency

    /// Compact rupee string using lakh / crore, e.g. "₹12.4L", "₹4.85Cr".
    static func inrCompact(_ amount: Double) -> String {
        let a = abs(amount)
        if a >= 1_00_00_000 { return "₹" + trimmed(amount / 1_00_00_000) + "Cr" }
        if a >= 1_00_000 { return "₹" + trimmed(amount / 1_00_000) + "L" }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_IN")
        f.maximumFractionDigits = 0
        return "₹" + (f.string(from: NSNumber(value: amount.rounded())) ?? String(Int(amount)))
    }

    private static func trimmed(_ value: Double) -> String {
        let s = String(format: "%.2f", value)
        return s.replacingOccurrences(of: "\\.?0+$", with: "", options: .regularExpression)
    }

    /// Format a percentage without trailing ".0" (92.0 -> "92", 92.3 -> "92.3").
    static func pct(_ value: Double) -> String {
        let s = String(format: "%.1f", value)
        return s.replacingOccurrences(of: "\\.0$", with: "", options: .regularExpression)
    }
}

// MARK: - Inline: Pending Applications

struct PendingApplicationsCountIntent: AppIntent {
    static var title: LocalizedStringResource = "How Many Pending Applications"
    static var description = IntentDescription("Tells you how many applications await review.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let snap = StaffSiri.snapshot() else {
            return .result(dialog: IntentDialog(stringLiteral: StaffSiri.noData))
        }
        let count = StaffSiri.isPortfolioRole(snap) ? snap.pendingApprovals : snap.officerPending
        let noun = count == 1 ? "application" : "applications"
        let dialog = count == 0
            ? "You have no applications pending review right now."
            : "You have \(count) \(noun) pending review."
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}

// MARK: - Inline: NPAs

struct NPACountIntent: AppIntent {
    static var title: LocalizedStringResource = "How Many NPAs"
    static var description = IntentDescription("Tells you how many loans are classified as NPA.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let snap = StaffSiri.snapshot() else {
            return .result(dialog: IntentDialog(stringLiteral: StaffSiri.noData))
        }
        guard StaffSiri.isPortfolioRole(snap) else {
            return .result(dialog: IntentDialog(stringLiteral: StaffSiri.notForRole))
        }
        let n = snap.npaCount
        let dialog: String
        if n == 0 {
            dialog = "No loans are currently classified as NPA. The portfolio is clean."
        } else {
            let noun = n == 1 ? "loan is" : "loans are"
            dialog = "\(n) \(noun) classified as NPA, which is \(StaffSiri.pct(snap.npaPercentage))% of the portfolio."
        }
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}

// MARK: - Inline: Collection Efficiency

struct CollectionEfficiencyIntent: AppIntent {
    static var title: LocalizedStringResource = "What's My Collection Efficiency"
    static var description = IntentDescription("Tells you this month's collection efficiency.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let snap = StaffSiri.snapshot() else {
            return .result(dialog: IntentDialog(stringLiteral: StaffSiri.noData))
        }
        guard StaffSiri.isPortfolioRole(snap) else {
            return .result(dialog: IntentDialog(stringLiteral: StaffSiri.notForRole))
        }
        let dialog = "Collection efficiency is \(StaffSiri.pct(snap.collectionEfficiency))% this month."
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}

// MARK: - Inline: Overdue EMIs

struct OverdueEMIsIntent: AppIntent {
    static var title: LocalizedStringResource = "Any Overdue EMIs"
    static var description = IntentDescription("Tells you how many EMIs are overdue across the portfolio.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let snap = StaffSiri.snapshot() else {
            return .result(dialog: IntentDialog(stringLiteral: StaffSiri.noData))
        }
        guard StaffSiri.isPortfolioRole(snap) else {
            return .result(dialog: IntentDialog(stringLiteral: StaffSiri.notForRole))
        }
        let n = snap.overdueEmis
        let dialog: String
        if n == 0 {
            dialog = "No EMIs are currently overdue. Collections are on track."
        } else {
            let noun = n == 1 ? "EMI is" : "EMIs are"
            dialog = "\(n) \(noun) currently overdue across the portfolio."
        }
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}

// MARK: - Inline: Portfolio Summary

struct PortfolioSummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "How's My Portfolio"
    static var description = IntentDescription("Summarizes active loans, amount disbursed, and NPA level.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let snap = StaffSiri.snapshot() else {
            return .result(dialog: IntentDialog(stringLiteral: StaffSiri.noData))
        }
        guard StaffSiri.isPortfolioRole(snap) else {
            return .result(dialog: IntentDialog(stringLiteral: StaffSiri.notForRole))
        }
        let health = snap.npaPercentage <= 5 ? "Portfolio looks healthy." : "NPA is worth watching."
        let loansNoun = snap.activeLoans == 1 ? "active loan" : "active loans"
        let dialog = "\(snap.activeLoans) \(loansNoun), \(StaffSiri.inrCompact(snap.totalDisbursed)) disbursed, NPA at \(StaffSiri.pct(snap.npaPercentage))%. \(health)"
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}

// MARK: - Inline: Oldest Pending Application

struct OldestPendingApplicationIntent: AppIntent {
    static var title: LocalizedStringResource = "Oldest Pending Application"
    static var description = IntentDescription("Tells you which application has been waiting the longest.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let snap = StaffSiri.snapshot() else {
            return .result(dialog: IntentDialog(stringLiteral: StaffSiri.noData))
        }
        guard let name = snap.oldestName, let days = snap.oldestDays else {
            return .result(dialog: "You have no pending applications waiting for review.")
        }
        let dayWord = days == 1 ? "day" : "days"
        let dialog = days == 0
            ? "\(name)'s application came in today and is your oldest pending one."
            : "\(name)'s application has been pending for \(days) \(dayWord)."
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}

// MARK: - Open: Approve an Application

struct ApproveApplicationIntent: AppIntent {
    static var title: LocalizedStringResource = "Approve Application"
    static var description = IntentDescription(
        "Opens a specific application so you can review and approve it."
    )
    static var openAppWhenRun: Bool = true

    @Parameter(
        title: "Application Number",
        description: "The application number, e.g. LMS-APP-007",
        requestValueDialog: "Which application number should I open?"
    )
    var applicationNumber: String

    static var parameterSummary: some ParameterSummary {
        Summary("Approve application \(\.$applicationNumber)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let number = applicationNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        StaffIntentRouter.shared.requestApproval(applicationNumber: number)
        return .result(dialog: "Opening application \(number) for you to review and approve.")
    }
}

// MARK: - Open Staff AI Assistant

struct OpenStaffAssistantIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Loanz Assistant"
    static var description = IntentDescription(
        "Opens the staff AI assistant, optionally with a question."
    )
    static var openAppWhenRun: Bool = true

    @Parameter(
        title: "Question",
        description: "What you want to ask the assistant",
        requestValueDialog: "What would you like to ask your assistant?"
    )
    var question: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Ask the Loanz assistant \(\.$question)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = question?.trimmingCharacters(in: .whitespacesAndNewlines)
        StaffIntentRouter.shared.request(.aiChat, prefill: (trimmed?.isEmpty == false) ? trimmed : nil)
        return .result(dialog: "Opening your Loanz assistant.")
    }
}

// MARK: - Open Pending Applications

struct ShowPendingApplicationsIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Pending Applications"
    static var description = IntentDescription("Opens applications awaiting your review.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        StaffIntentRouter.shared.request(.applications)
        return .result(dialog: "Here are your pending applications.")
    }
}

// MARK: - Open Portfolio

struct ShowPortfolioIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Portfolio"
    static var description = IntentDescription("Opens the portfolio / active loans view.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        StaffIntentRouter.shared.request(.portfolio)
        return .result(dialog: "Opening your portfolio.")
    }
}

// MARK: - App Shortcuts (spoken phrases)

struct StaffAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // --- Inline answers (no app open) ---
        AppShortcut(
            intent: PendingApplicationsCountIntent(),
            phrases: [
                "How many pending applications in \(.applicationName)",
                "How many applications are pending in \(.applicationName)"
            ],
            shortTitle: "Pending Count",
            systemImageName: "doc.on.doc"
        )
        AppShortcut(
            intent: NPACountIntent(),
            phrases: [
                "How many NPAs in \(.applicationName)",
                "How many NPA loans in \(.applicationName)"
            ],
            shortTitle: "NPA Count",
            systemImageName: "exclamationmark.triangle"
        )
        AppShortcut(
            intent: CollectionEfficiencyIntent(),
            phrases: [
                "What's my collection efficiency in \(.applicationName)",
                "What is my collection efficiency in \(.applicationName)"
            ],
            shortTitle: "Collection Efficiency",
            systemImageName: "chart.line.uptrend.xyaxis"
        )
        AppShortcut(
            intent: OverdueEMIsIntent(),
            phrases: [
                "Any overdue EMIs in \(.applicationName)",
                "How many overdue EMIs in \(.applicationName)"
            ],
            shortTitle: "Overdue EMIs",
            systemImageName: "clock.badge.exclamationmark"
        )
        AppShortcut(
            intent: PortfolioSummaryIntent(),
            phrases: [
                "How's my portfolio in \(.applicationName)",
                "How is my portfolio in \(.applicationName)"
            ],
            shortTitle: "Portfolio Summary",
            systemImageName: "briefcase"
        )
        AppShortcut(
            intent: OldestPendingApplicationIntent(),
            phrases: [
                "Who's my oldest pending application in \(.applicationName)",
                "What's my oldest pending application in \(.applicationName)"
            ],
            shortTitle: "Oldest Pending",
            systemImageName: "hourglass"
        )

        // --- Actions that open the app ---
        AppShortcut(
            intent: ApproveApplicationIntent(),
            phrases: [
                "Approve an application in \(.applicationName)",
                "Open an application in \(.applicationName)"
            ],
            shortTitle: "Approve Application",
            systemImageName: "checkmark.seal"
        )
        AppShortcut(
            intent: OpenStaffAssistantIntent(),
            phrases: [
                "Ask my Loanz assistant in \(.applicationName)",
                "Open my Loanz assistant in \(.applicationName)",
                "Talk to \(.applicationName) assistant"
            ],
            shortTitle: "Loanz Assistant",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: ShowPendingApplicationsIntent(),
            phrases: [
                "Show pending applications in \(.applicationName)",
                "Show my applications in \(.applicationName)"
            ],
            shortTitle: "Applications",
            systemImageName: "doc.on.doc"
        )
        AppShortcut(
            intent: ShowPortfolioIntent(),
            phrases: [
                "Show my portfolio in \(.applicationName)",
                "Open portfolio in \(.applicationName)"
            ],
            shortTitle: "Portfolio",
            systemImageName: "briefcase"
        )
    }
}
