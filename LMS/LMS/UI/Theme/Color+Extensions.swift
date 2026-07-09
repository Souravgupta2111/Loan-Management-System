import SwiftUI
import Combine
import UIKit

// MARK: - App Palette Selection
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
        case .green: return "#2D8B4E"
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

    var themeHex: String {
        switch self {
        case .green: return "#89DBA6"
        case .purple: return "#D7C2FF"
        case .blue: return "#A9D4FF"
        }
    }

    var darkThemeHex: String {
        switch self {
        case .green: return "#1C3A29"
        case .purple: return "#34265A"
        case .blue: return "#213858"
        }
    }

    var backgroundHex: String {
        switch self {
        case .green: return "#FAFAF8"
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

    var accentBackgroundHex: String {
        switch self {
        case .green: return "#E8F5EC"
        case .purple: return "#EDE3FF"
        case .blue: return "#DDEEFF"
        }
    }

    var darkAccentBackgroundHex: String {
        switch self {
        case .green: return "#183524"
        case .purple: return "#2A2046"
        case .blue: return "#1A2F4C"
        }
    }

    var gradientStartHex: String {
        switch self {
        case .green: return "#F0FAF4"
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

    var darkSurfaceHex: String {
        switch self {
        case .green: return "#102018"
        case .purple: return "#181424"
        case .blue: return "#111F31"
        }
    }

    var darkSurfaceMutedHex: String {
        switch self {
        case .green: return "#14261B"
        case .purple: return "#211B2D"
        case .blue: return "#1A293B"
        }
    }

    var darkBorderHex: String {
        switch self {
        case .green: return "#254337"
        case .purple: return "#3B3151"
        case .blue: return "#30445F"
        }
    }

    var darkBorderSubtleHex: String {
        switch self {
        case .green: return "#192D23"
        case .purple: return "#282139"
        case .blue: return "#1E3148"
        }
    }

    var darkGradientCardStartHex: String {
        switch self {
        case .green: return "#13251B"
        case .purple: return "#201833"
        case .blue: return "#172A40"
        }
    }

    var darkGradientCardEndHex: String {
        switch self {
        case .green: return "#0F1E16"
        case .purple: return "#171222"
        case .blue: return "#101F31"
        }
    }

    var darkerHex: String {
        switch self {
        case .green: return "#1B6B3A"
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

    let objectWillChange = ObservableObjectPublisher()

    var selectedPalette: AppColorPalette {
        didSet {
            guard selectedPalette != oldValue else { return }
            Self.activePalette = selectedPalette
            UserDefaults.standard.set(selectedPalette.rawValue, forKey: Self.storageKey)
            objectWillChange.send()
            
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

    init() {
        let savedValue = UserDefaults.standard.string(forKey: Self.storageKey)
        selectedPalette = AppColorPalette(rawValue: savedValue ?? "") ?? .green
        Self.activePalette = selectedPalette
    }
}

private struct AppColorPaletteKey: EnvironmentKey {
    static let defaultValue: AppColorPalette = AppThemeManager.activePalette
}

/// Propagates the high-contrast flag through the environment purely so the view
/// tree re-renders (and re-reads the palette) whenever the toggle changes.
private struct AppHighContrastKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var appColorPalette: AppColorPalette {
        get { self[AppColorPaletteKey.self] }
        set { self[AppColorPaletteKey.self] = newValue }
    }

    var appHighContrastEnabled: Bool {
        get { self[AppHighContrastKey.self] }
        set { self[AppHighContrastKey.self] = newValue }
    }
}

// MARK: - Color System (design.md §2)
// All hex values taken directly from the design specification.

extension Color {
    static var currentPalette: AppColorPalette {
        AppThemeManager.activePalette
    }

    /// System-wide high-contrast toggle. When enabled, the palette flips to a
    /// maximum-legibility scheme (white surfaces, near-black text, solid black
    /// borders, and a darker accent) that easily clears WCAG AA contrast.
    static var appHighContrast: Bool {
        AppAccessibilityManager.shared.isHighContrastEnabled
    }

    private static func themedColor(_ hex: @escaping (AppColorPalette) -> String) -> Color {
        Color(UIColor { _ in
            UIColor(hex: hex(AppThemeManager.activePalette))
        })
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

    private static func accessibleDynamicColor(light: String, dark: String, highContrastLight: String) -> Color {
        Color(UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(hex: dark)
            }
            return UIColor(hex: appHighContrast ? highContrastLight : light)
        })
    }

    // MARK: - Core Palette
    static var appBackground: Color {
        Color(UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(hex: AppThemeManager.activePalette.darkBackgroundHex)
            }
            return UIColor(hex: appHighContrast ? "#FFFFFF" : AppThemeManager.activePalette.backgroundHex)
        })
    }
    static var surface: Color { accessibleDynamicColor(light: "#FFFFFF", dark: AppThemeManager.activePalette.darkSurfaceHex, highContrastLight: "#FFFFFF") }
    static var surfaceMuted: Color { accessibleDynamicColor(light: "#F5F5F0", dark: AppThemeManager.activePalette.darkSurfaceMutedHex, highContrastLight: "#F0F0F0") }
    static var textPrimary: Color { accessibleDynamicColor(light: "#1A1A1A", dark: "#F4F8F3", highContrastLight: "#000000") }
    static var textSecondary: Color { accessibleDynamicColor(light: "#6B6B6B", dark: "#A5B2A9", highContrastLight: "#1C1C1C") }
    static var textTertiary: Color { accessibleDynamicColor(light: "#9E9E9E", dark: "#87968C", highContrastLight: "#3A3A3A") }
    static var border: Color { accessibleDynamicColor(light: "#E8E8E4", dark: AppThemeManager.activePalette.darkBorderHex, highContrastLight: "#000000") }
    static var borderSubtle: Color { accessibleDynamicColor(light: "#F0F0EC", dark: AppThemeManager.activePalette.darkBorderSubtleHex, highContrastLight: "#000000") }

    // MARK: - Accent Colors
    static var accentGreen: Color {
        Color(UIColor { traits in
            let palette = AppThemeManager.activePalette
            if traits.userInterfaceStyle == .dark {
                return UIColor(hex: palette.darkPrimaryHex)
            }
            return UIColor(hex: appHighContrast ? palette.darkerHex : palette.primaryHex)
        })
    }
    static var accentGreenBg: Color { themedColor(light: \.accentBackgroundHex, dark: \.darkAccentBackgroundHex) }
    static var themeGreen: Color { themedColor(light: \.themeHex, dark: \.darkThemeHex) }
    static var themeGreenBg: Color { themedColor(light: \.themeHex, lightOpacity: 0.2, dark: \.darkThemeHex, darkOpacity: 0.35) }
    static var accentMint: Color { themedColor(light: \.themeHex, dark: \.darkPrimaryHex).opacity(0.55) }
    static let accentBeige     = dynamicColor(light: "#F5E6C8", dark: "#4A3A22")
    static let accentBeigeDk   = dynamicColor(light: "#D4A574", dark: "#D7B27B")
    static let accentLavender  = dynamicColor(light: "#E8D5F0", dark: "#483257")
    static let accentRed       = dynamicColor(light: "#D94040", dark: "#FF7777")
    static let accentRedBg     = dynamicColor(light: "#FDE8E8", dark: "#4C2020")
    static let accentAmber     = dynamicColor(light: "#E8A830", dark: "#FFD166")
    static let accentAmberBg   = dynamicColor(light: "#FFF3D6", dark: "#4A3616")
    static let statusPending   = dynamicColor(light: "#D85C00", dark: "#FFD166")
    static let statusPendingBg = dynamicColor(light: "#FFF3E0", dark: "#4A3616")
    static let accentDark      = dynamicColor(light: "#2C2C2E", dark: "#CAD3CC")
    static let accentDarkText  = dynamicColor(light: "#FFFFFF", dark: "#111811")
    static let accentBlue      = dynamicColor(light: "#3B82F6", dark: "#92C4FF")
    static let accentBlueBg    = dynamicColor(light: "#EBF2FF", dark: "#1D3557")

    // MARK: - Gradient Presets
    static var gradientMintStart: Color { themedColor(light: \.gradientStartHex, dark: \.darkGradientStartHex) }
    static var gradientMintEnd: Color { themedColor(light: \.backgroundHex, dark: \.darkBackgroundHex) }
    static let gradientBeigeStart   = dynamicColor(light: "#FDF6EC", dark: "#2A241B")
    static let gradientBeigeEnd     = dynamicColor(light: "#FAFAF8", dark: "#07120D")
    static let gradientLavenderStart = dynamicColor(light: "#F5ECF9", dark: "#251C2E")
    static let gradientLavenderEnd   = dynamicColor(light: "#FAFAF8", dark: "#07120D")
    static var gradientCardStart: Color { themedColor(light: { _ in "#FFFFFF" }, dark: \.darkGradientCardStartHex) }
    static var gradientCardEnd: Color { themedColor(light: { _ in "#F8F8F5" }, dark: \.darkGradientCardEndHex) }
}

// MARK: - Semantic Status Helpers
extension Color {
    static func statusForeground(for status: String) -> Color {
        switch status.lowercased() {
        case "active", "approved", "paid", "verified":
            return .accentGreen
        case "pending", "under_review", "submitted", "upcoming":
            return .statusPending
        case "rejected", "overdue", "failed", "not_verified", "not verified", "unverified":
            return .accentRed
        case "draft", "inactive":
            return .textSecondary
        case "disbursed", "processing":
            return .accentBlue
        case "closed", "completed":
            return .textPrimary
        default:
            return .textSecondary
        }
    }

    static func statusBackground(for status: String) -> Color {
        switch status.lowercased() {
        case "active", "approved", "paid", "verified":
            return .accentGreenBg
        case "pending", "under_review", "submitted", "upcoming":
            return .statusPendingBg
        case "rejected", "overdue", "failed", "not_verified", "not verified", "unverified":
            return .accentRedBg
        case "disbursed", "processing":
            return .accentBlueBg
        case "draft", "inactive", "closed", "completed":
            return .surfaceMuted
        default:
            return .surfaceMuted
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
            return palette.darkSurfaceHex
        case "#FAFAF8", "#F9FBF9", "#F8F8F5":
            return palette.darkBackgroundHex
        case "#F5F5F0", "#F5F5F5":
            return palette.darkSurfaceMutedHex
        case "#E8E8E4":
            return palette.darkBorderHex
        case "#F0F0EC":
            return palette.darkBorderSubtleHex
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
