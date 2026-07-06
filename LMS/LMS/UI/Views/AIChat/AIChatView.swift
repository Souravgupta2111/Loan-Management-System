//
//  AIChatView.swift
//  LMS
//
//  Main View for the AI Financial Advisor chatbot — with full accessibility
//

import SwiftUI

struct AIChatView: View {
    @StateObject private var viewModel = AIChatViewModel()
    @Environment(\.dismiss) var dismiss
    @Environment(\.sizeCategory) var sizeCategory
    @State private var showFinancialHealthCard = true
    
    // Quick questions tailored for Borrower
    private let quickActions = [
        "Am I eligible for a personal loan?",
        "When is my next EMI due?",
        "How can I improve my credit score?",
        "Show my upcoming EMI schedule"
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                
                // Chat history
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // Top Financial Health Card removed by request
                                
                            if let error = viewModel.errorMessage {
                                Text(error)
                                    .font(.footnote)
                                    .foregroundColor(.red)
                                    .padding()
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(8)
                                    .accessibilityLabel("Error: \(error)")
                            }
                            
                            ForEach(viewModel.messages) { message in
                                ChatBubbleView(message: message)
                                    .id(message.id)
                            }
                            
                            if viewModel.isTyping {
                                HStack {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: "#1A1A1A"))
                                            .frame(width: 32, height: 32)
                                        Image(systemName: "sparkles")
                                            .font(.subheadline)
                                            .foregroundColor(Color(hex: "#2D8B4E"))
                                    }
                                    .accessibilityHidden(true)
                                    
                                    TypingIndicatorView()
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(Color(hex: "#F5F5F5"))
                                        .clipShape(ChatBubbleShape(isUser: false))
                                    
                                    Spacer()
                                }
                                .id("typing")
                                .accessibilityLabel("AI is thinking")
                            }
                            
                            Color.clear
                                .frame(height: 10)
                                .id("bottom")
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages) { _ in
                        withAnimation {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                    .onChange(of: viewModel.isTyping) { isTyping in
                        if isTyping {
                            withAnimation {
                                proxy.scrollTo("typing", anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Quick Actions (only show if no messages or user hasn't typed)
                if viewModel.messages.count <= 1 && viewModel.currentInput.isEmpty {
                    QuickActionChips(actions: quickActions) { action in
                        HapticManager.shared.impact(style: .light)
                        viewModel.sendMessage(action)
                    }
                    .padding(.vertical, 8)
                }
                
                // Input Area
                // Input Area
                VStack(spacing: 0) {
                    HStack(alignment: .bottom, spacing: 12) {
                        TextField("Type a message...", text: $viewModel.currentInput, axis: .vertical)
                            .lineLimit(1...5)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(hex: "#F5F6F5"))
                            .cornerRadius(22)
                            .onSubmit {
                                viewModel.sendMessage()
                            }
                            .accessibilityLabel("Message input")
                            .accessibilityHint("Type your question for the AI advisor")
                        
                        Button {
                            HapticManager.shared.impact(style: .medium)
                            viewModel.sendMessage()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "#008A45"))
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .offset(x: -1, y: 1)
                            }
                        }
                        .disabled(viewModel.currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(viewModel.currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
                        .accessibilityLabel("Send message")
                        .accessibilityHint(viewModel.currentInput.isEmpty ? "Type a message first" : "Double tap to send your message")
                    }
                    .padding(8)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.4))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white, lineWidth: 1.5)
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color(hex: "#E7EFE5"))
            }
            .background(Color(hex: "#E7EFE5").ignoresSafeArea())
            .navigationTitle("AI Financial Advisor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(Color(hex: "#1A1A1A"))
                            .font(.title3.weight(.medium))
                    }
                    .accessibilityLabel("Close AI Chat")
                }
                

            }
        }
        .task {
            await viewModel.startNewConversationIfNeeded()
        }
    }
}

struct TypingIndicatorView: View {
    @State private var step = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.gray)
                    .frame(width: 6, height: 6)
                    .scaleEffect(step == index ? 1.2 : 0.8)
                    .opacity(step == index ? 1.0 : 0.5)
                    .animation(.easeInOut(duration: 0.3).repeatForever(), value: step)
            }
        }
        .accessibilityHidden(true)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { timer in
                step = (step + 1) % 3
            }
        }
    }
}

#Preview {
    AIChatView()
}
