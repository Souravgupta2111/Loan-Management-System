//
//  NotificationService.swift
//  LMS Staff
//
//  Service for managing user notifications.
//

import Foundation
import Supabase

class NotificationService {
    
    static let shared = NotificationService()
    private let supabase = SupabaseManager.shared
    
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
}
