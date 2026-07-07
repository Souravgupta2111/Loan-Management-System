import Foundation
import UserNotifications
import Supabase
import UIKit

@MainActor
class NotificationService {
    static let shared = NotificationService()
    
    private var channel: RealtimeChannelV2?
    /// Tracks whether we are currently subscribed
    private var isSubscribed = false

    private init() {
        // Re-subscribe when app returns to foreground
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func appDidBecomeActive() {
        // Reconnect the realtime channel when user re-opens the app
        if !isSubscribed {
            subscribeToNotifications()
        }
    }
    
    func requestPermission() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        return granted
    }
    
    func subscribeToNotifications() {
        guard let userId = SupabaseManager.shared.currentUserId else { return }
        // Avoid duplicate subscriptions
        if isSubscribed { return }
        
        channel = SupabaseManager.shared.client.realtimeV2.channel("public:notifications")
        
        Task {
            guard let channel = channel else { return }
            
            let insertions = channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "notifications",
                filter: .eq("user_id", value: userId)
            )
            
            do {
                try await channel.subscribeWithError()
                isSubscribed = true
                print("✅ NotificationService: Realtime subscribed for user \(userId)")

                for await insert in insertions {
                    let record = insert.record
                    if let title = record["title"]?.stringValue,
                       let body = record["body"]?.stringValue {
                        // Only fire if the user hasn't disabled notifications in settings
                        if UserDefaults.standard.bool(forKey: "notificationsEnabled") {
                            await MainActor.run {
                                self.triggerLocalPush(title: title, body: body)
                            }
                        }
                    }
                }
            } catch {
                print("❌ NotificationService: Failed to subscribe — \(error)")
                isSubscribed = false
            }
        }
    }
    
    private func triggerLocalPush(title: String, body: String) {
        print("📣 [LMS Borrower] triggerLocalPush called with Title: \(title), Body: \(body)")
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "LMS_NOTIFICATION"

        // Use a tiny time-interval trigger instead of nil for reliable simulator delivery
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Local notification error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Schedule a test notification with a delay so you can background the app
    func scheduleTestNotification(afterSeconds seconds: TimeInterval = 5) {
        let content = UNMutableNotificationContent()
        content.title = "LMS Loan Update"
        content.body = "Your loan application has been reviewed. Tap to check the status."
        content.sound = .default
        content.categoryIdentifier = "LMS_NOTIFICATION"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: "test-notification-\(UUID().uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Test notification error: \(error.localizedDescription)")
            } else {
                print("✅ Test notification scheduled in \(seconds)s")
            }
        }
    }
    
    func unsubscribe() {
        if let channel = channel {
            Task {
                await SupabaseManager.shared.client.removeChannel(channel)
                isSubscribed = false
                print("⏹ NotificationService: Realtime unsubscribed")
            }
        }
    }
}
