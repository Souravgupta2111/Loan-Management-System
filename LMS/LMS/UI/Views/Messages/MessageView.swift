import SwiftUI

struct MessageView: View {
    @Environment(\.dismiss) private var dismiss
    let applicationId: UUID
    let receiverId: UUID
    let officerName: String?
    
    @StateObject private var messageService: MessageService
    @State private var messageText: String = ""
    
    init(applicationId: UUID, receiverId: UUID, officerName: String? = nil) {
        self.applicationId = applicationId
        self.receiverId = receiverId
        self.officerName = officerName
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
                    .textInputAutocapitalization(.sentences)
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
            .liquidGlass(cornerRadius: 24)
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.sm)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar { ToolbarItem(placement: .topBarLeading) { GlassBackButton { dismiss() } } }
        .navigationTitle(officerName != nil ? "Chat with \(officerName!.split(separator: " ").first ?? "")" : "Chat with Officer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .background(
            LinearGradient(
                colors: [Color(hex: "#E7EFE5"), Color(hex: "#EFF4EA"), Color(hex: "#E7EFE5")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
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
