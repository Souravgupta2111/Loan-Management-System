import Foundation
import Supabase
import Combine

@MainActor
class MessageService: ObservableObject {
    @Published var messages: [Message] = []
    
    private var channel: RealtimeChannelV2?
    let applicationId: UUID
    
    init(applicationId: UUID) {
        self.applicationId = applicationId
    }
    
    func fetchMessages() async {
        do {
            struct MessageFetch: Decodable {
                let id: UUID
                let application_id: UUID
                let sender_id: UUID
                let receiver_id: UUID
                let content: String
                let message_type: String
                let attachment_url: String?
                let is_read: Bool
                let sent_at: String?
            }
            
            let fetchResult: [MessageFetch] = try await SupabaseManager.shared.client
                .from("messages")
                .select()
                .eq("application_id", value: applicationId)
                .order("sent_at", ascending: true)
                .execute()
                .value
            
            let formatter = Formatter.iso8601
            
            self.messages = fetchResult.map { m in
                let sentAtDate = m.sent_at != nil ? formatter.date(from: m.sent_at!) : nil
                return Message(
                    id: m.id,
                    applicationId: m.application_id,
                    senderId: m.sender_id,
                    receiverId: m.receiver_id,
                    content: m.content,
                    messageType: MessageType(rawValue: m.message_type) ?? .text,
                    attachmentUrl: m.attachment_url,
                    isRead: m.is_read,
                    readAt: nil,
                    sentAt: sentAtDate,
                    isDeletedBySender: false,
                    isDeletedByReceiver: false
                )
            }
        } catch {
            print("Failed to fetch messages: \(error)")
        }
    }
    
    func subscribeToMessages() {
        channel = SupabaseManager.shared.client.realtimeV2.channel("public:messages")
        
        Task {
            guard let channel = channel else { return }
            
            let insertions = channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "messages",
                filter: .eq("application_id", value: applicationId)
            )
            
            do {
                try await channel.subscribeWithError()

                for await _ in insertions {
                    await self.fetchMessages()
                }
            } catch {
                print("Failed to subscribe to messages: \(error)")
            }
        }
    }
    
    func unsubscribe() {
        if let channel = channel {
            Task {
                await SupabaseManager.shared.client.realtimeV2.removeChannel(channel)
            }
        }
    }
    
    func sendMessage(content: String, receiverId: UUID) async {
        guard let currentUserId = SupabaseManager.shared.currentUserId else { return }
        
        struct MessageInsert: Encodable {
            let application_id: UUID
            let sender_id: UUID
            let receiver_id: UUID
            let content: String
            let message_type: String
        }
        
        let newMsg = MessageInsert(
            application_id: applicationId,
            sender_id: currentUserId,
            receiver_id: receiverId,
            content: content,
            message_type: "text"
        )
        
        do {
            try await SupabaseManager.shared.client
                .from("messages")
                .insert(newMsg)
                .execute()
        } catch {
            print("Failed to send message: \(error)")
        }
    }
}
