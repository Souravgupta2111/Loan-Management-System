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
    
    // Notification delegate must be retained for the app's lifetime
    private let notificationDelegate = NotificationDelegate()

    init() {
        // Set delegate BEFORE any notification requests
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(.staffAccent)
                .environment(\.appColorPalette, themeManager.selectedPalette)
                .environmentObject(authViewModel)
                .environmentObject(themeManager)

        }
    }
}
