import Foundation
import UserNotifications
import Supabase

@MainActor
class NotificationService {
    static let shared = NotificationService()
    
    private var channel: RealtimeChannelV2?
    
    private init() {}
    
    func requestPermission() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        return granted
    }
    
    func subscribeToNotifications() {
        guard let userId = SupabaseManager.shared.currentUserId else { return }
        
        channel = SupabaseManager.shared.client.realtimeV2.channel("public:notifications")
        
        Task {
            guard let channel = channel else { return }
            
            let insertions = await channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "notifications",
                filter: "user_id=eq.\(userId.uuidString)"
            )
            
            await channel.subscribe()
            
            for await insert in insertions {
                if let record = insert.record as? [String: Any],
                   let title = record["title"] as? String,
                   let body = record["body"] as? String {
                    await MainActor.run {
                        self.triggerLocalPush(title: title, body: body)
                    }
                }
            }
        }
    }
    
    private func triggerLocalPush(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil) // Deliver immediately
        UNUserNotificationCenter.current().add(request)
    }
    
    func unsubscribe() {
        if let channel = channel {
            Task {
                await SupabaseManager.shared.client.removeChannel(channel)
            }
        }
    }
}
