import Foundation
import Supabase

@MainActor
class ChatService {
    static let shared = ChatService()
    private init() {}
    
    struct MessageInsert: Encodable {
        let application_id: UUID
        let sender_id: UUID
        let receiver_id: UUID
        let content: String
    }
    
    struct MessageResponse: Decodable, Identifiable, Equatable {
        let id: UUID
        let application_id: UUID
        let sender_id: UUID
        let receiver_id: UUID
        let content: String
        let sent_at: String
        let is_read: Bool
    }
    
    func fetchMessages(applicationId: UUID) async throws -> [MessageResponse] {
        return try await SupabaseManager.shared.client
            .from("messages")
            .select()
            .eq("application_id", value: applicationId)
            .order("sent_at", ascending: true)
            .execute().value
    }
    
    func sendMessage(applicationId: UUID, senderId: UUID, receiverId: UUID, content: String) async throws {
        try await SupabaseManager.shared.client
            .from("messages")
            .insert(MessageInsert(
                application_id: applicationId,
                sender_id: senderId,
                receiver_id: receiverId,
                content: content
            ))
            .execute()
    }
    
    func markAsRead(messageIds: [UUID]) async throws {
        for id in messageIds {
            struct Update: Encodable { let is_read: Bool }
            try await SupabaseManager.shared.client
                .from("messages")
                .update(Update(is_read: true))
                .eq("id", value: id)
                .execute()
        }
    }
}
