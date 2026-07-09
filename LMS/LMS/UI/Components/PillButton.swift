import SwiftUI

/// Pill Button (design.md §5.2, 5.3, 5.4)
/// - primary (Dark Pill): accentDark bg, paired high-contrast text, ALL CAPS
/// - secondary (Beige Pill): accentBeigeDk bg, white text
/// - outline: clear bg, border, textPrimary
struct PillButton: View {
    let title: String
    let style: PillStyle
    var icon: String? = nil
    let action: () -> Void

    enum PillStyle {
        case primary    // Dark pill (§5.2)
        case secondary  // Beige pill (§5.3)
        case outline    // Outline pill (§5.4)
        case destructive // Red outline
    }

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            HapticManager.shared.impact(style: style == .primary ? .medium : .light)
            action()
        }) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.subheadline.weight(.semibold))
                }
                Text(style == .primary ? title.uppercased() : title)
                    .font(.body.weight(.semibold))
                    .tracking(style == .primary ? 1 : 0)
                if style == .primary {
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.semibold))
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(strokeColor, lineWidth: strokeWidth)
            )
        }
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .opacity(isPressed ? 0.9 : 1.0)
        .animation(.easeOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:     return .accentDark
        case .secondary:   return .accentBeigeDk
        case .outline:     return .clear
        case .destructive: return .clear
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:     return .accentDarkText
        case .secondary:   return .white
        case .outline:     return .textPrimary
        case .destructive: return .accentRed
        }
    }

    private var strokeColor: Color {
        switch style {
        case .outline:     return .border
        case .destructive: return .accentRed
        default:           return .clear
        }
    }

    private var strokeWidth: CGFloat {
        switch style {
        case .outline, .destructive: return 1
        default: return 0
        }
    }
}
