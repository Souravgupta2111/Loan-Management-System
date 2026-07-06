import SwiftUI
import Charts

// Mock Data for chart
struct CreditScoreDataPoint: Identifiable {
    let id = UUID()
    let month: String
    let score: Int
}
struct CreditScoreView: View {
    let score: Int
    let bureau: String
    
    let history: [CreditScoreDataPoint] = [
        CreditScoreDataPoint(month: "Jan", score: 680),
        CreditScoreDataPoint(month: "Feb", score: 695),
        CreditScoreDataPoint(month: "Mar", score: 710),
        CreditScoreDataPoint(month: "Apr", score: 720),
        CreditScoreDataPoint(month: "May", score: 720)
    ]
    
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
                
                // Score History Chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("Score History")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Chart {
                        ForEach(history) { point in
                            LineMark(
                                x: .value("Month", point.month),
                                y: .value("Score", point.score)
                            )
                            .foregroundStyle(Color.accentGreen)
                            .interpolationMethod(.catmullRom)
                            
                            PointMark(
                                x: .value("Month", point.month),
                                y: .value("Score", point.score)
                            )
                            .foregroundStyle(Color.accentGreen)
                        }
                    }
                    .chartYScale(domain: 600...800)
                    .frame(height: 120)
                    .chartXAxis {
                        AxisMarks { value in
                            AxisValueLabel()
                                .foregroundStyle(Color.textTertiary)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: [600, 700, 800]) { value in
                            AxisGridLine(stroke: StrokeStyle(dash: [5]))
                                .foregroundStyle(Color.white.opacity(0.1))
                            AxisValueLabel()
                                .foregroundStyle(Color.textTertiary)
                        }
                    }
                }
                .padding(.top, 8)
                
                // AI Tip
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.accentGreen)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI Tip: How to improve")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                        Text("Keep credit utilization under 30% to see a 15-20 point increase in the next 3 months.")
                            .font(.caption)
                            .foregroundColor(.textTertiary)
                            .lineSpacing(4)
                    }
                }
                .padding(16)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
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
