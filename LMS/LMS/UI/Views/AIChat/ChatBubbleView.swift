//
//  ChatBubbleView.swift
//  LMS
//
//  Reusable chat bubble for user and AI messages
//

import SwiftUI

struct AIAssistantAvatar: View {
    let size: CGFloat
    let iconSize: Font

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.55),
                                    Color.themeGreen.opacity(0.22),
                                    Color.white.opacity(0.08)
                                ],
                                center: .topLeading,
                                startRadius: 2,
                                endRadius: size
                            )
                        )
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.75), lineWidth: 1)
                )
                .overlay(
                    Circle()
                        .stroke(Color.accentGreen.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: Color.accentGreen.opacity(0.18), radius: 8, x: 0, y: 4)

            Image(systemName: "sparkles")
                .font(iconSize)
                .foregroundColor(Color.accentGreen)
        }
    }
}

struct ChatBubbleView: View {
    let message: AIMessage
    var onSpeakTapped: (() -> Void)? = nil
    
    private var isUser: Bool {
        message.role == .user
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if isUser { Spacer() }
            
            if !isUser {
                // AI Avatar
                AIAssistantAvatar(size: 32, iconSize: .subheadline)
                .accessibilityHidden(true)
            }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
                    Text(.init(message.content)) // Render markdown
                        .font(.body)
                        .foregroundColor(isUser ? .white : Color(hex: "#1A1A1A"))
                    
                    if !isUser, let onSpeak = onSpeakTapped {
                        Button {
                            HapticManager.shared.impact(style: .light)
                            onSpeak()
                        } label: {
                            Image(systemName: "speaker.wave.2")
                                .font(.caption)
                                .foregroundColor(Color.accentGreen)
                                .padding(6)
                                .background(Color.white.opacity(0.8))
                                .clipShape(Circle())
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .accessibilityLabel("Read message aloud")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Group {
                        if isUser {
                            Color.accentGreen
                        } else {
                            Color.white.opacity(0.5)
                                .background(.ultraThinMaterial)
                        }
                    }
                )
                .clipShape(ChatBubbleShape(isUser: isUser))
                .overlay(
                    ChatBubbleShape(isUser: isUser)
                        .stroke(Color.white.opacity(isUser ? 0 : 0.6), lineWidth: 1)
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
                                .foregroundColor(Color.accentGreen)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.accentGreenBg)
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
