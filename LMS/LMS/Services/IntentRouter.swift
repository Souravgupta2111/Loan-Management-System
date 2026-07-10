import SwiftUI
import Combine

@MainActor
final class IntentRouter: ObservableObject {
    static let shared = IntentRouter()

    enum Tab {
        case home, loans, schedule
    }

    @Published var selectedTab: Tab = .home
    @Published var showAIChat = false
    @Published var applyRequested = 0
    @Published var advisorPrefill: String?
    @Published var paymentTarget: PaymentTarget?

    struct PaymentTarget: Identifiable {
        let id = UUID()
        let loanId: UUID
    }

    private init() {}

    func openPayment(loanId: UUID) {
        showAIChat = false
        paymentTarget = PaymentTarget(loanId: loanId)
    }

    func openAdvisor(prefill: String? = nil) {
        advisorPrefill = prefill
        showAIChat = true
    }

    func switchTab(_ tab: Tab) {
        showAIChat = false
        selectedTab = tab
    }

    func startLoanApplication() {
        showAIChat = false
        selectedTab = .home
        applyRequested += 1
    }
}
