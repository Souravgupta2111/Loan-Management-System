//
//  LMSApp.swift
//  LMS
//
//  Created by Apple on 22/06/26.
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
struct LMSApp: App {

    // Initialize Supabase on app launch
    private let supabase = SupabaseManager.shared
    @StateObject private var themeManager = AppThemeManager()

    // Notification delegate must be retained for the app's lifetime
    private let notificationDelegate = NotificationDelegate()

    init() {
        // Set delegate BEFORE any notification requests
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(.accentGreen)
                .environment(\.appColorPalette, themeManager.selectedPalette)
                .environmentObject(themeManager)
        }
    }
}
