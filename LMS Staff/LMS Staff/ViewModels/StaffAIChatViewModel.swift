//
//  StaffAIChatViewModel.swift
//  LMS
//
//  ViewModel for managing state of the AI Chat interface
//

import SwiftUI
import Combine

@MainActor
final class StaffAIChatViewModel: ObservableObject {
    @Published var messages: [AIMessage] = []
    @Published var currentInput: String = ""
    @Published var isTyping = false
    @Published var errorMessage: String?
    
    private var conversationId: UUID?
    
    init() {
        // Initial setup if needed
    }
    
    func startNewConversationIfNeeded() async {
        // Add a welcome message from the AI if empty
        if messages.isEmpty {
            let welcome = AIMessage(
                id: UUID(),
                conversationId: UUID(), // temporary for local display
                role: .assistant,
                content: "Hi! I'm your AI Assistant. I can help you summarize your portfolio risk, review pending applications, or analyze market trends. How can I help you today?",
                suggestedActions: nil,
                createdAt: Date()
            )
            messages.append(welcome)
        }
    }
    
    func sendMessage(_ text: String? = nil) {
        let textToSend = text ?? currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !textToSend.isEmpty, !isTyping else { return }
        
        // Add user message to UI immediately
        let userMessage = AIMessage(
            id: UUID(),
            conversationId: conversationId ?? UUID(),
            role: .user,
            content: textToSend,
            suggestedActions: nil,
            createdAt: Date()
        )
        
        messages.append(userMessage)
        currentInput = ""
        isTyping = true
        errorMessage = nil
        
        // Call backend
        Task {
            do {
                let response = try await StaffAIChatService.shared.sendMessage(
                    content: textToSend,
                    conversationId: conversationId
                )
                
                self.conversationId = response.conversationId
                
                let aiMessage = AIMessage(
                    id: UUID(),
                    conversationId: response.conversationId,
                    role: .assistant,
                    content: response.reply,
                    suggestedActions: nil,
                    createdAt: Date()
                )
                
                self.messages.append(aiMessage)
                
            } catch {
                print("Edge function failed: \(error)")
                let errorMessage = AIMessage(
                    id: UUID(),
                    conversationId: self.conversationId ?? UUID(),
                    role: .assistant,
                    content: "Sorry, I couldn't process that right now. (Error: \(error.localizedDescription))",
                    suggestedActions: nil,
                    createdAt: Date()
                )
                self.messages.append(errorMessage)
            }
            
            self.isTyping = false
        }
    }
    
    func clearChat() {
        messages.removeAll()
        conversationId = nil
        Task {
            await startNewConversationIfNeeded()
        }
    }
}
