import SwiftUI

struct LiquidGlassModifier: ViewModifier {
    let tintColor: Color?
    
    func body(content: Content) -> some View {
        content
            .background(
                // Use ultra thin material for the iOS 26 Liquid Glass feel
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        tintColor != nil ? tintColor!.opacity(0.3) : Color.clear
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 16, x: 0, y: 8)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
                    .blendMode(.overlay)
            )
    }
}

extension View {
    /// Applies a premium Liquid Glass effect to any view
    /// - Parameter tint: Optional color to tint the glass (e.g. Mint, Lavender)
    func liquidGlass(tint: Color? = nil) -> some View {
        self.modifier(LiquidGlassModifier(tintColor: tint))
    }
}
