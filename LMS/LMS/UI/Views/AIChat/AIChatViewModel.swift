//
//  AIChatViewModel.swift
//  LMS
//
//  ViewModel for managing state of the AI Chat interface
//

import SwiftUI
import Combine

@MainActor
final class AIChatViewModel: ObservableObject {
    @Published var messages: [AIMessage] = []
    @Published var currentInput: String = ""
    @Published var isTyping = false
    @Published var errorMessage: String?
    
    private var conversationId: UUID?
    private var context: BorrowerContext?
    
    init() {
        // Initial setup if needed
    }
    
    func startNewConversationIfNeeded() async {
        guard context == nil else { return } // Already loaded
        
        do {
            context = try await AIChatService.shared.buildBorrowerContext()
            
            // Add a welcome message from the AI
            let welcome = AIMessage(
                id: UUID(),
                conversationId: UUID(), // temporary for local display
                role: .assistant,
                content: "Hi! I'm your personal AI Financial Advisor. I can help you understand your loans, check eligibility, or give tips on improving your credit score. How can I help you today?",
                suggestedActions: nil,
                createdAt: Date()
            )
            messages.append(welcome)
            
        } catch {
            print("Failed to build context: \(error)")
            errorMessage = "Failed to load your financial data. Some AI features may be limited."
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
                // Ensure we have context
                if context == nil {
                    context = try await AIChatService.shared.buildBorrowerContext()
                }
                
                guard let ctx = context else {
                    throw URLError(.cannotParseResponse)
                }
                
                let response = try await AIChatService.shared.sendMessage(
                    content: textToSend,
                    conversationId: conversationId,
                    context: ctx
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
