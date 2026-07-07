import SwiftUI

/// Staff-themed button component
/// Styles: primary (blue), secondary (surface), destructive (red), outline
struct StaffButton: View {
    let title: String
    let style: ButtonStyle
    var icon: String? = nil
    var isLoading: Bool = false
    var isFullWidth: Bool = true
    let action: () -> Void

    enum ButtonStyle {
        case primary
        case secondary
        case destructive
        case outline
        case success
    }

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            HapticManager.shared.impact(style: .medium)
            action()
        }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: foregroundColor))
                        .scaleEffect(0.8)
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.body.weight(.semibold))
                    }
                    Text(title)
                        .font(.staffButton)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: StaffCorner.md))
            .overlay(
                RoundedRectangle(cornerRadius: StaffCorner.md)
                    .stroke(strokeColor, lineWidth: strokeWidth)
            )
        }
        .disabled(isLoading)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .accessibleAnimation(.easeOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:     return .staffAccent
        case .secondary:   return .staffSurfaceLight
        case .destructive: return .staffRed
        case .outline:     return .clear
        case .success:     return .staffGreen
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary, .destructive, .success: return .white
        case .secondary:   return .staffTextPrimary
        case .outline:     return .staffAccent
        }
    }

    private var strokeColor: Color {
        switch style {
        case .outline:     return .staffAccent
        default:           return .clear
        }
    }

    private var strokeWidth: CGFloat {
        switch style {
        case .outline: return 1.5
        default:       return 0
        }
    }
}
