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

    /// Optional question to auto-send to the AI assistant when it opens.
    private var assistantPrefill: String?

    private init() {}

    func request(_ destination: Destination, prefill: String? = nil) {
        assistantPrefill = prefill
        pending = destination
    }

    /// Read-once prefill so the assistant only auto-asks the Siri question once.
    func consumePrefill() -> String? {
        let value = assistantPrefill
        assistantPrefill = nil
        return value
    }
}
