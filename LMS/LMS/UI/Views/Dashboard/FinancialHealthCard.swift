//
//  FinancialHealthCard.swift
//  LMS
//
//  A compact card showing a calculated financial health score (0-100)
//

import SwiftUI

struct FinancialHealthCard: View {
    let creditScore: Int
    let hasActiveLoans: Bool
    
    // Simple client-side score calculation (for demo purposes)
    private var healthScore: Int {
        // Base 50
        var score = 50
        
        // Credit score contribution (up to +30, down to -20)
        if creditScore > 750 { score += 30 }
        else if creditScore > 700 { score += 20 }
        else if creditScore > 650 { score += 10 }
        else if creditScore < 600 { score -= 10 }
        else if creditScore < 500 { score -= 20 }
        
        // Active loans (could imply good repayment or high debt)
        if hasActiveLoans { score += 5 }
        
        return min(max(score, 0), 100)
    }
    
    private var scoreColor: Color {
        if healthScore >= 70 { return Color.accentGreen } // Green
        if healthScore >= 40 { return Color.orange }
        return Color.red
    }
    
    private var scoreLabel: String {
        if healthScore >= 70 { return "Excellent" }
        if healthScore >= 40 { return "Fair" }
        return "Needs Work"
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Radial Gauge
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                
                Circle()
                    .trim(from: 0, to: CGFloat(healthScore) / 100.0)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.0), value: healthScore)
                
                VStack(spacing: 2) {
                    Text("\(healthScore)")
                        .font(.title3.weight(.bold)).fontDesign(.rounded)
                        .foregroundColor(Color(hex: "#1A1A1A"))
                    Text("/ 100")
                        .font(.caption.weight(.regular))
                        .foregroundColor(Color(hex: "#6B6B6B"))
                }
            }
            .frame(width: 60, height: 60)
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text("Financial Health")
                    .font(.headline)
                    .foregroundColor(Color(hex: "#1A1A1A"))
                
                Text(scoreLabel)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(scoreColor)
                
                Text("Based on your credit profile and loan history.")
                    .font(.caption)
                    .foregroundColor(Color(hex: "#6B6B6B"))
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Financial Health Score")
        .accessibilityValue("\(healthScore) out of 100. \(scoreLabel). Based on your credit profile and loan history.")
    }
}
