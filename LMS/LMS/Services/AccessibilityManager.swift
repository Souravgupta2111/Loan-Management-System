import SwiftUI

import Combine

/// Global manager for system-wide accessibility toggles (Haptics & High Contrast)
final class AppAccessibilityManager: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    static let shared = AppAccessibilityManager()
    
    var isHapticsEnabled: Bool {
        willSet { objectWillChange.send() }
        didSet { UserDefaults.standard.set(isHapticsEnabled, forKey: "isHapticsEnabled") }
    }
    var isHighContrastEnabled: Bool {
        willSet { objectWillChange.send() }
        didSet { UserDefaults.standard.set(isHighContrastEnabled, forKey: "isHighContrastEnabled") }
    }
    
    private init() {
        // Haptics should be ON by default (matches the Staff app and standard iOS
        // UX). `UserDefaults.bool(forKey:)` returns false for an unset key, which
        // silently disabled haptics on first launch — register a default instead.
        UserDefaults.standard.register(defaults: [
            "isHapticsEnabled": true,
            "isHighContrastEnabled": false
        ])
        self.isHapticsEnabled = UserDefaults.standard.bool(forKey: "isHapticsEnabled")
        self.isHighContrastEnabled = UserDefaults.standard.bool(forKey: "isHighContrastEnabled")
    }
}
