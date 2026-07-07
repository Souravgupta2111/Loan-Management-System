//
//  StaffAppIntents.swift
//  LMS Staff
//
//  Siri & Shortcuts automations for the staff portal (officers & managers).
//  Example: "Hey Siri, ask my LMS assistant how many applications are pending".
//
//  App Intents compile into the main target automatically (the project uses
//  Xcode file-system-synchronized groups). Routing goes through
//  StaffIntentRouter, which StaffTabRouter observes.
//

import AppIntents
import SwiftUI

// MARK: - Open Staff AI Assistant

struct OpenStaffAssistantIntent: AppIntent {
    static var title: LocalizedStringResource = "Open LMS Assistant"
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
        Summary("Ask the LMS assistant \(\.$question)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = question?.trimmingCharacters(in: .whitespacesAndNewlines)
        StaffIntentRouter.shared.request(.aiChat, prefill: (trimmed?.isEmpty == false) ? trimmed : nil)
        return .result(dialog: "Opening your LMS assistant.")
    }
}

// MARK: - Show Pending Applications

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

// MARK: - Show Portfolio

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
        AppShortcut(
            intent: OpenStaffAssistantIntent(),
            phrases: [
                "Ask my LMS assistant in \(.applicationName)",
                "Open my LMS assistant in \(.applicationName)",
                "Talk to \(.applicationName) assistant"
            ],
            shortTitle: "LMS Assistant",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: ShowPendingApplicationsIntent(),
            phrases: [
                "Show pending applications in \(.applicationName)",
                "What's pending in \(.applicationName)"
            ],
            shortTitle: "Pending Applications",
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
