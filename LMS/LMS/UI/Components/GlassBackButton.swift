import SwiftUI

/// A reusable glassmorphic circular back button with a dark green arrow icon,
/// matching the app's premium frosted glass visual style.
struct GlassBackButton: View {
    var iconName: String
    let action: () -> Void
    
    init(iconName: String = "chevron.left", action: @escaping () -> Void) {
        self.iconName = iconName
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 34, height: 34)
                    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                Image(systemName: iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.accentGreen)
            }
        }
        .buttonStyle(.plain)
    }
}
