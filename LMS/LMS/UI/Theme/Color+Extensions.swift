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

    var themeHex: String {
        switch self {
        case .green: return "#89DBA6"
        case .purple: return "#D7C2FF"
        case .blue: return "#A9D4FF"
        }
    }

    var backgroundHex: String {
        switch self {
        case .green: return "#FAFAF8"
        case .purple: return "#F8F3FF"
        case .blue: return "#F2F8FF"
        }
    }

    var accentBackgroundHex: String {
        switch self {
        case .green: return "#E8F5EC"
        case .purple: return "#EDE3FF"
        case .blue: return "#DDEEFF"
        }
    }

    var gradientStartHex: String {
        switch self {
        case .green: return "#F0FAF4"
        case .purple: return "#F1E7FF"
        case .blue: return "#E4F2FF"
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

extension EnvironmentValues {
    var appColorPalette: AppColorPalette {
        get { self[AppColorPaletteKey.self] }
        set { self[AppColorPaletteKey.self] = newValue }
    }
}

// MARK: - Color System (design.md §2)
// All hex values taken directly from the design specification.

extension Color {
    static var currentPalette: AppColorPalette {
        AppThemeManager.activePalette
    }

    private static func themedColor(_ hex: @escaping (AppColorPalette) -> String) -> Color {
        Color(UIColor { _ in
            UIColor(hex: hex(AppThemeManager.activePalette))
        })
    }

    // MARK: - Core Palette (Light Mode)
    static var appBackground: Color { themedColor(\.backgroundHex) }
    static let surface         = Color(hex: "#FFFFFF")
    static let surfaceMuted    = Color(hex: "#F5F5F0")
    static let textPrimary     = Color(hex: "#1A1A1A")
    static let textSecondary   = Color(hex: "#6B6B6B")
    static let textTertiary    = Color(hex: "#9E9E9E")
    static let border          = Color(hex: "#E8E8E4")
    static let borderSubtle    = Color(hex: "#F0F0EC")

    // MARK: - Accent Colors
    static var accentGreen: Color { themedColor(\.primaryHex) }
    static var accentGreenBg: Color { themedColor(\.accentBackgroundHex) }
    static var themeGreen: Color { themedColor(\.themeHex) }
    static var themeGreenBg: Color { themedColor(\.themeHex).opacity(0.2) }
    static var accentMint: Color { themedColor(\.themeHex).opacity(0.55) }
    static let accentBeige     = Color(hex: "#F5E6C8")
    static let accentBeigeDk   = Color(hex: "#D4A574")
    static let accentLavender  = Color(hex: "#E8D5F0")
    static let accentRed       = Color(hex: "#D94040")
    static let accentRedBg     = Color(hex: "#FDE8E8")
    static let accentAmber     = Color(hex: "#E8A830")
    static let accentAmberBg   = Color(hex: "#FFF3D6")
    static let accentDark      = Color(hex: "#2C2C2E")
    static let accentDarkText  = Color.white
    static let accentBlue      = Color(hex: "#3B82F6")
    static let accentBlueBg    = Color(hex: "#EBF2FF")

    // MARK: - Gradient Presets
    static var gradientMintStart: Color { themedColor(\.gradientStartHex) }
    static var gradientMintEnd: Color { themedColor(\.backgroundHex) }
    static let gradientBeigeStart   = Color(hex: "#FDF6EC")
    static let gradientBeigeEnd     = Color(hex: "#FAFAF8")
    static let gradientLavenderStart = Color(hex: "#F5ECF9")
    static let gradientLavenderEnd   = Color(hex: "#FAFAF8")
    static let gradientCardStart    = Color(hex: "#FFFFFF")
    static let gradientCardEnd      = Color(hex: "#F8F8F5")
}

// MARK: - Semantic Status Helpers
extension Color {
    static func statusForeground(for status: String) -> Color {
        switch status.lowercased() {
        case "active", "approved", "paid", "verified":
            return .accentGreen
        case "pending", "under_review", "submitted", "upcoming":
            return Color(hex: "#D85C00")
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
            return Color(hex: "#FFF3E0")
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
