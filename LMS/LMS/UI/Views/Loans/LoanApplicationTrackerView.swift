import SwiftUI

/// Loan Application Tracker View
struct LoanApplicationTrackerView: View {
    let status: String
    
    // Stages: Draft, Submitted, Under Review, Approved, Disbursed
    private let stages = ["Submitted", "Under Review", "Approved", "Disbursed"]
    
    var currentStageIndex: Int {
        switch status.lowercased() {
        case "submitted": return 0
        case "under_review": return 1
        case "approved": return 2
        case "disbursed": return 3
        default: return 0
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            Text("Application Status")
                .font(.cardTitle)
                .foregroundColor(.textPrimary)
            
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(stages.enumerated()), id: \.offset) { index, stage in
                    HStack(alignment: .top, spacing: Spacing.md) {
                        // Indicator Column
                        VStack(spacing: 0) {
                            // Circle
                            ZStack {
                                Circle()
                                    .fill(circleColor(for: index))
                                    .frame(width: 24, height: 24)
                                
                                if index <= currentStageIndex {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            
                            // Connecting Line (except last)
                            if index < stages.count - 1 {
                                Rectangle()
                                    .fill(lineColor(for: index))
                                    .frame(width: 2, height: 40)
                            }
                        }
                        
                        // Text Column
                        VStack(alignment: .leading, spacing: 4) {
                            Text(stage)
                                .font(.bodyLarge)
                                .foregroundColor(index <= currentStageIndex ? .textPrimary : .textSecondary)
                            
                            if index == currentStageIndex {
                                Text("Current step")
                                    .font(.caption2)
                                    .foregroundColor(.accentGreen)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
            }
        }
        .padding(Spacing.xl)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Corner.xl))
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
    }
    
    private func circleColor(for index: Int) -> Color {
        if index <= currentStageIndex { return .accentGreen }
        return .textSecondary.opacity(0.2)
    }
    
    private func lineColor(for index: Int) -> Color {
        if index < currentStageIndex { return .accentGreen }
        return .border
    }
}
