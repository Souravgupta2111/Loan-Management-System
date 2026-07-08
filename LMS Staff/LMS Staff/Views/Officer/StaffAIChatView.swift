//
//  AIChatView.swift
//  LMS
//
//  Main View for the AI Financial Advisor chatbot — with full accessibility
//

import SwiftUI

struct StaffAIChatView: View {
    @StateObject private var viewModel = StaffAIChatViewModel()
    @StateObject private var speechService = SpeechService()
    @Environment(\.sizeCategory) var sizeCategory
    
    // Quick questions tailored for Staff (Officers & Managers)
    private let quickActions = [
        "Summarize my active portfolio risk",
        "Show applications pending my review",
        "Analyze latest market trends",
        "Draft an approval recommendation"
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                
                // Chat history
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            
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
                                ChatBubbleView(message: message, onSpeakTapped: {
                                    if speechService.isSpeaking {
                                        speechService.stopSpeaking()
                                    } else {
                                        speechService.speak(message.content)
                                    }
                                })
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
                                            .foregroundColor(Color.staffAccent)
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
                
                // Voice Recording Indicator (Tiny text above input)
                if speechService.isListening {
                    Text(speechService.transcribedText.isEmpty ? "Listening... (Tap mic to stop)" : speechService.transcribedText)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 2)
                        .lineLimit(1)
                        .transition(.opacity)
                }
                
                // Input Area
                VStack(spacing: 0) {
                    HStack(alignment: .bottom, spacing: 8) {
                        // Mic Button (Tap to toggle)
                        Button {
                            HapticManager.shared.impact(style: .medium)
                            if speechService.isListening {
                                let text = speechService.transcribedText
                                speechService.stopListening()
                                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    viewModel.sendMessage(text)
                                }
                            } else {
                                speechService.transcribedText = ""
                                speechService.startListening()
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(speechService.isListening ? Color.red.opacity(0.15) : Color(hex: "#F5F6F5"))
                                    .frame(width: 44, height: 44) // Match Send button dimension
                                
                                Image(systemName: speechService.isListening ? "stop.fill" : "mic")
                                    .font(.system(size: 20))
                                    .foregroundColor(speechService.isListening ? .red : Color.staffAccent)
                            }
                        }
                        .accessibilityLabel(speechService.isListening ? "Stop recording" : "Start recording voice")
                        
                        TextField("Type a message...", text: $viewModel.currentInput, axis: .vertical)
                            .lineLimit(1...5)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.clear) // Clear to blend with capsule
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
                    }
                    .padding(4) // tighter padding so buttons fit inside the capsule nicely
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.8))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white, lineWidth: 1.5)
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .background(Color.staffGradientEnd)
            }
            .background(Color.staffGradientEnd.ignoresSafeArea())
            .navigationTitle("AI Financial Advisor")
            .navigationBarTitleDisplayMode(.inline)
            .accessibleAnimation(.easeInOut(duration: 0.2), value: speechService.isListening)
        }
        .task {
            await viewModel.startNewConversationIfNeeded()
            // If Siri opened us with a question, ask it automatically (once).
            if let question = StaffIntentRouter.shared.consumePrefill()?
                .trimmingCharacters(in: .whitespacesAndNewlines), !question.isEmpty {
                viewModel.sendMessage(question)
            }
        }
        .onDisappear {
            speechService.stopListening()
            speechService.stopSpeaking()
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
    StaffAIChatView()
}
