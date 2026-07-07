import SwiftUI

/// Status Badge (design.md §5.1) — Pill-shaped badges for loan/application status.
///
/// Color-blind safe: when the user enables "Differentiate Without Color" (iOS
/// Settings) or the in-app high-contrast toggle, a distinct SF Symbol is shown
/// alongside the text so status is never conveyed by color alone (A3).
struct StatusBadge: View {
    let status: String

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @StateObject private var a11yManager = AppAccessibilityManager.shared

    private var showsShape: Bool {
        differentiateWithoutColor || a11yManager.isHighContrastEnabled
    }

    var body: some View {
        HStack(spacing: Spacing.xs) {
            if showsShape {
                Image(systemName: iconName(for: status))
                    .font(.badge)
            } else {
                Circle()
                    .fill(Color.statusForeground(for: status))
                    .frame(width: 6, height: 6)
            }
            Text(displayText)
                .font(.badge)
        }
        .foregroundColor(Color.statusForeground(for: status))
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color.statusBackground(for: status))
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Status: \(displayText)")
    }

    private var displayText: String {
        status.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func iconName(for status: String) -> String {
        switch status.lowercased() {
        case "active", "approved", "paid", "verified", "disbursed", "completed", "closed":
            return "checkmark.circle.fill"
        case "pending", "under_review", "submitted", "upcoming", "processing", "pending_acceptance":
            return "clock.fill"
        case "rejected", "overdue", "failed", "npa", "default":
            return "xmark.octagon.fill"
        default:
            return "info.circle.fill"
        }
    }
}
