import SwiftUI

/// Color-coded status pill badge for application/loan/payment statuses
struct StaffStatusBadge: View {
    let status: String
    var size: BadgeSize = .regular
    @StateObject private var a11yManager = AccessibilityManager.shared
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    enum BadgeSize {
        case small
        case regular
        case large
    }

    /// Show the shape/icon fallback when either the system "Differentiate
    /// Without Color" setting or the in-app high-contrast toggle is on (A3).
    private var showsShape: Bool {
        differentiateWithoutColor || a11yManager.isHighContrastEnabled
    }

    var body: some View {
        HStack(spacing: 4) {
            if showsShape {
                Image(systemName: iconName(for: status))
                    .font(badgeFont)
            }
            Text(displayText)
                .font(badgeFont)
                .fontWeight(.semibold)
        }
        .foregroundColor(Color.staffStatusForeground(for: status))
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(Color.staffStatusBackground(for: status))
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Status: \(displayText)")
    }
    
    private func iconName(for status: String) -> String {
        switch status.lowercased() {
        case "approved", "disbursed", "active", "paid", "completed":
            return "checkmark.circle.fill"
        case "pending", "under_review", "under review":
            return "clock.fill"
        case "rejected", "default", "npa", "overdue", "failed":
            return "xmark.octagon.fill"
        default:
            return "info.circle.fill"
        }
    }

    private var displayText: String {
        let cleaned = status.replacingOccurrences(of: "_", with: " ")
        if cleaned.lowercased() == "npa" {
            return "NPA"
        }
        return cleaned.capitalized
    }

    private var badgeFont: Font {
        switch size {
        case .small:   return .staffFinePrint
        case .regular: return .staffBadge
        case .large:   return .staffCaption
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .small:   return 6
        case .regular: return 10
        case .large:   return 14
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .small:   return 3
        case .regular: return 5
        case .large:   return 7
        }
    }
}

/// Role badge specifically styled for staff roles
struct StaffRoleBadge: View {
    let role: String

    var body: some View {
        Text(role.capitalized)
            .font(.staffBadge)
            .fontWeight(.semibold)
            .foregroundColor(Color.roleBadgeColor(for: role))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.roleBadgeBg(for: role))
            .clipShape(Capsule())
    }
}
