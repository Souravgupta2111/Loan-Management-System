import Foundation
import WidgetKit

enum WidgetKeys {
    static let appGroupID = "group.com.sourav.hi123.LMS"
    static let snapshot = "widget.snapshot"
    static let calcAmount = "widget.calc.amount"
    static let calcTenure = "widget.calc.tenure"
    static let loanIndex = "widget.loanIndex"
}

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
    var loans: [WidgetLoanDTO]        // active loans only
    var creditScore: Int?
    var applicationStage: String?     // raw status of an in-progress application
    var applicationLoanName: String?
    var applicationUpdated: Date?
    var calendar: [WidgetEMIDayDTO]
    var generated: Date
    var closedLoans: Int? = nil
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
