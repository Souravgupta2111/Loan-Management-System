//
//  LMSAppIntents.swift
//  LMS
//
//  Siri & Shortcuts automations for the borrower app.
//
//  These App Intents let a borrower use Siri or the Shortcuts app to jump
//  straight into key flows, e.g. "Hey Siri, ask my loan advisor when my EMI
//  is due". Because the project uses Xcode file-system-synchronized groups,
//  this file is compiled into the LMS target automatically — no extension
//  target is required for App Intents.
//
//  Routing is handled by `IntentRouter.shared`, which the UI observes.
//

import AppIntents
import SwiftUI

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

// MARK: - Check EMI Schedule

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

// MARK: - Pay EMI

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

// MARK: - Check Credit Score

struct CheckCreditScoreIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Credit Score"
    static var description = IntentDescription(
        "Asks your AI advisor about your current credit score and how to improve it."
    )
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        IntentRouter.shared.openAdvisor(
            prefill: "What is my current credit score and how can I improve it?"
        )
        return .result(dialog: "Let me pull up your credit score details.")
    }
}

// MARK: - App Shortcuts (spoken phrases)

struct LMSAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
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
            intent: CheckEMIScheduleIntent(),
            phrases: [
                "Check my EMI schedule in \(.applicationName)",
                "When is my next EMI in \(.applicationName)"
            ],
            shortTitle: "EMI Schedule",
            systemImageName: "calendar"
        )
        AppShortcut(
            intent: PayEMIIntent(),
            phrases: [
                "Pay my EMI in \(.applicationName)",
                "Make a loan payment in \(.applicationName)"
            ],
            shortTitle: "Pay EMI",
            systemImageName: "indianrupeesign.circle"
        )
        AppShortcut(
            intent: CheckCreditScoreIntent(),
            phrases: [
                "Check my credit score in \(.applicationName)",
                "What's my credit score in \(.applicationName)"
            ],
            shortTitle: "Credit Score",
            systemImageName: "chart.bar.fill"
        )
    }
}
