import SwiftUI

// MARK: - Staff App Color System
// Soft mint and deep green palette matched to the borrower app reference.

extension Color {

    // MARK: - Core Palette
    static let staffBackground    = Color(hex: "#F1F8F0")    // Soft mint canvas
    static let staffSurface       = Color(hex: "#FBFEFA")    // Card background
    static let staffSurfaceLight  = Color(hex: "#EAF4EA")    // Elevated surface
    static let staffSurfaceMuted  = Color(hex: "#EEF6ED")    // Input fields
    static let staffBorder        = Color(hex: "#DDEADC")    // Subtle borders
    static let staffBorderLight   = Color(hex: "#BFE8CF")    // Focus borders

    // MARK: - Text Colors
    static let staffTextPrimary   = Color(hex: "#1A1D1A")    // Deep charcoal
    static let staffTextSecondary = Color(hex: "#71786F")    // Muted labels
    static let staffTextTertiary  = Color(hex: "#A0AAA0")    // Hints, placeholders

    // MARK: - Accent Colors
    static let staffAccent        = Color(hex: "#2E9658")    // Primary green
    static let staffAccentBg      = Color(hex: "#DFF3E6")    // Green tinted bg
    static let staffGreen         = Color(hex: "#2E9658")    // Success
    static let staffGreenBg       = Color(hex: "#DFF3E6")    // Success bg
    static let staffRed           = Color(hex: "#D9534F")    // Error/destructive
    static let staffRedBg         = Color(hex: "#F8E7E5")    // Error bg
    static let staffAmber         = Color(hex: "#C89A24")    // Warning
    static let staffAmberBg       = Color(hex: "#F7EED3")    // Warning bg
    static let staffPurple        = Color(hex: "#3A9A61")    // Info/special
    static let staffPurpleBg      = Color(hex: "#E4F3EA")    // Info bg
    static let staffTeal          = Color(hex: "#409F73")    // Secondary accent
    static let staffTealBg        = Color(hex: "#DDF2E8")    // Teal bg
    static let staffOrange        = Color(hex: "#B98222")    // Attention
    static let staffOrangeBg      = Color(hex: "#F6ECD7")    // Orange bg

    // MARK: - Gradient Presets
    static let staffGradientStart  = Color(hex: "#F6FBF4")
    static let staffGradientEnd    = Color(hex: "#EAF5EA")
    static let staffAccentGradientStart = Color(hex: "#2E9658")
    static let staffAccentGradientEnd   = Color(hex: "#248149")

    // MARK: - Sidebar
    static let staffSidebarBg     = Color(hex: "#EAF4EA")    // Soft side rail
    static let staffSidebarHover  = Color(hex: "#DFF3E6")    // Hover/active
    static let staffSidebarActive = Color(hex: "#D5ECDC")    // Selected

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
