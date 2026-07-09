import SwiftUI
import Combine

/// Global manager for system-wide accessibility toggles (Haptics & High Contrast).
///
/// Uses `@Published` properties backed by `UserDefaults` (rather than `@AppStorage`,
/// which does not emit `objectWillChange` from inside a class). This lets the whole
/// view tree re-render when a toggle flips — which is how the high-contrast palette
/// is applied app-wide. The same `UserDefaults` keys are preserved so any existing
/// `@AppStorage("isHighContrastEnabled")` readers stay in sync.
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
        // Haptics default ON when unset; high contrast default OFF.
        isHapticsEnabled = (UserDefaults.standard.object(forKey: Self.hapticsKey) as? Bool) ?? true
        isHighContrastEnabled = UserDefaults.standard.bool(forKey: Self.highContrastKey)
    }
}
