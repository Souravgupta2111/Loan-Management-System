import SwiftUI

/// Status Badge (design.md §5.1) — Pill-shaped badges for loan/application status.
struct StatusBadge: View {
    let status: String

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(Color.statusForeground(for: status))
                .frame(width: 6, height: 6)
            Text(status.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(.badge)
                .foregroundColor(Color.statusForeground(for: status))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color.statusBackground(for: status))
        .clipShape(Capsule())
    }
}
