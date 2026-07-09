import SwiftUI

/// Glassmorphic card with blur backdrop for Staff app
struct StaffCard<Content: View>: View {
    var padding: CGFloat = StaffSpacing.lg
    @ViewBuilder let content: () -> Content

    // High Contrast Mode: replace the subtle hairline border with a strong,
    // solid dark outline so cards separate clearly. Applied app-wide because
    // every staff screen builds on StaffCard. Read the AppStorage key directly
    // so the card live-updates the moment the toggle changes.
    @AppStorage("isHighContrastEnabled") private var highContrast: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let effectiveHighContrast = highContrast

        content()
            .padding(padding)
            .background(effectiveHighContrast ? (colorScheme == .dark ? Color(hex: "#1A1A1A") : Color(hex: "#FFFFFF")) : (colorScheme == .dark ? Color.staffSurface : Color(hex: "#FAFAF8")))
            .clipShape(RoundedRectangle(cornerRadius: StaffCorner.md))
            .overlay(
                RoundedRectangle(cornerRadius: StaffCorner.md)
                    .stroke(
                        effectiveHighContrast ? (colorScheme == .dark ? Color(hex: "#FFFFFF") : Color(hex: "#1A1A1A")) : Color.staffBorder,
                        lineWidth: effectiveHighContrast ? 2 : 1
                    )
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
                            .font(.headline.weight(.semibold))
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
        .accessibilityValue(trendAccessibilityText)
    }
    
    private var trendAccessibilityText: String {
        guard let trend = trend else { return "" }
        switch trend {
        case .up(let val): return "Trending up by \(val)"
        case .down(let val): return "Trending down by \(val)"
        case .neutral(let val): return "Neutral trend: \(val)"
        }
    }

    @ViewBuilder
    private func trendBadge(_ trend: Trend) -> some View {
        switch trend {
        case .up(let value):
            HStack(spacing: 2) {
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
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
                    .font(.caption.weight(.bold))
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
