//
//  HapticManager.swift
//  LMS Staff
//
//  Provides consistent haptic feedback across the Staff application.
//

import UIKit

@MainActor
final class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        guard AccessibilityManager.shared.isHapticsEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard AccessibilityManager.shared.isHapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    func selection() {
        guard AccessibilityManager.shared.isHapticsEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}
