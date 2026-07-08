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
    /// The user id the current subscription is bound to.
    private var subscribedUserId: UUID?

    private init() {
        // Notifications are ON by default; users can opt out in settings. Using
        // register(defaults:) makes `.bool(forKey:)` return true when unset
        // while still honoring an explicit user choice of false.
        UserDefaults.standard.register(defaults: ["notificationsEnabled": true])

        // Re-subscribe when app returns to foreground
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func appDidBecomeActive() {
        // Reconnect / re-bind the realtime channel when the user re-opens the
        // app. subscribeToNotifications() no-ops if already bound to this user
        // and re-binds if the signed-in user changed.
        subscribeToNotifications()
    }
    
    func requestPermission() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        return granted
    }
    
    func subscribeToNotifications() {
        guard let userId = SupabaseManager.shared.currentUserId else { return }
        // Already subscribed for THIS user — nothing to do.
        if isSubscribed && subscribedUserId == userId { return }

        // Subscribed for a different user (e.g. logout → login as someone else):
        // tear down the stale channel before re-binding to the new user.
        if let existing = channel {
            channel = nil
            isSubscribed = false
            subscribedUserId = nil
            Task { await SupabaseManager.shared.client.removeChannel(existing) }
        }
        
        // Namespace the channel per user so it can't collide across accounts.
        channel = SupabaseManager.shared.client.realtimeV2.channel("notifications:\(userId.uuidString)")
        
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
                subscribedUserId = userId
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
                subscribedUserId = nil
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
    
    // MARK: - Proactive EMI Reminders (local, on-device)

    /// A single upcoming EMI to remind the borrower about.
    struct EMIReminder {
        let loanName: String
        let amount: Double
        let dueDate: Date
    }

    /// Schedules local "EMI due soon" nudges 3 days and 1 day before each due
    /// date (at 9am). Safe to call repeatedly — it clears previously scheduled
    /// EMI reminders first, so it always reflects the latest schedule. Respects
    /// the in-app "Notifications" toggle.
    func scheduleEMIReminders(_ reminders: [EMIReminder]) {
        let center = UNUserNotificationCenter.current()

        center.getPendingNotificationRequests { requests in
            let staleIDs = requests.map { $0.identifier }.filter { $0.hasPrefix("emi-reminder-") }
            center.removePendingNotificationRequests(withIdentifiers: staleIDs)

            guard UserDefaults.standard.bool(forKey: "notificationsEnabled") else { return }

            let calendar = Calendar.current
            let now = Date()
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            formatter.locale = Locale(identifier: "en_IN")

            for reminder in reminders {
                for daysBefore in [3, 1] {
                    guard let fireDay = calendar.date(byAdding: .day, value: -daysBefore, to: reminder.dueDate) else { continue }
                    var comps = calendar.dateComponents([.year, .month, .day], from: fireDay)
                    comps.hour = 9
                    comps.minute = 0
                    guard let fireDate = calendar.date(from: comps), fireDate > now else { continue }

                    let content = UNMutableNotificationContent()
                    content.title = daysBefore == 1 ? "EMI due tomorrow" : "EMI due in \(daysBefore) days"
                    let amt = formatter.string(from: NSNumber(value: reminder.amount)) ?? "\(Int(reminder.amount))"
                    content.body = "Your \(reminder.loanName) EMI of ₹\(amt) is due soon. Tap to pay now."
                    content.sound = .default
                    content.categoryIdentifier = "LMS_NOTIFICATION"

                    let triggerComps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                    let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComps, repeats: false)
                    let id = "emi-reminder-\(reminder.loanName)-\(Int(reminder.dueDate.timeIntervalSince1970))-\(daysBefore)"
                    center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
                }
            }
        }
    }

    func unsubscribe() {
        if let channel = channel {
            Task {
                await SupabaseManager.shared.client.removeChannel(channel)
                isSubscribed = false
                subscribedUserId = nil
                self.channel = nil
                print("⏹ NotificationService: Realtime unsubscribed")
            }
        }
    }
}
