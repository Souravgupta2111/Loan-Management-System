//
//  AccessibilityAnimation.swift
//  LMS Staff
//
//  Reduce Motion support. Use `.accessibleAnimation(_:value:)` instead of
//  `.animation(_:value:)` so animations are disabled when the user has
//  "Reduce Motion" enabled (Settings ▸ Accessibility ▸ Motion).
//

import SwiftUI

private struct AccessibleAnimation<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation?
    let value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

extension View {
    /// Like `.animation(_:value:)`, but honors the system "Reduce Motion" setting.
    func accessibleAnimation<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        modifier(AccessibleAnimation(animation: animation, value: value))
    }

    /// Runs `withAnimation` only when Reduce Motion is OFF; otherwise applies instantly.
    func reduceMotionAware(_ animation: Animation = .default, _ body: () -> Void) {
        if UIAccessibility.isReduceMotionEnabled {
            body()
        } else {
            withAnimation(animation, body)
        }
    }
}
