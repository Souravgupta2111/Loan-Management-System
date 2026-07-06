import SwiftUI

struct ChatRoomView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ChatViewModel
    
    init(applicationId: UUID, currentUserId: UUID, officerId: UUID) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(
            applicationId: applicationId,
            currentUserId: currentUserId,
            officerId: officerId
        ))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: Spacing.md) {
                        if viewModel.isLoading {
                            ProgressView()
                                .padding(.top, Spacing.xl)
                        } else if viewModel.messages.isEmpty {
                            Text("No messages yet. Send a message to your loan officer.")
                                .font(.bodyRegular)
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.top, Spacing.xxl)
                        } else {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message, isCurrentUser: message.sender_id == viewModel.currentUserId)
                                    .id(message.id)
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let lastId = viewModel.messages.last?.id {
                        withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                    }
                }
                .onAppear {
                    if let lastId = viewModel.messages.last?.id {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
            .background(Color.appBackground)
            
            // Input Area
            VStack {
                Divider()
                HStack(alignment: .bottom, spacing: Spacing.sm) {
                    TextField("Type a message...", text: $viewModel.newMessageText, axis: .vertical)
                        .font(.bodyRegular)
                        .padding(10)
                        .background(Color.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .lineLimit(1...5)
                    
                    Button {
                        Task { await viewModel.sendMessage() }
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(viewModel.newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.textSecondary : Color.accentGreen)
                            .clipShape(Circle())
                    }
                    .disabled(viewModel.newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
            }
            .background(Color.surface)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar { ToolbarItem(placement: .topBarLeading) { GlassBackButton { dismiss() } } }
        .navigationTitle("Message Officer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await viewModel.loadMessages()
        }
    }
}

private struct MessageBubble: View {
    let message: ChatService.MessageResponse
    let isCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isCurrentUser { Spacer() }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.bodyRegular)
                    .foregroundColor(isCurrentUser ? .white : .textPrimary)
                    .padding(12)
                    .background(isCurrentUser ? Color.accentGreen : Color.surface)
                    .clipShape(ChatBubbleShape(isCurrentUser: isCurrentUser))
                    .shadow(color: .black.opacity(isCurrentUser ? 0 : 0.05), radius: 2, x: 0, y: 1)
                
                Text(formatTime(message.sent_at))
                    .font(.caption2)
                    .foregroundColor(.textTertiary)
                    .padding(.horizontal, 4)
            }
            
            if !isCurrentUser { Spacer() }
        }
    }
    
    private func formatTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: isoString) else { return "" }
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        return timeFormatter.string(from: date)
    }
}

private struct ChatBubbleShape: Shape {
    let isCurrentUser: Bool
    
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 16
        var path = Path()
        
        path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius), radius: radius, startAngle: Angle(degrees: -90), endAngle: Angle(degrees: 0), clockwise: false)
        
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - (isCurrentUser ? 0 : radius)))
        
        if isCurrentUser {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.maxY))
        } else {
            path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius), radius: radius, startAngle: Angle(degrees: 0), endAngle: Angle(degrees: 90), clockwise: false)
        }
        
        path.addLine(to: CGPoint(x: rect.minX + (isCurrentUser ? radius : 0), y: rect.maxY))
        
        if isCurrentUser {
            path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius), radius: radius, startAngle: Angle(degrees: 90), endAngle: Angle(degrees: 180), clockwise: false)
        } else {
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - radius))
        }
        
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius), radius: radius, startAngle: Angle(degrees: 180), endAngle: Angle(degrees: 270), clockwise: false)
        
        return path
    }
}
