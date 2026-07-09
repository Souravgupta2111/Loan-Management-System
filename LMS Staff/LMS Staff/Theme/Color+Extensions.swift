import SwiftUI
import Combine

// MARK: - Staff Palette Selection
enum AppColorPalette: String, CaseIterable, Identifiable {
    case green
    case purple
    case blue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .green: return "Green"
        case .purple: return "Purple"
        case .blue: return "Blue"
        }
    }

    var primaryHex: String {
        switch self {
        case .green: return "#2E9658"
        case .purple: return "#6B46C1"
        case .blue: return "#2F6FCC"
        }
    }

    var secondaryHex: String {
        switch self {
        case .green: return "#409F73"
        case .purple: return "#7C5BD6"
        case .blue: return "#3A7DDA"
        }
    }

    var cardHex: String {
        switch self {
        case .green: return "#DFF3E6"
        case .purple: return "#D7C2FF"
        case .blue: return "#A9D4FF"
        }
    }

    var backgroundHex: String {
        switch self {
        case .green: return "#F1F8F0"
        case .purple: return "#F8F3FF"
        case .blue: return "#F2F8FF"
        }
    }

    var surfaceLightHex: String {
        switch self {
        case .green: return "#EAF4EA"
        case .purple: return "#F1E7FF"
        case .blue: return "#E4F2FF"
        }
    }

    var mutedHex: String {
        switch self {
        case .green: return "#EEF6ED"
        case .purple: return "#F4F0FC"
        case .blue: return "#F0F7FE"
        }
    }

    var borderHex: String {
        switch self {
        case .green: return "#DDEADC"
        case .purple: return "#E3D8F8"
        case .blue: return "#D6E8F8"
        }
    }

    var gradientStartHex: String {
        switch self {
        case .green: return "#F6FBF4"
        case .purple: return "#F1E7FF"
        case .blue: return "#E4F2FF"
        }
    }

    var gradientEndHex: String {
        switch self {
        case .green: return "#EAF5EA"
        case .purple: return "#F8F3FF"
        case .blue: return "#F2F8FF"
        }
    }

    var darkerHex: String {
        switch self {
        case .green: return "#248149"
        case .purple: return "#553C9A"
        case .blue: return "#2559A6"
        }
    }
}

final class AppThemeManager: ObservableObject {
    static let storageKey = "selectedColorPalette"
    static var activePalette: AppColorPalette = {
        AppColorPalette(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .green
    }()

    @Published private var paletteStorage: AppColorPalette

    var selectedPalette: AppColorPalette {
        get { paletteStorage }
        set { applyPalette(newValue) }
    }

    init() {
        let savedValue = UserDefaults.standard.string(forKey: Self.storageKey)
        let savedPalette = AppColorPalette(rawValue: savedValue ?? "") ?? .green
        paletteStorage = savedPalette
        Self.activePalette = savedPalette
    }

    private func applyPalette(_ palette: AppColorPalette) {
        guard paletteStorage != palette else { return }
        Self.activePalette = palette
        UserDefaults.standard.set(palette.rawValue, forKey: Self.storageKey)
        paletteStorage = palette
    }
}

private struct AppColorPaletteKey: EnvironmentKey {
    static let defaultValue: AppColorPalette = AppThemeManager.activePalette
}

/// Propagates the high-contrast flag through the environment purely so the view
/// tree re-renders (and re-reads the palette) whenever the toggle changes.
private struct StaffHighContrastKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var appColorPalette: AppColorPalette {
        get { self[AppColorPaletteKey.self] }
        set { self[AppColorPaletteKey.self] = newValue }
    }

    var staffHighContrastEnabled: Bool {
        get { self[StaffHighContrastKey.self] }
        set { self[StaffHighContrastKey.self] = newValue }
    }
}

// MARK: - Staff App Color System
// Soft mint and deep green palette matched to the borrower app reference.

extension Color {
    static var currentPalette: AppColorPalette {
        AppThemeManager.activePalette
    }

    /// System-wide high-contrast toggle. When enabled, the palette flips to a
    /// maximum-legibility scheme (white surfaces, near-black text, solid black
    /// borders, and a darker accent) that easily clears WCAG AA contrast.
    static var staffHighContrast: Bool {
        AccessibilityManager.shared.isHighContrastEnabled
    }

    // MARK: - Core Palette
    static var staffBackground: Color {
        staffHighContrast ? Color(hex: "#FFFFFF") : Color(hex: currentPalette.backgroundHex)
    }
    static var staffSurface: Color {
        staffHighContrast ? Color(hex: "#FFFFFF") : Color(hex: "#FBFEFA")    // Card background
    }
    static var staffSurfaceLight: Color {
        staffHighContrast ? Color(hex: "#FFFFFF") : Color(hex: currentPalette.surfaceLightHex)
    }
    static var staffSurfaceMuted: Color {
        staffHighContrast ? Color(hex: "#F0F0F0") : Color(hex: currentPalette.mutedHex)
    }
    static var staffBorder: Color {
        staffHighContrast ? Color(hex: "#000000") : Color(hex: currentPalette.borderHex)
    }
    static var staffBorderLight: Color {
        staffHighContrast ? Color(hex: "#000000") : Color(hex: currentPalette.cardHex)
    }

