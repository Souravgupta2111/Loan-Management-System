import SwiftUI

/// A reusable "Liquid Glass" style — frosted `.ultraThinMaterial` fill,
/// a soft light edge highlight, and a gentle depth shadow.
///
/// This mirrors the same frosted-glass language the system uses for the
/// floating tab bar. Apply `.liquidGlass(...)` to any card, row, or
/// container to keep that look consistent across every screen in the app —
/// no need to repeat background/overlay/shadow code per screen.
struct LiquidGlassModifier: ViewModifier {
    /// Corner radius of the glass shape.
    var cornerRadius: CGFloat = 24
    /// Optional color tint blended into the glass (e.g. Mint, Lavender, a status color).
    var tint: Color? = nil
    /// Tint strength, only used when `tint` is set.
    var tintOpacity: Double = 0.18
    /// Edge highlight color — defaults to white, but can be set to a status/accent color.
    var borderColor: Color = .white
    /// Edge highlight opacity — use a lower value (e.g. 0.2–0.25) when `borderColor` is a strong accent color.
    var borderOpacity: Double = 0.55
    /// Depth shadow tuning.
    var shadowOpacity: Double = 0.08
    var shadowRadius: CGFloat = 20
    var shadowY: CGFloat = 10

    /// Drives the in-app "High Contrast Mode" toggle. When on, the frosted
    /// translucency is replaced with a near-opaque surface and a strong, solid
    /// dark outline so every card separates clearly from the background and text
    /// sits on a high-contrast surface (WCAG-friendly). Because every card in the
    /// app uses `.liquidGlass(...)`, this upgrades the whole UI at once.
    @ObservedObject private var a11y = AppAccessibilityManager.shared
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let highContrast = a11y.isHighContrastEnabled && colorScheme == .light
        let isDarkMode = colorScheme == .dark
        let backgroundFill: AnyShapeStyle = isDarkMode
            ? AnyShapeStyle(Color.surface.opacity(0.90))
            : AnyShapeStyle(.ultraThinMaterial)
        let overlayFill = highContrast
            ? Color.white.opacity(0.95)
            : (tint?.opacity(isDarkMode ? min(tintOpacity, 0.08) : tintOpacity) ?? Color.clear)
        let strokeColor = highContrast
            ? Color(hex: "#1A1A1A")
            : (isDarkMode ? Color.border.opacity(0.55) : borderColor.opacity(borderOpacity))
        let strokeWidth: CGFloat = highContrast ? 2 : (isDarkMode ? 0.8 : 1)
        let cardShadowOpacity = highContrast ? 0 : (isDarkMode ? min(shadowOpacity + 0.10, 0.22) : shadowOpacity)
        let cardShadowRadius = highContrast ? 0 : (isDarkMode ? shadowRadius * 0.75 : shadowRadius)
        let cardShadowY = highContrast ? 0 : (isDarkMode ? shadowY * 0.6 : shadowY)

        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(overlayFill)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(strokeColor, lineWidth: strokeWidth)
                    .blendMode(highContrast || isDarkMode ? .normal : .overlay)
            )
            .shadow(
                color: Color.black.opacity(cardShadowOpacity),
                radius: cardShadowRadius,
                x: 0,
                y: cardShadowY
            )
    }
}

extension View {
    /// Applies the app's standard Liquid Glass treatment to any view.
    ///
    /// All parameters are optional — call `.liquidGlass()` for the default
    /// look, or override individual values per use case.
    ///
    /// ```swift
    /// // Default — 24pt corners, white edge highlight, soft shadow
    /// someCard.liquidGlass()
    ///
    /// // A larger card with bigger corners (e.g. a calendar card)
    /// calendarCard.liquidGlass(cornerRadius: 28)
    ///
    /// // A row with a status-colored border instead of white
    /// emiRow.liquidGlass(cornerRadius: 22, borderColor: accentColor, borderOpacity: 0.22,
    ///                     shadowOpacity: 0.05, shadowRadius: 12, shadowY: 6)
    ///
    /// // A tinted glass card
    /// statCard.liquidGlass(tint: .accentGreen)
    /// ```
    func liquidGlass(
        cornerRadius: CGFloat = 24,
        tint: Color? = nil,
        tintOpacity: Double = 0.18,
        borderColor: Color = .white,
        borderOpacity: Double = 0.55,
        shadowOpacity: Double = 0.08,
        shadowRadius: CGFloat = 20,
        shadowY: CGFloat = 10
    ) -> some View {
        modifier(LiquidGlassModifier(
            cornerRadius: cornerRadius,
            tint: tint,
            tintOpacity: tintOpacity,
            borderColor: borderColor,
            borderOpacity: borderOpacity,
            shadowOpacity: shadowOpacity,
            shadowRadius: shadowRadius,
            shadowY: shadowY
        ))
    }
}
