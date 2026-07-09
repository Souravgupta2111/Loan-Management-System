//
//  HapticManager.swift
//  LMS Staff
//
//  Provides consistent haptic feedback across the Staff application.
//  Note: Haptic feedback requires iPhone with Taptic Engine.
//  On iPad and Simulator, haptics are silently ignored by iOS.
//

import UIKit

final class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        guard AccessibilityManager.shared.isHapticsEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
    
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard AccessibilityManager.shared.isHapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func selection() {
        guard AccessibilityManager.shared.isHapticsEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}