    // MARK: - Text Colors
    static var staffTextPrimary: Color {
        staffHighContrast ? Color(hex: "#000000") : Color(hex: "#1A1D1A")    // Deep charcoal
    }
    static var staffTextSecondary: Color {
        staffHighContrast ? Color(hex: "#1C1C1C") : Color(hex: "#71786F")    // Muted labels
    }
    static var staffTextTertiary: Color {
        staffHighContrast ? Color(hex: "#3A3A3A") : Color(hex: "#A0AAA0")    // Hints, placeholders
    }

    // MARK: - Accent Colors
    static var staffAccent: Color {
        staffHighContrast ? Color(hex: currentPalette.darkerHex) : Color(hex: currentPalette.primaryHex)
    }
    static var staffAccentBg: Color { Color(hex: currentPalette.cardHex).opacity(0.35) }
    static var staffGreen: Color { Color(hex: currentPalette.primaryHex) }
    static var staffGreenBg: Color { Color(hex: currentPalette.cardHex).opacity(0.35) }
    static let staffRed           = Color(hex: "#D9534F")    // Error/destructive
    static let staffRedBg         = Color(hex: "#F8E7E5")    // Error bg
    static let staffAmber         = Color(hex: "#C89A24")    // Warning
    static let staffAmberBg       = Color(hex: "#F7EED3")    // Warning bg
    static var staffPurple: Color { Color(hex: currentPalette.darkerHex) }
    static var staffPurpleBg: Color { Color(hex: currentPalette.cardHex).opacity(0.28) }
    static var staffTeal: Color { Color(hex: currentPalette.secondaryHex) }
    static var staffTealBg: Color { Color(hex: currentPalette.cardHex).opacity(0.3) }
    static let staffOrange        = Color(hex: "#B98222")    // Attention
    static let staffOrangeBg      = Color(hex: "#F6ECD7")    // Orange bg

    // MARK: - Gradient Presets
    static var staffGradientStart: Color { Color(hex: currentPalette.gradientStartHex) }
    static var staffGradientEnd: Color { Color(hex: currentPalette.gradientEndHex) }
    static var staffAccentGradientStart: Color { Color(hex: currentPalette.primaryHex) }
    static var staffAccentGradientEnd: Color { Color(hex: currentPalette.darkerHex) }

    // MARK: - Sidebar
    static var staffSidebarBg: Color { Color(hex: currentPalette.surfaceLightHex) }
    static var staffSidebarHover: Color { Color(hex: currentPalette.cardHex).opacity(0.35) }
    static var staffSidebarActive: Color { Color(hex: currentPalette.cardHex).opacity(0.45) }

    // MARK: - Role Badge Colors
    static func roleBadgeColor(for role: String) -> Color {
        switch role.lowercased() {
        case "admin":   return .staffPurple
        case "manager": return .staffTeal
        case "officer": return .staffAccent
        default:        return .staffTextTertiary
        }
    }

    static func roleBadgeBg(for role: String) -> Color {
        switch role.lowercased() {
        case "admin":   return .staffPurpleBg
        case "manager": return .staffTealBg
        case "officer": return .staffAccentBg
        default:        return .staffSurfaceLight
        }
    }
}

// MARK: - Semantic Status Colors (Staff Context)
extension Color {
    static func staffStatusForeground(for status: String) -> Color {
        switch status.lowercased() {
        case "active", "approved", "paid", "verified", "confirmed":
            return .staffGreen
        case "pending", "under_review", "submitted", "upcoming", "processing", "due":
            return .staffAmber
        case "rejected", "overdue", "failed", "npa":
            return .staffRed
        case "draft", "inactive":
            return .staffTextTertiary
        case "disbursed":
            return .staffAccent
        case "sent_back":
            return .staffOrange
        case "closed", "completed":
            return .staffTextSecondary
        case "restructured":
            return .staffPurple
        case "written_off":
            return .staffRed
        default:
            return .staffTextSecondary
        }
    }

    static func staffStatusBackground(for status: String) -> Color {
        switch status.lowercased() {
        case "active", "approved", "paid", "verified", "confirmed":
            return .staffGreenBg
        case "pending", "under_review", "submitted", "upcoming", "processing", "due":
            return .staffAmberBg
        case "rejected", "overdue", "failed", "npa":
            return .staffRedBg
        case "disbursed":
            return .staffAccentBg
        case "sent_back":
            return .staffOrangeBg
        case "restructured":
            return .staffPurpleBg
        case "written_off":
            return .staffRedBg
        default:
            return .staffSurfaceLight
        }
    }
}

// MARK: - Hex Initialization
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
