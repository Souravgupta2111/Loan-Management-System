import SwiftUI

/// Glassmorphic card with blur backdrop for Staff app
struct StaffCard<Content: View>: View {
    var padding: CGFloat = StaffSpacing.lg
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(Color(hex: "#FAFAF8"))
            .clipShape(RoundedRectangle(cornerRadius: StaffCorner.md))
            .overlay(
                RoundedRectangle(cornerRadius: StaffCorner.md)
                    .stroke(Color.staffBorder, lineWidth: 1)
            )
    }
}

/// Stat metric card for dashboards
struct StaffStatCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    var icon: String? = nil
    var accentColor: Color = .staffAccent
    var trend: Trend? = nil

    enum Trend {
        case up(String)
        case down(String)
        case neutral(String)
    }

    var body: some View {
        StaffCard {
            VStack(alignment: .leading, spacing: StaffSpacing.md) {
                HStack {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(accentColor)
                            .frame(width: 36, height: 36)
                            .background(accentColor.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: StaffCorner.sm))
                    }
                    Spacer()
                    if let trend = trend {
                        trendBadge(trend)
                    }
                }

                VStack(alignment: .leading, spacing: StaffSpacing.xs) {
                    Text(value)
                        .font(.staffLargeAmount)
                        .foregroundColor(.staffTextPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Text(title)
                        .font(.staffCaption)
                        .foregroundColor(.staffTextSecondary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.staffFinePrint)
                            .foregroundColor(.staffTextTertiary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func trendBadge(_ trend: Trend) -> some View {
        switch trend {
        case .up(let value):
            HStack(spacing: 2) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .bold))
                Text(value)
                    .font(.staffBadge)
            }
            .foregroundColor(.staffGreen)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.staffGreenBg)
            .clipShape(Capsule())

        case .down(let value):
            HStack(spacing: 2) {
                Image(systemName: "arrow.down.right")
                    .font(.system(size: 10, weight: .bold))
                Text(value)
                    .font(.staffBadge)
            }
            .foregroundColor(.staffRed)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.staffRedBg)
            .clipShape(Capsule())

        case .neutral(let value):
            Text(value)
                .font(.staffBadge)
                .foregroundColor(.staffTextTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.staffSurfaceLight)
                .clipShape(Capsule())
        }
    }
}
