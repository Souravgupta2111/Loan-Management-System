//
//  PaymentLiveActivity.swift
//  LMS
//
//  Starts / updates / ends the payment Live Activity (Dynamic Island + lock
//  screen) while an EMI payment is in progress. The Live Activity UI itself
//  lives in the widget extension (PaymentLiveActivityWidget).
//

import Foundation
import ActivityKit

enum PaymentLiveActivity {

    /// Begin a Live Activity for a payment that's now processing.
    @discardableResult
    static func start(title: String, amount: Double) -> Activity<PaymentActivityAttributes>? {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return nil }
        let attributes = PaymentActivityAttributes(title: title, amount: amount)
        let state = PaymentActivityAttributes.ContentState(
            stage: "processing",
            message: "Processing your payment…"
        )
        do {
            return try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: Date().addingTimeInterval(300))
            )
        } catch {
            print("Live Activity start failed: \(error)")
            return nil
        }
    }

    /// Mark the payment confirmed and let the activity linger briefly, then dismiss.
    static func confirm(_ activity: Activity<PaymentActivityAttributes>?) async {
        guard let activity else { return }
        let state = PaymentActivityAttributes.ContentState(
            stage: "confirmed",
            message: "Payment successful"
        )
        await activity.end(.init(state: state, staleDate: nil), dismissalPolicy: .after(.now + 6))
    }

    /// Mark the payment failed/cancelled and dismiss.
    static func fail(_ activity: Activity<PaymentActivityAttributes>?, message: String = "Payment not completed") async {
        guard let activity else { return }
        let state = PaymentActivityAttributes.ContentState(stage: "failed", message: message)
        await activity.end(.init(state: state, staleDate: nil), dismissalPolicy: .after(.now + 3))
    }
}
