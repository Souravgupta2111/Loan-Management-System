//
//  AppIntent.swift
//  StaffWidgets
//
//  Created by Apple on 07/07/26.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration" }
    static var description: IntentDescription { "This is an example widget." }

    // An example configurable parameter.
    @Parameter(title: "Favorite Emoji", default: "😃")
    var favoriteEmoji: String
}

/// A do-nothing intent used by SignInHint so that tapping an inactive
/// (wrong-role) widget runs this no-op inside the widget extension
/// instead of opening the app.
struct NoOpIntent: AppIntent {
    static var title: LocalizedStringResource = "No Action"
    static var description = IntentDescription("Does nothing.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
