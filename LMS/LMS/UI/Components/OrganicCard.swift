import SwiftUI

struct OrganicCard<Content: View>: View {
    let backgroundColor: Color
    let content: Content
    
    init(backgroundColor: Color = .surface, @ViewBuilder content: () -> Content) {
        self.backgroundColor = backgroundColor
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(24)
            .background(backgroundColor)
            // Asymmetric corner radii to give an organic, premium feel
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 32,
                    bottomLeadingRadius: 24,
                    bottomTrailingRadius: 32,
                    topTrailingRadius: 24
                )
            )
            .shadow(color: Color.black.opacity(0.04), radius: 24, x: 0, y: 12)
    }
}
