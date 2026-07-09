import SwiftUI
import Combine
import UIKit

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

    var darkPrimaryHex: String {
        switch self {
        case .green: return "#88CFA4"
        case .purple: return "#C0A9FF"
        case .blue: return "#92C4FF"
        }
    }

    var secondaryHex: String {
        switch self {
        case .green: return "#409F73"
        case .purple: return "#7C5BD6"
        case .blue: return "#3A7DDA"
        }
    }

    var darkSecondaryHex: String {
        switch self {
        case .green: return "#98D9B1"
        case .purple: return "#CAB9FF"
        case .blue: return "#A7D0FF"
        }
    }

    var cardHex: String {
        switch self {
        case .green: return "#DFF3E6"
        case .purple: return "#D7C2FF"
        case .blue: return "#A9D4FF"
        }
    }

    var darkCardHex: String {
        switch self {
        case .green: return "#183524"
        case .purple: return "#2A2046"
        case .blue: return "#1A2F4C"
        }
    }

    var backgroundHex: String {
        switch self {
        case .green: return "#F1F8F0"
        case .purple: return "#F8F3FF"
        case .blue: return "#F2F8FF"
        }
    }

    var darkBackgroundHex: String {
        switch self {
        case .green: return "#07120D"
        case .purple: return "#0F0D16"
        case .blue: return "#09111A"
        }
    }

    var surfaceLightHex: String {
        switch self {
        case .green: return "#EAF4EA"
        case .purple: return "#F1E7FF"
        case .blue: return "#E4F2FF"
        }
    }

    var darkSurfaceLightHex: String {
        switch self {
        case .green: return "#102018"
        case .purple: return "#181424"
        case .blue: return "#111F31"
        }
    }

    var mutedHex: String {
        switch self {
        case .green: return "#EEF6ED"
        case .purple: return "#F4F0FC"
        case .blue: return "#F0F7FE"
        }
    }

    var darkMutedHex: String {
        switch self {
        case .green: return "#14261B"
        case .purple: return "#211B2D"
        case .blue: return "#1A293B"
        }
    }

    var borderHex: String {
        switch self {
        case .green: return "#DDEADC"
        case .purple: return "#E3D8F8"
        case .blue: return "#D6E8F8"
        }
    }

    var darkBorderHex: String {
        switch self {
        case .green: return "#254337"
        case .purple: return "#3B3151"
        case .blue: return "#30445F"
        }
    }

    var gradientStartHex: String {
        switch self {
        case .green: return "#F6FBF4"
        case .purple: return "#F1E7FF"
        case .blue: return "#E4F2FF"
        }
    }

    var darkGradientStartHex: String {
        switch self {
        case .green: return "#0C1D14"
        case .purple: return "#181322"
        case .blue: return "#101F32"
        }
    }

    var gradientEndHex: String {
        switch self {
        case .green: return "#EAF5EA"
        case .purple: return "#F8F3FF"
        case .blue: return "#F2F8FF"
        }
    }

    var darkGradientEndHex: String {
        switch self {
        case .green: return "#07120D"
        case .purple: return "#0F0D16"
        case .blue: return "#09111A"
        }
    }

    var darkerHex: String {
        switch self {
        case .green: return "#248149"
        case .purple: return "#553C9A"
        case .blue: return "#2559A6"
        }
    }

    var darkDarkerHex: String {
        switch self {
        case .green: return "#79C999"
        case .purple: return "#B495FF"
        case .blue: return "#83B8FF"
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
        
        // Force redraw of all windows to apply the new theme colors immediately
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                for window in windowScene.windows {
                    let style = window.overrideUserInterfaceStyle
                    window.overrideUserInterfaceStyle = (style == .dark) ? .light : .dark
                    DispatchQueue.main.async {
                        window.overrideUserInterfaceStyle = style
                    }
                }
            }
        }
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

    private static func dynamicColor(light: String, dark: String) -> Color {
        Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    private static func themedColor(
        light: @escaping (AppColorPalette) -> String,
        dark: @escaping (AppColorPalette) -> String
    ) -> Color {
        Color(UIColor { traits in
            let palette = AppThemeManager.activePalette
            return UIColor(hex: traits.userInterfaceStyle == .dark ? dark(palette) : light(palette))
        })
    }

    private static func themedColor(
        light: @escaping (AppColorPalette) -> String,
        lightOpacity: CGFloat,
        dark: @escaping (AppColorPalette) -> String,
        darkOpacity: CGFloat
    ) -> Color {
        Color(UIColor { traits in
            let palette = AppThemeManager.activePalette
            let hex = traits.userInterfaceStyle == .dark ? dark(palette) : light(palette)
            let opacity = traits.userInterfaceStyle == .dark ? darkOpacity : lightOpacity
            return UIColor(hex: hex).withAlphaComponent(opacity)
        })
    }

    /// System-wide high-contrast toggle. Works in both light and dark modes.
    static var staffHighContrast: Bool {
        AccessibilityManager.shared.isHighContrastEnabled
    }

    private static func accessibleDynamicColor(light: String, dark: String, highContrastLight: String, highContrastDark: String = "#FFFFFF") -> Color {
        Color(UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(hex: staffHighContrast ? highContrastDark : dark)
            }
            return UIColor(hex: staffHighContrast ? highContrastLight : light)
        })
    }

    // MARK: - Core Palette
    static var staffBackground: Color {
        Color(UIColor { traits in
            let palette = AppThemeManager.activePalette
            if traits.userInterfaceStyle == .dark {
                return UIColor(hex: staffHighContrast ? "#000000" : palette.darkBackgroundHex)
            }
            return UIColor(hex: staffHighContrast ? "#FFFFFF" : palette.backgroundHex)
        })
    }
    static var staffPanel: Color { accessibleDynamicColor(light: "#FFFFFF", dark: AppThemeManager.activePalette.darkSurfaceLightHex, highContrastLight: "#FFFFFF", highContrastDark: "#0A0A0A") }
    static var staffSurface: Color { accessibleDynamicColor(light: "#FBFEFA", dark: AppThemeManager.activePalette.darkSurfaceLightHex, highContrastLight: "#FFFFFF", highContrastDark: "#0A0A0A") }    // Card background
    static var staffSurfaceLight: Color {
        Color(UIColor { traits in
            let palette = AppThemeManager.activePalette
            if traits.userInterfaceStyle == .dark {
                return UIColor(hex: staffHighContrast ? "#0F0F0F" : palette.darkSurfaceLightHex)
            }
            return UIColor(hex: staffHighContrast ? "#FFFFFF" : palette.surfaceLightHex)
        })
    }
    static var staffSurfaceMuted: Color {
        Color(UIColor { traits in
            let palette = AppThemeManager.activePalette
            if traits.userInterfaceStyle == .dark {
                return UIColor(hex: staffHighContrast ? "#1A1A1A" : palette.darkMutedHex)
            }
            return UIColor(hex: staffHighContrast ? "#F0F0F0" : palette.mutedHex)
        })
    }
    static var staffBorder: Color {
        Color(UIColor { traits in
            let palette = AppThemeManager.activePalette
            if traits.userInterfaceStyle == .dark {
                return UIColor(hex: staffHighContrast ? "#FFFFFF" : palette.darkBorderHex)
            }
            return UIColor(hex: staffHighContrast ? "#000000" : palette.borderHex)
        })
    }
    static var staffBorderLight: Color {
        Color(UIColor { traits in
            let palette = AppThemeManager.activePalette
            if traits.userInterfaceStyle == .dark {
                return UIColor(hex: staffHighContrast ? "#FFFFFF" : palette.darkCardHex)
            }
            return UIColor(hex: staffHighContrast ? "#000000" : palette.cardHex)
        })
    }
    
    // MARK: - Card Custom Colors (Dynamic via traits)
    static var staffCardBackground: Color {
        Color(UIColor { traits in
            if staffHighContrast {
                return traits.userInterfaceStyle == .dark ? UIColor(hex: "#000000") : UIColor(hex: "#FFFFFF")
            } else {
                return traits.userInterfaceStyle == .dark ? UIColor(hex: AppThemeManager.activePalette.darkSurfaceLightHex) : UIColor(hex: "#FAFAF8")
            }
        })
    }
    
    static var staffCardBorder: Color {
        Color(UIColor { traits in
            if staffHighContrast {
                return traits.userInterfaceStyle == .dark ? UIColor(hex: "#FFFFFF") : UIColor(hex: "#1A1A1A")
            } else {
                let palette = AppThemeManager.activePalette
                return traits.userInterfaceStyle == .dark ? UIColor(hex: palette.darkBorderHex) : UIColor(hex: palette.borderHex)
            }
        })
    }

    // MARK: - Text Colors
    static var staffTextPrimary: Color { accessibleDynamicColor(light: "#1A1D1A", dark: "#F4F8F3", highContrastLight: "#000000", highContrastDark: "#FFFFFF") }    // Deep charcoal
    static var staffTextSecondary: Color { accessibleDynamicColor(light: "#71786F", dark: "#A5B2A9", highContrastLight: "#1C1C1C", highContrastDark: "#E5E5E5") }    // Muted labels
    static var staffTextTertiary: Color { accessibleDynamicColor(light: "#A0AAA0", dark: "#87968C", highContrastLight: "#3A3A3A", highContrastDark: "#B0B0B0") }    // Hints, placeholders

    // MARK: - Accent Colors
    static var staffAccent: Color {
        Color(UIColor { traits in
            let palette = AppThemeManager.activePalette
            if traits.userInterfaceStyle == .dark {
                return UIColor(hex: palette.darkPrimaryHex)
            }
            return UIColor(hex: staffHighContrast ? palette.darkerHex : palette.primaryHex)
        })
    }
    static var staffAccentBg: Color { themedColor(light: \.cardHex, lightOpacity: 0.35, dark: \.darkCardHex, darkOpacity: 0.42) }
    static var staffGreen: Color { themedColor(light: \.primaryHex, dark: \.darkPrimaryHex) }
    static var staffGreenBg: Color { themedColor(light: \.cardHex, lightOpacity: 0.35, dark: \.darkCardHex, darkOpacity: 0.42) }
    static let staffRed           = dynamicColor(light: "#D9534F", dark: "#FF7777")    // Error/destructive
    static let staffRedBg         = dynamicColor(light: "#F8E7E5", dark: "#4C2020")    // Error bg
    static let staffAmber         = dynamicColor(light: "#C89A24", dark: "#FFD166")    // Warning
    static let staffAmberBg       = dynamicColor(light: "#F7EED3", dark: "#4A3616")    // Warning bg
    static var staffPurple: Color { themedColor(light: \.darkerHex, dark: \.darkDarkerHex) }
    static var staffPurpleBg: Color { themedColor(light: \.cardHex, lightOpacity: 0.28, dark: \.darkCardHex, darkOpacity: 0.35) }
    static var staffTeal: Color { themedColor(light: \.secondaryHex, dark: \.darkSecondaryHex) }
    static var staffTealBg: Color { themedColor(light: \.cardHex, lightOpacity: 0.3, dark: \.darkCardHex, darkOpacity: 0.38) }
    static let staffOrange        = dynamicColor(light: "#B98222", dark: "#FFB45E")    // Attention
    static let staffOrangeBg      = dynamicColor(light: "#F6ECD7", dark: "#4A2F16")    // Orange bg

    // MARK: - Gradient Presets
    static var staffGradientStart: Color { themedColor(light: \.gradientStartHex, dark: \.darkGradientStartHex) }
    static var staffGradientEnd: Color { themedColor(light: \.gradientEndHex, dark: \.darkGradientEndHex) }
    static var staffAccentGradientStart: Color { themedColor(light: \.primaryHex, dark: \.darkPrimaryHex) }
    static var staffAccentGradientEnd: Color { themedColor(light: \.darkerHex, dark: \.darkDarkerHex) }

    // MARK: - Sidebar
    static var staffSidebarBg: Color { themedColor(light: \.surfaceLightHex, dark: \.darkSurfaceLightHex) }
    static var staffSidebarHover: Color { themedColor(light: \.cardHex, lightOpacity: 0.35, dark: \.darkCardHex, darkOpacity: 0.4) }
    static var staffSidebarActive: Color { themedColor(light: \.cardHex, lightOpacity: 0.45, dark: \.darkCardHex, darkOpacity: 0.5) }

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
    private static func semanticHex(_ hex: String, for style: UIUserInterfaceStyle) -> String {
        guard style == .dark else { return hex }
        let palette = AppThemeManager.activePalette

        switch hex.uppercased() {
        case "#1A1A1A", "#1A1D1A":
            return "#F4F8F3"
        case "#6B6B6B", "#71786F":
            return "#A5B2A9"
        case "#9E9E9E", "#A0AAA0":
            return "#87968C"
        case "#FFFFFF", "#FBFEFA":
            return palette.darkSurfaceLightHex
        case "#FAFAF8", "#F9FBF9", "#F8F8F5":
            return palette.darkBackgroundHex
        case "#F5F5F0", "#F5F5F5":
            return palette.darkMutedHex
        case "#E8E8E4":
            return palette.darkBorderHex
        case "#F0F0EC":
            return palette.darkBorderHex
        default:
            return hex
        }
    }

    init(hex: String) {
        self.init(UIColor { traits in
            UIColor(hex: Self.semanticHex(hex, for: traits.userInterfaceStyle))
        })
    }

    private init(staticHex hex: String) {
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

private extension UIColor {
    convenience init(hex: String) {
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
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}
