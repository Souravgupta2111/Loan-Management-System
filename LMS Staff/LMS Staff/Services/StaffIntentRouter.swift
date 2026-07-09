//
//  StaffIntentRouter.swift
//  LMS Staff
//
//  Lightweight router used by Siri / Shortcuts App Intents to drive navigation
//  in the staff portal once the app is foregrounded. Intents publish a logical
//  destination here; StaffTabRouter maps it to the correct role-specific screen.
//

import SwiftUI
import Combine

@MainActor
final class StaffIntentRouter: ObservableObject {
    static let shared = StaffIntentRouter()

    /// Logical destinations, resolved to role-specific sidebar items by the router.
    enum Destination {
        case aiChat
        case applications
        case portfolio
        case npa
        case disbursements
    }

    @Published var pending: Destination?

    /// An application number Siri asked to open for approval (e.g. "LMS-APP-007").
    /// The applications screen can read this to focus the matching application.
    @Published var approvalTargetNumber: String?

    /// Optional question to auto-send to the AI assistant when it opens.
    private var assistantPrefill: String?

    private init() {}

    func request(_ destination: Destination, prefill: String? = nil) {
        assistantPrefill = prefill
        pending = destination
    }

    /// Route to the applications screen with a specific application flagged for approval.
    func requestApproval(applicationNumber: String) {
        approvalTargetNumber = applicationNumber
        pending = .applications
    }

    /// Read-once prefill so the assistant only auto-asks the Siri question once.
    func consumePrefill() -> String? {
        let value = assistantPrefill
        assistantPrefill = nil
        return value
    }
}
