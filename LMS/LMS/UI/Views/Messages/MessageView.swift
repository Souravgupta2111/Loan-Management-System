import SwiftUI

struct MessageView: View {
    let applicationId: UUID
    let receiverId: UUID
    
    @StateObject private var messageService: MessageService
    @State private var messageText: String = ""
    
    init(applicationId: UUID, receiverId: UUID) {
        self.applicationId = applicationId
        self.receiverId = receiverId
        _messageService = StateObject(wrappedValue: MessageService(applicationId: applicationId))
    }
    
    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: Spacing.md) {
                        ForEach(messageService.messages) { message in
                            MessageRow(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(Spacing.md)
                }
                .onChange(of: messageService.messages) { _ in
                    if let last = messageService.messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            HStack(spacing: Spacing.sm) {
                TextField("Type a message...", text: $messageText)
                    .padding(Spacing.md)
                    .background(Color.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: Corner.md))
                
                Button(action: {
                    let text = messageText
                    messageText = ""
                    Task {
                        await messageService.sendMessage(content: text, receiverId: receiverId)
                    }
                }) {
                    Image(systemName: "paperplane.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(Spacing.md)
                        .background(Color.accentGreen)
                        .clipShape(Circle())
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(Spacing.md)
            .background(Color.surface)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: -5)
        }
        .navigationTitle("Chat with Officer")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.appBackground)
        .task {
            await messageService.fetchMessages()
            messageService.subscribeToMessages()
        }
        .onDisappear {
            messageService.unsubscribe()
        }
    }
}

struct MessageRow: View {
    let message: Message
    
    private var isCurrentUser: Bool {
        message.senderId == SupabaseManager.shared.currentUserId
    }
    
    var body: some View {
        HStack {
            if isCurrentUser { Spacer() }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.bodyRegular)
                    .padding(Spacing.md)
                    .background(isCurrentUser ? Color.accentGreen : Color.surface)
                    .foregroundColor(isCurrentUser ? .white : .textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: Corner.lg))
                
                if let sentAt = message.sentAt {
                    Text(sentAt, style: .time)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }
            
            if !isCurrentUser { Spacer() }
        }
    }
}
