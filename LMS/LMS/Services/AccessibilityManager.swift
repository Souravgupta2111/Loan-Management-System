import SwiftUI

import Combine

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
        UserDefaults.standard.register(defaults: [
            "isHapticsEnabled": true,
            "isHighContrastEnabled": false
        ])
        self.isHapticsEnabled = UserDefaults.standard.bool(forKey: "isHapticsEnabled")
        self.isHighContrastEnabled = UserDefaults.standard.bool(forKey: "isHighContrastEnabled")
    }
}
