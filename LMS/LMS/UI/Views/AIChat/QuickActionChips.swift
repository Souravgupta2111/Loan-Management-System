//
//  QuickActionChips.swift
//  LMS
//
//  Horizontal scrollable chips for quick AI questions
//

import SwiftUI

struct QuickActionChips: View {
    let actions: [String]
    let onActionTap: (String) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(actions, id: \.self) { action in
                    Button {
                        onActionTap(action)
                    } label: {
                        Text(action)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(Color(hex: "#2D8B4E"))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(hex: "#E8F5EC"))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color(hex: "#2D8B4E").opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
