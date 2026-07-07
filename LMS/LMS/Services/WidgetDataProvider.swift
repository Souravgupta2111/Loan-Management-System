//
//  WidgetDataProvider.swift
//  LMS
//
//  Publishes a rich snapshot of the borrower's data into a shared App Group so
//  the home-screen / lock-screen widgets can render it. No-op until the App
//  Group entitlement exists (UserDefaults(suiteName:) returns nil).
//
//  The DTOs below are mirrored (identical shape) in the widget target's
//  LMSGlassWidgets.swift — they're plain JSON, decoded independently on each side.
//

import Foundation
import WidgetKit

enum WidgetKeys {
    /// Must match the App Group on BOTH the app and widget targets.
    static let appGroupID = "group.com.sourav.hi123.LMS"
    static let snapshot = "widget.snapshot"
    static let calcAmount = "widget.calc.amount"
    static let calcTenure = "widget.calc.tenure"
    static let loanIndex = "widget.loanIndex"
}

// MARK: - DTOs (mirror these in the widget target)

struct WidgetLoanDTO: Codable {
    var id: String            // loan UUID (for deep-linking to its payment page)
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
    var status: String   // paid / overdue / due / upcoming
}

struct WidgetSnapshotDTO: Codable {
    var loans: [WidgetLoanDTO]
    var creditScore: Int?
    var applicationStage: String?     // raw status of an in-progress application
    var applicationLoanName: String?
    var applicationUpdated: Date?
    var calendar: [WidgetEMIDayDTO]
    var generated: Date
}

@MainActor
enum WidgetDataProvider {
    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: WidgetKeys.appGroupID)
    }

    static func update(_ snapshot: WidgetSnapshotDTO) {
        guard let defaults else { return } // App Group not configured yet.
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: WidgetKeys.snapshot)
        }
        // Seed calculator defaults once so the calculator widget has a starting point.
        if defaults.object(forKey: WidgetKeys.calcAmount) == nil {
            defaults.set(500_000.0, forKey: WidgetKeys.calcAmount)
        }
        if defaults.object(forKey: WidgetKeys.calcTenure) == nil {
            defaults.set(24, forKey: WidgetKeys.calcTenure)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func clear() {
        guard let defaults else { return }
        [WidgetKeys.snapshot, WidgetKeys.loanIndex].forEach { defaults.removeObject(forKey: $0) }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
