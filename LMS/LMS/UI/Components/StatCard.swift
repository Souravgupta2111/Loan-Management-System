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

struct DarkStatPill: View {
    let count: Int
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            Text("\(count)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text(label.replacingOccurrences(of: "\n", with: " "))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
}
