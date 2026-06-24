import SwiftUI

/// Section Header (design.md §5.10) — Title + "See All" action.
struct SectionHeader: View {
    let title: String
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.cardTitle)
                .foregroundColor(.textPrimary)
            Spacer()
            if let action = action {
                Button(action: action) {
                    HStack(spacing: Spacing.xs) {
                        Text("See All")
                            .font(.bodyRegular)
                        Image(systemName: "arrow.right")
                            .font(.caption)
                    }
                    .foregroundColor(.accentBeigeDk)
                }
            }
        }
    }
}
