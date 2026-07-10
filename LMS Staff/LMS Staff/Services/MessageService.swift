import Foundation
import Supabase

class MessageService {
    
    static let shared = MessageService()
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    func fetchMessages(forApplicationId applicationId: UUID) async throws -> [Message] {
        let messages: [Message] = try await supabase.database
            .from("messages")
            .select()
            .eq("application_id", value: applicationId)
            .order("sent_at", ascending: true)
            .execute()
            .value
        return messages
    }
    
    func sendMessage(
        applicationId: UUID,
        receiverId: UUID,
        content: String,
        type: MessageType = .text,
        attachmentUrl: String? = nil
    ) async throws -> Message {
        guard let senderId = supabase.currentUserId else {
            throw NSError(domain: "MessageService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unauthorized"])
        }
        
        await MainActor.run {
            NotificationService.shared.recentlySentMessages.insert(content)
        }
        
        Task {
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            await MainActor.run {
                NotificationService.shared.recentlySentMessages.remove(content)
            }
        }
        
        let payload: [String: AnyEncodable] = [
            "application_id": AnyEncodable(applicationId),
            "sender_id": AnyEncodable(senderId),
            "receiver_id": AnyEncodable(receiverId),
            "content": AnyEncodable(content),
            "message_type": AnyEncodable(type.rawValue),
            "attachment_url": AnyEncodable(attachmentUrl ?? ""),
            "is_read": AnyEncodable(false),
            "is_deleted_by_sender": AnyEncodable(false),
            "is_deleted_by_receiver": AnyEncodable(false),
            "sent_at": AnyEncodable(ISO8601DateFormatter().string(from: Date()))
        ]
        
        let sentMessage: Message = try await supabase.database
            .from("messages")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
            
        try? await NotificationService.shared.createNotification(
            userId: receiverId,
            title: "New Message",
            message: content,
            type: .general,
            referenceId: applicationId,
            referenceType: "loan_applications"
        )
            
        return sentMessage
    }
    
    func subscribeToMessages(forApplicationId applicationId: UUID, onUpdate: @escaping () -> Void) -> RealtimeChannelV2 {
        let channel = supabase.client.realtimeV2.channel("public:messages:\(applicationId.uuidString)")
        
        Task {
            let insertions = await channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "messages",
                filter: "application_id=eq.\(applicationId.uuidString)"
            )
            await channel.subscribe()
            for await _ in insertions {
                onUpdate()
            }
        }
        
        return channel
    }
    
    func unsubscribe(_ channel: RealtimeChannelV2) async {
        await supabase.client.realtimeV2.removeChannel(channel)
    }
    
    func markAsRead(messageId: UUID) async throws {
        try await supabase.database
            .from("messages")
            .update(["is_read": AnyEncodable(true)])
            .eq("id", value: messageId)
            .execute()
    }
    
    func deleteMessage(messageId: UUID, isSender: Bool) async throws {
        let field = isSender ? "is_deleted_by_sender" : "is_deleted_by_receiver"
        try await supabase.database
            .from("messages")
            .update([field: AnyEncodable(true)])
            .eq("id", value: messageId)
            .execute()
    }
}
