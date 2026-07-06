//
//  NotificationService.swift
//  LMS Staff
//
//  Service for managing user notifications.
//

import Foundation
import Supabase
import UserNotifications

@MainActor
class NotificationService {
    
    static let shared = NotificationService()
    private let supabase = SupabaseManager.shared
    private var channel: RealtimeChannelV2?
    
    private init() {}
    
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
        
        channel = supabase.client.realtimeV2.channel("public:notifications")
        
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

                for await insert in insertions {
                    let record = insert.record
                    if let title = record["title"]?.stringValue,
                       let body = record["body"]?.stringValue {
                        await MainActor.run {
                            self.triggerLocalPush(title: title, body: body)
                        }
                    }
                }
            } catch {
                print("Failed to subscribe to notifications: \(error)")
            }
        }
    }
    
    private func triggerLocalPush(title: String, body: String) {
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
    
    func unsubscribe() {
        if let channel = channel {
            Task {
                await supabase.client.removeChannel(channel)
            }
        }
    }
}
