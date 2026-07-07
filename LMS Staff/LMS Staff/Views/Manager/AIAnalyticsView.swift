//
//  AIAnalyticsView.swift
//  LMS Staff
//
//  Dedicated AI analytics chat interface for Branch Managers
//

import SwiftUI

// MARK: - Staff-side AI Message Model (shared across staff AI views)
struct StaffAIMessage: Identifiable, Equatable {
    let id: UUID
    let conversationId: UUID
    let isUser: Bool
    let content: String
    let createdAt: Date
}

struct AIAnalyticsView: View {
    @State private var messages: [StaffAIMessage] = []
    @State private var currentInput: String = ""
    @State private var isTyping = false
    @State private var conversationId: UUID?
    @State private var errorMessage: String?
    
    private let service = ManagerAIService.shared
    
    private let quickActions = [
        "Give me a complete portfolio summary with NPA breakdown",
        "Which officers have the most pending applications?",
        "Forecast NPA risk for the next quarter",
        "What is this week's collection efficiency trend?"
    ]
    
    private let quickActionLabels = [
        "Portfolio Summary",
        "Officer Performance",
        "NPA Risk Forecast",
        "Collection Trend"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Branch Analytics")
                        .font(.staffTitle)
                        .foregroundColor(.staffTextPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text("Powered by Gemini")
                        .font(.staffCaption)
                        .foregroundColor(.staffTextSecondary)
                }
                Spacer()
                Button(action: clearChat) {
                    Image(systemName: "trash")
                        .foregroundColor(.staffRed)
                }
                .accessibilityLabel("Clear chat history")
            }
            .padding(StaffSpacing.lg)
            .background(Color.staffSurface)
            
            Divider()
            
            // Chat Area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: StaffSpacing.md) {
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.staffCaption)
                                .foregroundColor(.staffRed)
                                .padding()
                                .background(Color.staffRed.opacity(0.1))
                                .cornerRadius(StaffCorner.sm)
                                .accessibilityLabel("Error: \(error)")
                        }
                        
                        ForEach(messages) { message in
                            ManagerChatBubble(message: message)
                                .id(message.id)
                        }
                        
                        if isTyping {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(Color.staffAccent)
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "chart.bar.fill")
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                }
                                
                                Text("Analyzing portfolio data...")
                                    .font(.staffBody)
                                    .foregroundColor(.staffTextSecondary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.staffSurface)
                                    .cornerRadius(StaffCorner.md)
                                
                                Spacer()
                            }
                            .id("typing")
                            .accessibilityLabel("AI is analyzing portfolio data")
                        }
                        
                        Color.clear.frame(height: 10).id("bottom")
                    }
                    .padding(StaffSpacing.lg)
                }
                .onChange(of: messages) { _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                .onChange(of: isTyping) { typing in
                    if typing {
                        withAnimation { proxy.scrollTo("typing", anchor: .bottom) }
                    }
                }
            }
            
            // Quick Actions
            if messages.count <= 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: StaffSpacing.sm) {
                        ForEach(Array(zip(quickActionLabels.indices, quickActionLabels)), id: \.0) { index, label in
                            Button {
                                sendMessage(quickActions[index])
                            } label: {
                                Text(label)
                                    .font(.staffCaption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.staffAccent)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.staffAccent.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            .accessibilityLabel("Quick action: \(label)")
                            .accessibilityHint("Double tap to ask AI about \(label)")
                        }
                    }
                    .padding(.horizontal, StaffSpacing.lg)
                    .padding(.vertical, StaffSpacing.sm)
                }
            }
            
            Divider()
            
            // Input Box
            HStack(spacing: StaffSpacing.md) {
                TextField("Ask for branch insights...", text: $currentInput, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(12)
                    .background(Color.staffSurface)
                    .cornerRadius(StaffCorner.md)
                    .onSubmit { sendMessage() }
                    .accessibilityLabel("Chat input field")
                
                Button {
                    sendMessage()
                } label: {
                    ZStack {
                        Circle()
                            .fill(currentInput.trimmingCharacters(in: .whitespaces).isEmpty ? Color.staffBorder : Color.staffAccent)
                            .frame(width: 44, height: 44)
                        Image(systemName: "arrow.up")
                            .foregroundColor(.white)
                            .font(.headline.weight(.bold))
                    }
                }
                .disabled(currentInput.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Send message")
                .accessibilityHint(currentInput.isEmpty ? "Type a message first" : "Double tap to send your message")
            }
            .padding(StaffSpacing.lg)
            .background(Color.white)
        }
        .background(Color.staffBackground)
        .onAppear {
            if messages.isEmpty {
                let welcome = StaffAIMessage(
                    id: UUID(),
                    conversationId: UUID(),
                    isUser: false,
                    content: "Hello Manager! I'm your AI Analytics Assistant. I have real-time access to your branch's loan portfolio, NPA data, EMI collection metrics, and pending applications. What would you like to analyze?",
                    createdAt: Date()
                )
                messages.append(welcome)
            }
        }
    }
    
    private func sendMessage(_ text: String? = nil) {
        let textToSend = text ?? currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !textToSend.isEmpty, !isTyping else { return }
        
        let userMessage = StaffAIMessage(
            id: UUID(),
            conversationId: conversationId ?? UUID(),
            isUser: true,
            content: textToSend,
            createdAt: Date()
        )
        
        messages.append(userMessage)
        currentInput = ""
        isTyping = true
        errorMessage = nil
        
        // Haptic feedback on send
        HapticManager.shared.impact(style: .light)
        
        Task {
            do {
                let response = try await service.sendMessage(content: textToSend, conversationId: conversationId)
                self.conversationId = response.conversationId
                
                let aiMessage = StaffAIMessage(
                    id: UUID(),
                    conversationId: response.conversationId ?? UUID(),
                    isUser: false,
                    content: response.reply,
                    createdAt: Date()
                )
                
                self.messages.append(aiMessage)
                HapticManager.shared.notification(type: .success)
            } catch {
                self.errorMessage = "Failed to fetch analytics: \(error.localizedDescription)"
                HapticManager.shared.notification(type: .error)
            }
            self.isTyping = false
        }
    }
    
    private func clearChat() {
        messages.removeAll()
        conversationId = nil
        HapticManager.shared.impact(style: .medium)
    }
}

struct ManagerChatBubble: View {
    let message: StaffAIMessage
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if message.isUser { Spacer() }
            
            if !message.isUser {
                ZStack {
                    Circle()
                        .fill(Color.staffAccent)
                        .frame(width: 32, height: 32)
                    Image(systemName: "chart.bar.fill")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .accessibilityHidden(true)
            }
            
            Text(.init(message.content))
                .font(.staffBody)
                .foregroundColor(message.isUser ? .white : .staffTextPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(message.isUser ? Color.staffAccent : Color.staffSurface)
                .clipShape(StaffChatBubbleShape(isUser: message.isUser))
                .accessibilityLabel(message.isUser ? "You said: \(message.content)" : "AI said: \(message.content)")
            
            if !message.isUser { Spacer() }
        }
    }
}

struct StaffChatBubbleShape: Shape {
    let isUser: Bool
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: isUser ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight],
            cornerRadii: CGSize(width: 16, height: 16)
        )
        return Path(path.cgPath)
    }
}
