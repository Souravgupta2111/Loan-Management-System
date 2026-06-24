import SwiftUI

/// Stat Card (design.md §5.5) — Small cards showing a single financial metric.
struct StatCard: View {
    let label: String
    let value: String
    let backgroundColor: Color

    init(_ label: String, value: String, backgroundColor: Color = .surface) {
        self.label = label
        self.value = value
        self.backgroundColor = backgroundColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(value)
                .font(.cardTitle)
                .foregroundColor(.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: Corner.lg))
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: Corner.lg)
                .stroke(Color.border, lineWidth: 0.5)
        )
    }
}

/// Dark Stat Pill — compact version used inside hero cards (e.g. "2 Active Loans")
struct DarkStatPill: View {
    let count: Int
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.bodyLarge)
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.accentDark)
        .clipShape(Capsule())
    }
}
