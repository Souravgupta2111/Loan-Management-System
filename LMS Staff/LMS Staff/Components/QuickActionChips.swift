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
                            .foregroundColor(Color.staffAccent)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.staffAccentBg)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.staffAccent.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
