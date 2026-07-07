//
//  IntentRouter.swift
//  LMS
//
//  Lightweight in-app router used by Siri / Shortcuts App Intents to drive
//  navigation once the app is foregrounded. App Intents cannot push SwiftUI
//  views directly, so they publish an intent here and the UI reacts.
//

import SwiftUI
import Combine

@MainActor
final class IntentRouter: ObservableObject {
    static let shared = IntentRouter()

    enum Tab {
        case home, loans, schedule
    }

    /// The tab the UI should switch to.
    @Published var selectedTab: Tab = .home
    /// Whether the AI Advisor sheet should be presented.
    @Published var showAIChat = false
    /// An optional question to auto-send to the advisor when it opens.
    @Published var advisorPrefill: String?
    /// A loan whose EMI payment page should be presented (from the widget "Pay Now").
    @Published var paymentTarget: PaymentTarget?

    /// Identifiable wrapper so a loan id can drive a `.fullScreenCover(item:)`.
    struct PaymentTarget: Identifiable {
        let id = UUID()
        let loanId: UUID
    }

    private init() {}

    /// Open the EMI payment page for a specific loan.
    func openPayment(loanId: UUID) {
        showAIChat = false
        paymentTarget = PaymentTarget(loanId: loanId)
    }

    /// Open the AI Financial Advisor, optionally auto-asking a question.
    func openAdvisor(prefill: String? = nil) {
        advisorPrefill = prefill
        showAIChat = true
    }

    /// Switch to a main tab (and dismiss the advisor if it was open).
    func switchTab(_ tab: Tab) {
        showAIChat = false
        selectedTab = tab
    }
}
