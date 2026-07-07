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
        self.isHapticsEnabled = UserDefaults.standard.bool(forKey: "isHapticsEnabled")
        self.isHighContrastEnabled = UserDefaults.standard.bool(forKey: "isHighContrastEnabled")
    }
}
