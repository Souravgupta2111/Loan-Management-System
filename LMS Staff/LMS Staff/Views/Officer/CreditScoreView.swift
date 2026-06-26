//
//  CreditScoreView.swift
//  LMS Staff
//
//  Credit score dial gauge widget and risk breakdown visualization.
//

import SwiftUI

struct CreditScoreGauge: View {
    let score: Int
    
    var body: some View {
        VStack(spacing: StaffSpacing.xs) {
            ZStack {
                // Background Track ring
                Circle()
                    .trim(from: 0.1, to: 0.9)
                    .stroke(Color.staffBorder, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .frame(width: 160, height: 160)
                    .rotationEffect(Angle(degrees: 90))
                
                // Color track based on rating score
                Circle()
                    .trim(from: 0.1, to: fillPercent)
                    .stroke(
                        gradientForScore(score),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(Angle(degrees: 90))
                    .animation(.easeOut(duration: 1.0), value: score)
                
                VStack(spacing: 2) {
                    Text("\(score)")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(.staffTextPrimary)
                    
                    Text(riskLabel(score))
                        .font(.staffCaption)
                        .fontWeight(.bold)
                        .foregroundColor(colorForScore(score))
                }
            }
            .frame(height: 180)
        }
    }
    
    // MARK: - Calculations
    
    private var fillPercent: Double {
        // Map credit score (300 to 900) into circular trim (0.1 to 0.9)
        let minScore = 300.0
        let maxScore = 900.0
        let pct = (Double(score) - minScore) / (maxScore - minScore)
        let trimmed = 0.1 + (pct * 0.8) // map 0.0-1.0 to 0.1-0.9
        return min(max(trimmed, 0.1), 0.9)
    }
    
    private func colorForScore(_ score: Int) -> Color {
        if score >= 750 { return .staffGreen }
        if score >= 650 { return .staffAccent }
        if score >= 550 { return .staffAmber }
        return .staffRed
    }
    
    private func gradientForScore(_ score: Int) -> AngularGradient {
        let baseColor = colorForScore(score)
        return AngularGradient(
            gradient: Gradient(colors: [baseColor.opacity(0.8), baseColor]),
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360)
        )
    }
    
    private func riskLabel(_ score: Int) -> String {
        if score >= 750 { return "EXCELLENT" }
        if score >= 650 { return "GOOD" }
        if score >= 550 { return "AVERAGE" }
        return "HIGH RISK"
    }
}

struct CreditScoreView: View {
    let score: Int
    let bureau: String
    
    var body: some View {
        StaffCard {
            VStack(alignment: .leading, spacing: StaffSpacing.md) {
                Text("Credit Bureau Details")
                    .font(.staffTitle)
                    .foregroundColor(.staffTextPrimary)
                
                Divider()
                
                HStack(spacing: StaffSpacing.xl) {
                    CreditScoreGauge(score: score)
                        .padding(.vertical, StaffSpacing.md)
                    
                    VStack(alignment: .leading, spacing: StaffSpacing.md) {
                        CreditFactorRow(icon: "shield.check", title: "Identity Match", subtitle: "PAN/Aadhaar details match exactly")
                        CreditFactorRow(icon: "clock.arrow.circlepath", title: "Payment History", subtitle: "No historical defaults or delays")
                        CreditFactorRow(icon: "exclamationmark.circle", title: "Inquiries", subtitle: "2 hard inquiries in the past 6 months")
                    }
                }
            }
        }
    }
}

struct CreditFactorRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: StaffSpacing.md) {
            Image(systemName: icon)
                .foregroundColor(.staffAccent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.staffBody)
                    .fontWeight(.bold)
                    .foregroundColor(.staffTextPrimary)
                Text(subtitle)
                    .font(.staffCaption)
                    .foregroundColor(.staffTextSecondary)
            }
        }
    }
}
