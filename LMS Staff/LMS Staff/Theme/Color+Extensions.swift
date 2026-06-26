import SwiftUI

// MARK: - Staff App Color System
// Professional dark-toned palette for iPad staff portal
// Distinct from the Borrower app's mint/green consumer theme

extension Color {

    // MARK: - Core Palette
    static let staffBackground    = Color(hex: "#0F1724")    // Deep navy
    static let staffSurface       = Color(hex: "#1A2332")    // Card background
    static let staffSurfaceLight  = Color(hex: "#243044")    // Elevated surface
    static let staffSurfaceMuted  = Color(hex: "#212F42")    // Input fields
    static let staffBorder        = Color(hex: "#3A4D64")    // Subtle borders
    static let staffBorderLight   = Color(hex: "#4A5E74")    // Focus borders

    // MARK: - Text Colors
    static let staffTextPrimary   = Color(hex: "#F0F4F8")    // White-ish
    static let staffTextSecondary = Color(hex: "#9AACBE")    // Muted labels
    static let staffTextTertiary  = Color(hex: "#7A8FA3")    // Hints, placeholders

    // MARK: - Accent Colors
    static let staffAccent        = Color(hex: "#4F8CFF")    // Primary blue
    static let staffAccentBg      = Color(hex: "#1A3366")    // Blue tinted bg
    static let staffGreen         = Color(hex: "#34C759")    // Success
    static let staffGreenBg       = Color(hex: "#1A3326")    // Success bg
    static let staffRed           = Color(hex: "#FF453A")    // Error/destructive
    static let staffRedBg         = Color(hex: "#3D1A1A")    // Error bg
    static let staffAmber         = Color(hex: "#FFD60A")    // Warning
    static let staffAmberBg       = Color(hex: "#3D3311")    // Warning bg
    static let staffPurple        = Color(hex: "#BF5AF2")    // Info/special
    static let staffPurpleBg      = Color(hex: "#2D1A3D")    // Info bg
    static let staffTeal          = Color(hex: "#30D5C8")    // Secondary accent
    static let staffTealBg        = Color(hex: "#1A3330")    // Teal bg
    static let staffOrange        = Color(hex: "#FF9F0A")    // Attention
    static let staffOrangeBg      = Color(hex: "#3D2A11")    // Orange bg

    // MARK: - Gradient Presets
    static let staffGradientStart  = Color(hex: "#1A2332")
    static let staffGradientEnd    = Color(hex: "#0F1724")
    static let staffAccentGradientStart = Color(hex: "#4F8CFF")
    static let staffAccentGradientEnd   = Color(hex: "#3366CC")

    // MARK: - Sidebar
    static let staffSidebarBg     = Color(hex: "#0D1420")    // Darker than main
    static let staffSidebarHover  = Color(hex: "#1A2840")    // Hover/active
    static let staffSidebarActive = Color(hex: "#1F3355")    // Selected

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
