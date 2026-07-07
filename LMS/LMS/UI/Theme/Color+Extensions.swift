import SwiftUI

// MARK: - Color System (design.md §2)
// All hex values taken directly from the design specification.

extension Color {

    // MARK: - Core Palette (Light Mode)
    static let appBackground   = Color(hex: "#FAFAF8")
    static let surface         = Color(hex: "#FFFFFF")
    static let surfaceMuted    = Color(hex: "#F5F5F0")
    static let textPrimary     = Color(hex: "#1A1A1A")
    static let textSecondary   = Color(hex: "#6B6B6B")
    static let textTertiary    = Color(hex: "#9E9E9E")
    static let border          = Color(hex: "#E8E8E4")
    static let borderSubtle    = Color(hex: "#F0F0EC")

    // MARK: - Accent Colors
    static let accentGreen     = Color(hex: "#2D8B4E")
    static let accentGreenBg   = Color(hex: "#E8F5EC")
    static let themeGreen      = Color(hex: "#89DBA6")
    static let themeGreenBg    = Color(hex: "#89DBA6").opacity(0.2)
    static let accentMint      = Color(hex: "#C8E6D0")
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
    static let gradientMintStart    = Color(hex: "#F0FAF4")
    static let gradientMintEnd      = Color(hex: "#FAFAF8")
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
