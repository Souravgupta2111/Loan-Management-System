//
//  ChatBubbleView.swift
//  LMS
//
//  Reusable chat bubble for user and AI messages
//

import SwiftUI

struct ChatBubbleView: View {
    let message: AIMessage
    var onSpeakTapped: (() -> Void)? = nil
    @Environment(\.colorScheme) private var colorScheme
    
    private var isUser: Bool {
        message.role == .user
    }

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var messageForeground: Color {
        isUser ? .white : Color(hex: "#1A1A1A")
    }

    private var speakerBackground: Color {
        isDarkMode ? Color.staffSurfaceMuted : Color.white.opacity(0.8)
    }

    private var bubbleBackground: Color {
        if isUser {
            return Color.staffAccent
        }
        return isDarkMode ? Color.staffSurface : Color.white.opacity(0.5)
    }

    private var bubbleStroke: Color {
        if isUser {
            return Color.clear
        }
        return isDarkMode ? Color.staffBorder.opacity(0.65) : Color.white.opacity(0.6)
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if isUser { Spacer() }
            
            if !isUser {
                // AI Avatar
                ZStack {
                    Circle()
                        .fill(Color.staffAccentBg)
                        .frame(width: 32, height: 32)
                    Image(systemName: "sparkles")
                        .font(.subheadline)
                        .foregroundColor(Color.staffAccent)
                }
                .accessibilityHidden(true)
            }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
                    Text(.init(message.content)) // Render markdown
                        .font(.body)
                        .foregroundColor(messageForeground)
                    
                    if !isUser, let onSpeak = onSpeakTapped {
                        Button {
                            HapticManager.shared.impact(style: .light)
                            onSpeak()
                        } label: {
                            Image(systemName: "speaker.wave.2")
                                .font(.caption)
                                .foregroundColor(Color.staffAccent)
                                .padding(6)
                                .background(speakerBackground)
                                .clipShape(Circle())
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .accessibilityLabel("Read message aloud")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(bubbleBackground)
                .clipShape(ChatBubbleShape(isUser: isUser))
                .overlay(
                    ChatBubbleShape(isUser: isUser)
                        .stroke(bubbleStroke, lineWidth: 1)
                        .blendMode(.overlay)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1) // subtle shadow like WhatsApp
                .accessibilityLabel(isUser ? "You said: \(message.content)" : "AI said: \(message.content)")
                
                // Suggested Actions
                if let actions = message.suggestedActions, !actions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(actions) { action in
                            Button {
                                // Action handler would go here (e.g. via environment or closure)
                            } label: {
                                HStack {
                                    Text(action.label)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(Color.staffAccent)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.staffAccentBg)
                                .accessibilityLabel("Suggested action: \(action.label)")
                                .accessibilityHint("Double tap to use this action")
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.8, alignment: isUser ? .trailing : .leading)
            
            if !isUser { Spacer(minLength: 20) }
        }
    }
}

struct ChatBubbleShape: Shape {
    let isUser: Bool
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: isUser 
                ? [.topLeft, .topRight, .bottomLeft]
                : [.topLeft, .topRight, .bottomRight],
            cornerRadii: CGSize(width: 16, height: 16)
        )
        return Path(path.cgPath)
    }
}
