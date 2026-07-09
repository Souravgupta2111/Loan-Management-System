//
//  NotificationService.swift
//  LMS Staff
//
//  Service for managing user notifications.
//

import Foundation
import Supabase
import UserNotifications
import UIKit

@MainActor
class NotificationService {
    
    static let shared = NotificationService()
    private let supabase = SupabaseManager.shared
    private var channel: RealtimeChannelV2?
    
    /// Tracks whether we are currently subscribed
    private var isSubscribed = false
    /// The user id the current subscription is bound to.
    private var subscribedUserId: UUID?
    
    // Track recently sent message contents to prevent echo notifications
    var recentlySentMessages: Set<String> = []
    
    private init() {
        // Re-subscribe when app returns to foreground (iPad sleep/wake cycle
        // kills the WebSocket — this ensures reconnection).
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func appDidBecomeActive() {
        subscribeToNotifications()
    }
    
    /// Fetches notifications for the logged in staff member
    func fetchNotifications() async throws -> [LMSNotification] {
        guard let userId = supabase.currentUserId else { return [] }
        
        let notifications: [LMSNotification] = try await supabase.database
            .from("notifications")
            .select()
            .eq("user_id", value: userId)
            .order("sent_at", ascending: false)
            .execute()
            .value
        
        return notifications
    }
    
    /// Marks a notification as read
    func markAsRead(notificationId: UUID) async throws {
        let formatter = ISO8601DateFormatter()
        let nowString = formatter.string(from: Date())
        
        try await supabase.database
            .from("notifications")
            .update([
                "is_read": AnyEncodable(true),
                "read_at": AnyEncodable(nowString)
            ])
            .eq("id", value: notificationId)
            .execute()
    }
    
    /// Utility function to create a new notification in the database for a target user
    func createNotification(
        userId: UUID,
        title: String,
        message: String,
        type: LMSNotificationType = .general,
        referenceId: UUID? = nil,
        referenceType: String? = nil
    ) async throws {
        var payload: [String: AnyEncodable] = [
            "user_id": AnyEncodable(userId),
            "type": AnyEncodable(type.rawValue),
            "title": AnyEncodable(title),
            "body": AnyEncodable(message),
            "is_read": AnyEncodable(false),
            "push_sent": AnyEncodable(false),
            "sent_at": AnyEncodable(ISO8601DateFormatter().string(from: Date()))
        ]
        
        if let refId = referenceId {
            payload["reference_id"] = AnyEncodable(refId.uuidString)
        }
        
        if let refType = referenceType {
            payload["reference_type"] = AnyEncodable(refType)
        }
        
        try await supabase.database
            .from("notifications")
            .insert(payload)
            .execute()
    }
    
    func requestPermission() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        return granted
    }
    
    func subscribeToNotifications() {
        guard let userId = supabase.currentUserId else { return }
        
        // Already subscribed for THIS user — nothing to do.
        if isSubscribed && subscribedUserId == userId { return }
        
        // Subscribed for a different user (e.g. logout → login as someone else):
        // tear down the stale channel before re-binding.
        if let existing = channel {
            channel = nil
            isSubscribed = false
            subscribedUserId = nil
            Task { await supabase.client.removeChannel(existing) }
        }
        
        // Namespace the channel per user so it can't collide across accounts.
        channel = supabase.client.realtimeV2.channel("notifications:\(userId.uuidString)")
        
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
                print("✅ [LMS Staff] NotificationService: Realtime subscribed for user \(userId)")

                for await insert in insertions {
                    let record = insert.record
                    if let title = record["title"]?.stringValue,
                       let body = record["body"]?.stringValue {
                        
                        // Prevent triggering local push if the message was sent by the current user
                        if (title == "New Message" || title == "New Message from Borrower") && self.recentlySentMessages.contains(body) {
                            print("🔔 [LMS Staff] Ignored echo notification for sent message: \(body)")
                            continue
                        }
                        
                        self.triggerLocalPush(title: title, body: body)
                    }
                }
            } catch {
                print("❌ [LMS Staff] NotificationService: Failed to subscribe — \(error)")
                isSubscribed = false
                subscribedUserId = nil
            }
        }
    }
    
    private func triggerLocalPush(title: String, body: String) {
        print("📣 [LMS Staff] triggerLocalPush called with Title: \(title), Body: \(body)")
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "LMS_NOTIFICATION"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Local notification error: \(error.localizedDescription)")
            }
        }
    }
    
    func unsubscribe() {
        if let channel = channel {
            Task {
                await supabase.client.removeChannel(channel)
                self.channel = nil
                self.isSubscribed = false
                self.subscribedUserId = nil
                print("⏹ [LMS Staff] NotificationService: Realtime unsubscribed")
            }
        }
    }
}
