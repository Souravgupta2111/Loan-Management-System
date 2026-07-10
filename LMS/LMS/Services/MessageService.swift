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

    private struct MessageRow: Decodable {
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

    private func makeMessage(from m: MessageRow) -> Message {
        let sentAtDate = m.sent_at.flatMap { Formatter.iso8601Flexible.date(from: $0) }
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
    
    func fetchMessages() async {
        do {
            let fetchResult: [MessageRow] = try await SupabaseManager.shared.client
                .from("messages")
                .select()
                .eq("application_id", value: applicationId)
                .order("sent_at", ascending: true)
                .execute()
                .value
            
            self.messages = fetchResult.map { makeMessage(from: $0) }
            
            await self.markUnreadAsRead()
        } catch {
            print("Failed to fetch messages: \(error)")
        }
    }
    
    func markUnreadAsRead() async {
        guard let currentUserId = SupabaseManager.shared.currentUserId else { return }
        let unreadIds = messages.filter { !$0.isRead && $0.receiverId == currentUserId }.map { $0.id }
        guard !unreadIds.isEmpty else { return }
        
        do {
            for id in unreadIds {
                struct Update: Encodable { let is_read: Bool }
                try await SupabaseManager.shared.client
                    .from("messages")
                    .update(Update(is_read: true))
                    .eq("id", value: id)
                    .execute()
            }
            
            for i in 0..<messages.count {
                if unreadIds.contains(messages[i].id) {
                    messages[i].isRead = true
                }
            }
        } catch {
            print("Failed to mark messages as read: \(error)")
        }
    }
    
    func subscribeToMessages() {
        channel = SupabaseManager.shared.client.realtimeV2.channel("messages:\(applicationId.uuidString)")
        
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

                for await insertion in insertions {
                    if let message = Self.message(from: insertion.record) {
                        appendIfNew(message)
                    } else {
                        await self.fetchMessages()
                    }
                }
            } catch {
                print("Failed to subscribe to messages: \(error)")
            }
        }
    }

    private func appendIfNew(_ message: Message) {
        guard !messages.contains(where: { $0.id == message.id }) else { return }
        messages.append(message)
        messages.sort { ($0.sentAt ?? .distantPast) < ($1.sentAt ?? .distantPast) }
        Task { await self.markUnreadAsRead() }
    }

    private static func message(from record: [String: AnyJSON]) -> Message? {
        guard
            let idStr = record["id"]?.stringValue, let id = UUID(uuidString: idStr),
            let appStr = record["application_id"]?.stringValue, let appId = UUID(uuidString: appStr),
            let senderStr = record["sender_id"]?.stringValue, let senderId = UUID(uuidString: senderStr),
            let receiverStr = record["receiver_id"]?.stringValue, let receiverId = UUID(uuidString: receiverStr),
            let content = record["content"]?.stringValue
        else { return nil }

        return Message(
            id: id,
            applicationId: appId,
            senderId: senderId,
            receiverId: receiverId,
            content: content,
            messageType: MessageType(rawValue: record["message_type"]?.stringValue ?? "text") ?? .text,
            attachmentUrl: record["attachment_url"]?.stringValue,
            isRead: record["is_read"]?.boolValue ?? false,
            readAt: nil,
            sentAt: record["sent_at"]?.stringValue.flatMap { Formatter.iso8601Flexible.date(from: $0) },
            isDeletedBySender: false,
            isDeletedByReceiver: false
        )
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
        
        struct NotificationInsert: Encodable {
            let user_id: UUID
            let type: String
            let title: String
            let body: String
            let is_read: Bool
            let push_sent: Bool
            let reference_id: UUID
            let reference_type: String
        }
        
        let newNotification = NotificationInsert(
            user_id: receiverId,
            type: "general",
            title: "New Message from Borrower",
            body: content,
            is_read: false,
            push_sent: false,
            reference_id: applicationId,
            reference_type: "loan_applications"
        )
        
        do {
            try await SupabaseManager.shared.client
                .from("messages")
                .insert(newMsg)
                .execute()
                
            try await SupabaseManager.shared.client
                .from("notifications")
                .insert(newNotification)
                .execute()
        } catch {
            print("Failed to send message: \(error)")
        }
    }
}
