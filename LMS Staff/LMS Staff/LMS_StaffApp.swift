//
//  LMS_StaffApp.swift
//  LMS Staff
//
//  Created for Staff/Admin portal.
//

import SwiftUI
import UserNotifications

// MARK: - Notification Delegate (foreground delivery)
/// Without this delegate, iOS silently consumes local notifications
/// when the app is in the foreground — they never appear as banners.
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner + sound + badge even when in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}

@main
struct LMS_StaffApp: App {
    // Initialize Supabase on app launch
    private let supabase = SupabaseManager.shared
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var themeManager = AppThemeManager()
    @StateObject private var accessibilityManager = AccessibilityManager.shared
    
    // Notification delegate must be retained for the app's lifetime
    private let notificationDelegate = NotificationDelegate()

    init() {
        // Set delegate BEFORE any notification requests
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
                .tint(.staffAccent)
                .environment(\.appColorPalette, themeManager.selectedPalette)
                // Re-inject a value derived from the high-contrast flag so the
                // whole tree re-renders (and re-reads the palette) when toggled.
                .environment(\.staffHighContrastEnabled, accessibilityManager.isHighContrastEnabled)
                .environmentObject(authViewModel)
                .environmentObject(themeManager)
                .environmentObject(accessibilityManager)

        }
    }
}
