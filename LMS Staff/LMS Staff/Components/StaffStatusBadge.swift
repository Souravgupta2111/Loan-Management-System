import SwiftUI

/// Color-coded status pill badge for application/loan/payment statuses
struct StaffStatusBadge: View {
    let status: String
    var size: BadgeSize = .regular

    enum BadgeSize {
        case small
        case regular
        case large
    }

    var body: some View {
        Text(displayText)
            .font(badgeFont)
            .fontWeight(.semibold)
            .foregroundColor(Color.staffStatusForeground(for: status))
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(Color.staffStatusBackground(for: status))
            .clipShape(Capsule())
    }

    private var displayText: String {
        status
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
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
