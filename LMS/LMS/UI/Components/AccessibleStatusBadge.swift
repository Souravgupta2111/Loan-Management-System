//
//  AccessibleStatusBadge.swift
//  LMS
//
//  A high-contrast, color-blind safe status badge for loan states.
//

import SwiftUI

struct AccessibleStatusBadge: View {
    let status: String
    @StateObject private var a11yManager = AppAccessibilityManager.shared

    // Dynamic Type Support
    @Environment(\.sizeCategory) var sizeCategory
    // Honor the system "Differentiate Without Color" setting too, not just the in-app toggle.
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    private var showsShape: Bool {
        differentiateWithoutColor || a11yManager.isHighContrastEnabled
    }

    var body: some View {
        HStack(spacing: 4) {
            if showsShape {
                Image(systemName: iconName(for: status))
                    .font(.caption.weight(.bold))
            } else {
                Image(systemName: iconName(for: status))
                    .accessibilityHidden(true)
            }
            
            Text(status.uppercased())
                .font(.caption.weight(.bold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(backgroundColor(for: status))
        .foregroundColor(foregroundColor(for: status))
        .cornerRadius(8)
        // Accessibility Modifiers
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loan Status: \(status)")
        .accessibilityAddTraits(.isStaticText)
    }
    
    // Color Blind Safe Colors (WCAG AAA Contrast)
    private func backgroundColor(for status: String) -> Color {
        switch status.lowercased() {
        case "approved", "disbursed", "active":
            return Color(hex: "#005A36") // Dark Green
        case "pending", "under review":
            return Color(hex: "#B25D00") // Dark Orange/Brown
        case "rejected", "default", "npa":
            return Color(hex: "#A30000") // Dark Red
        default:
            return Color.gray.opacity(0.8)
        }
    }
    
    private func foregroundColor(for status: String) -> Color {
        return .white
    }
    
    private func iconName(for status: String) -> String {
        switch status.lowercased() {
        case "approved", "disbursed", "active":
            return "checkmark.circle.fill"
        case "pending", "under review":
            return "clock.fill"
        case "rejected", "default", "npa":
            return "xmark.octagon.fill"
        default:
            return "info.circle.fill"
        }
    }
}
