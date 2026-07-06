//
//  SmartRecommendationCard.swift
//  LMS
//
//  Pre-qualification card for personalized loan offers
//

import SwiftUI

struct SmartRecommendationCard: View {
    let productName: String
    let maxAmount: Double
    let interestRate: Double
    let onApply: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#E8F5EC"))
                        .frame(width: 40, height: 40)
                    Image(systemName: "sparkle")
                        .font(.body.weight(.bold))
                        .foregroundColor(Color(hex: "#2D8B4E"))
                }
                .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pre-Approved Offer")
                        .font(.caption.weight(.bold))
                        .foregroundColor(Color(hex: "#2D8B4E"))
                        .textCase(.uppercase)
                    
                    Text(productName)
                        .font(.headline)
                        .foregroundColor(Color(hex: "#1A1A1A"))
                }
                Spacer()
            }
            
            Text("Based on your profile, you are eligible for up to **₹\(formatAmount(maxAmount))** at a special rate of **\(String(format: "%.1f", interestRate))% APR**.")
                .font(.subheadline)
                .foregroundColor(Color(hex: "#6B6B6B"))
                .lineSpacing(4)
            
            Button(action: onApply) {
                HStack {
                    Text("Apply Now")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(hex: "#1A1A1A"))
                .cornerRadius(12)
            }
            .accessibilityLabel("Apply for \(productName)")
            .accessibilityHint("Double tap to start the loan application process")
        }
        .padding(16)
        .background(
            LinearGradient(colors: [Color(hex: "#F9FBF9"), Color.white], startPoint: .top, endPoint: .bottom)
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "#2D8B4E").opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color(hex: "#2D8B4E").opacity(0.05), radius: 10, x: 0, y: 4)
    }
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
}
