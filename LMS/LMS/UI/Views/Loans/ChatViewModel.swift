import Foundation
import SwiftUI
import Combine
import Supabase

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatService.MessageResponse] = []
    @Published var newMessageText: String = ""
    @Published var isLoading = false
    
    let applicationId: UUID
    let currentUserId: UUID
    let officerId: UUID
    
    private var channel: RealtimeChannelV2?
    
    init(applicationId: UUID, currentUserId: UUID, officerId: UUID) {
        self.applicationId = applicationId
        self.currentUserId = currentUserId
        self.officerId = officerId
    }
    
    func loadMessages() async {
        isLoading = true
        do {
            messages = try await ChatService.shared.fetchMessages(applicationId: applicationId)
            setupSubscription()
            markUnreadAsRead()
        } catch {
            print("Failed to load messages: \(error)")
        }
        isLoading = false
    }
     
    private func setupSubscription() {
        guard channel == nil else { return }
        let client = SupabaseManager.shared.client
        
        channel = client.realtimeV2.channel("public:messages:app_\(applicationId.uuidString)")
        
        Task {
            guard let channel = channel else { return }
            let changes = await channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "messages",
                filter: "application_id=eq.\(applicationId.uuidString)"
            )
            
            await channel.subscribe()
            
            for await insert in changes {
                do {
                    let data = try JSONSerialization.data(withJSONObject: insert.record, options: [])
                    let newMsg = try JSONDecoder().decode(ChatService.MessageResponse.self, from: data)
                    await MainActor.run {
                        if !self.messages.contains(where: { $0.id == newMsg.id }) {
                            self.messages.append(newMsg)
                            self.markUnreadAsRead()
                        }
                    }
                } catch {
                    print("Error decoding realtime message: \(error)")
                }
            }
        }
    }
    
    func sendMessage() async {
        let text = newMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // Optimistic UI update could be done here
        newMessageText = ""
        
        do {
            try await ChatService.shared.sendMessage(
                applicationId: applicationId,
                senderId: currentUserId,
                receiverId: officerId,
                content: text
            )
            // It will be fetched by realtime subscription
        } catch {
            print("Failed to send message: \(error)")
            // Optionally restore text if failed
            newMessageText = text
        }
    }
    
    private func markUnreadAsRead() {
        let unreadIds = messages.filter { !$0.is_read && $0.receiver_id == currentUserId }.map { $0.id }
        guard !unreadIds.isEmpty else { return }
        Task {
            do {
                try await ChatService.shared.markAsRead(messageIds: unreadIds)
                // update local state
                for i in 0..<messages.count {
                    if unreadIds.contains(messages[i].id) {
                        let msg = messages[i]
                        messages[i] = ChatService.MessageResponse(
                            id: msg.id, application_id: msg.application_id, sender_id: msg.sender_id,
                            receiver_id: msg.receiver_id, content: msg.content, sent_at: msg.sent_at, is_read: true
                        )
                    }
                }
            } catch {
                print("Failed to mark messages as read: \(error)")
            }
        }
    }
    
    deinit {
        let currentChannel = channel
        Task {
            if let ch = currentChannel {
                await SupabaseManager.shared.client.realtimeV2.removeChannel(ch)
            }
        }
    }
}
