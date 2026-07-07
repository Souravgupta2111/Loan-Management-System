//
//  AICopilotPanel.swift
//  LMS Staff
//
//  AI Copilot bottom sheet/panel for Loan Officers
//

import SwiftUI

struct AICopilotPanel: View {
    let application: ApplicationWithBorrower
    let onUseText: (String) -> Void
    
    @State private var responseText: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private let service = AICopilotService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#1A1A1A"))
                        .frame(width: 32, height: 32)
                    Image(systemName: "sparkles")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "#2D8B4E"))
                }
                
                Text("AI Copilot")
                    .font(.headline)
                    .foregroundColor(Color(hex: "#1A1A1A"))
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                }
            }
            .padding(.bottom, 8)
            
            // Quick Actions
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    CopilotActionButton(title: "Summarize Risk", icon: "shield") {
                        performAction(.summarizeRisk)
                    }
                    CopilotActionButton(title: "Flag Gaps", icon: "exclamationmark.triangle") {
                        performAction(.flagGaps)
                    }
                    CopilotActionButton(title: "Draft Rejection", icon: "xmark.square") {
                        performAction(.draftRejection)
                    }
                    CopilotActionButton(title: "Suggest Questions", icon: "questionmark.bubble") {
                        performAction(.suggestQuestions)
                    }
                }
            }
            
            // Response Area
            if let error = errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            } else if let response = responseText {
                VStack(alignment: .leading, spacing: 12) {
                    Text(.init(response)) // Render markdown
                        .font(.body)
                        .foregroundColor(Color(hex: "#1A1A1A"))
                    
                    HStack {
                        Spacer()
                        
                        Button {
                            onUseText(response)
                        } label: {
                            Text("Use This")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(hex: "#2D8B4E"))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(Color(hex: "#F5F5F5"))
                .cornerRadius(12)
            }
            
            Spacer()
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(24, corners: [.topLeft, .topRight])
        .shadow(color: Color.black.opacity(0.1), radius: 10, y: -5)
    }
    
    private func performAction(_ action: AICopilotService.CopilotAction) {
        isLoading = true
        errorMessage = nil
        responseText = nil
        
        Task {
            do {
                let response = try await service.quickAction(action, app: application)
                self.responseText = response
            } catch {
                self.errorMessage = "Failed to get AI response: \(error.localizedDescription)"
            }
            self.isLoading = false
        }
    }
}

struct CopilotActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.subheadline.weight(.medium))
            .foregroundColor(Color(hex: "#2D8B4E"))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hex: "#E8F5EC"))
            .cornerRadius(8)
        }
    }
}

// Extension for corner radius on specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
