import SwiftUI

struct CreditScoreView: View {
    let score: Int
    let bureau: String
    
    var body: some View {
        OrganicCard(backgroundColor: .accentDark) {
            VStack(spacing: 24) {
                HStack {
                    Text("Credit Health")
                        .font(.cardTitle)
                        .foregroundColor(.white)
                    Spacer()
                    Text(bureau)
                        .font(.badge)
                        .foregroundColor(.textTertiary)
                }
                
                ZStack {
                    // Background Track
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 16)
                    
                    // Progress Track
                    Circle()
                        .trim(from: 0.0, to: CGFloat(score) / 900.0)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [.accentAmber, .accentGreen]),
                                center: .center,
                                startAngle: .degrees(0),
                                endAngle: .degrees(360)
                            ),
                            style: StrokeStyle(lineWidth: 16, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 1.5), value: score)
                    
                    VStack(spacing: 4) {
                        Text("\(score)")
                            .font(.heroAmount)
                            .foregroundColor(.white)
                        
                        Text(scoreRating)
                            .font(.badge)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(ratingColor.opacity(0.2))
                            .foregroundColor(ratingColor)
                            .clipShape(Capsule())
                    }
                }
                .frame(height: 200)
                .padding(.vertical, 16)
            }
        }
    }
    
    private var scoreRating: String {
        if score >= 750 { return "Excellent" }
        if score >= 650 { return "Good" }
        if score >= 550 { return "Fair" }
        return "Poor"
    }
    
    private var ratingColor: Color {
        if score >= 750 { return .accentGreen }
        if score >= 650 { return .accentMint }
        if score >= 550 { return .accentAmber }
        return .accentRed
    }
}
