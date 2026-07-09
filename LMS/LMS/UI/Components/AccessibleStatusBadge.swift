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
    @Environment(\.colorScheme) private var colorScheme

    private var showsShape: Bool {
        differentiateWithoutColor || (a11yManager.isHighContrastEnabled && colorScheme == .light)
    }

    var body: some View {
        HStack(spacing: 3) {
            if showsShape {
                Image(systemName: iconName(for: status))
                    .font(.system(size: 10, weight: .bold))
            } else {
                Image(systemName: iconName(for: status))
                    .font(.system(size: 10))
                    .accessibilityHidden(true)
            }
            
            Text(status.uppercased())
                .font(.system(size: 10, weight: .bold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor(for: status))
        .foregroundColor(foregroundColor(for: status))
        .clipShape(Capsule())
        // Accessibility Modifiers
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loan Status: \(status)")
        .accessibilityAddTraits(.isStaticText)
    }
    
    // Color Blind Safe Colors (WCAG AAA Contrast)
    private func backgroundColor(for status: String) -> Color {
        switch status.lowercased() {
        case "approved", "disbursed", "active", "verified":
            return Color(hex: "#005A36") // Dark Green
        case "pending", "under review", "under_review", "submitted", "upcoming":
            return Color(hex: "#B25D00") // Dark Orange/Brown
        case "rejected", "default", "npa", "failed", "not_verified", "not verified", "unverified":
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
        case "approved", "disbursed", "active", "verified":
            return "checkmark.circle.fill"
        case "pending", "under review", "under_review", "submitted", "upcoming":
            return "clock.fill"
        case "rejected", "default", "npa", "failed", "not_verified", "not verified", "unverified":
            return "xmark.octagon.fill"
        default:
            return "info.circle.fill"
        }
    }
}
