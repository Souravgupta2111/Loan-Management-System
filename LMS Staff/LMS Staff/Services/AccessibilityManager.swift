import SwiftUI
import Combine

final class AccessibilityManager: ObservableObject {
    static let shared = AccessibilityManager()

    static let hapticsKey = "isHapticsEnabled"
    static let highContrastKey = "isHighContrastEnabled"

    @Published var isHapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(isHapticsEnabled, forKey: Self.hapticsKey) }
    }

    @Published var isHighContrastEnabled: Bool {
        didSet { UserDefaults.standard.set(isHighContrastEnabled, forKey: Self.highContrastKey) }
    }

    private init() {
        isHapticsEnabled = (UserDefaults.standard.object(forKey: Self.hapticsKey) as? Bool) ?? true
        isHighContrastEnabled = UserDefaults.standard.bool(forKey: Self.highContrastKey)
    }
}
