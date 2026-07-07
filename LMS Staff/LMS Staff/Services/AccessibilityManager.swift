import SwiftUI
import Combine

/// Global manager for system-wide accessibility toggles (Haptics & High Contrast)
final class AccessibilityManager: ObservableObject {
    static let shared = AccessibilityManager()
    
    // User Preferences (Persisted via AppStorage)
    @AppStorage("isHapticsEnabled") var isHapticsEnabled: Bool = true
    @AppStorage("isHighContrastEnabled") var isHighContrastEnabled: Bool = false
    
    private init() {}
}
