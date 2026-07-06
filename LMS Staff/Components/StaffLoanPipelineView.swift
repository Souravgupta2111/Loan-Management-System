import SwiftUI

/// Chronological stage-based loan pipeline timeline (mirrors borrower timeline)
struct StaffLoanPipelineView: View {
    let stages: [PipelineStage]
    
    struct PipelineStage: Identifiable {
        let id = UUID()
        let title: String
        let date: String
        let remarks: String?
        let status: StageStatus
    }
    
    enum StageStatus {
        case completed
        case active
        case pending
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                HStack(alignment: .top, spacing: 14) {
                    // Node + connector line
                    VStack(spacing: 0) {
                        nodeView(for: stage)
                        
                        if index < stages.count - 1 {
                            ZStack(alignment: .bottom) {
                                Rectangle()
                                    .fill(Color.staffBorder)
                                    .frame(width: 2)
                                
                                Rectangle()
                                    .fill(Color.staffGreen)
                                    .frame(width: 2)
                                    .scaleEffect(y: stage.status == .completed ? 1.0 : 0.0, anchor: .bottom)
                            }
                            .frame(width: 28)
                            .frame(minHeight: 38)
                        }
                    }
                    
                    // Content
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stage.title)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(textColor(for: stage))
                        
                        if !stage.date.isEmpty {
                            Text(stage.date)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.staffTextTertiary)
                        }
                        
                        if let remarks = stage.remarks, !remarks.isEmpty {
                            Text(remarks)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(remarksColor(for: stage))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(remarksBgColor(for: stage))
                                .cornerRadius(6)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.top, 3)
                    .padding(.bottom, index == stages.count - 1 ? 0 : 20)
                    
                    Spacer(minLength: 0)
                }
            }
        }
    }
    
    // MARK: - Node View
    
    @ViewBuilder
    private func nodeView(for stage: PipelineStage) -> some View {
        ZStack {
            switch stage.status {
            case .completed:
                Circle()
                    .fill(Color.staffGreen)
                    .frame(width: 28, height: 28)
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                
            case .active:
                let titleLower = stage.title.lowercased()
                if titleLower.contains("reject") {
                    Circle()
                        .stroke(Color.staffRed, lineWidth: 2)
                        .background(Circle().fill(Color.staffRed.opacity(0.1)))
                        .frame(width: 28, height: 28)
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.staffRed)
                } else if titleLower.contains("document") || titleLower.contains("back") {
                    Circle()
                        .stroke(Color.staffOrange, lineWidth: 2)
                        .background(Circle().fill(Color.staffOrange.opacity(0.1)))
                        .frame(width: 28, height: 28)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.staffOrange)
                } else {
                    Circle()
                        .stroke(Color.staffGreen, lineWidth: 2)
                        .background(Circle().fill(Color.white))
                        .frame(width: 28, height: 28)
                    Circle()
                        .fill(Color.staffGreen)
                        .frame(width: 12, height: 12)
                }
                
            case .pending:
                Circle()
                    .stroke(Color.staffBorder, lineWidth: 2)
                    .background(Circle().fill(Color.white))
                    .frame(width: 28, height: 28)
                Circle()
                    .fill(Color.staffBorder)
                    .frame(width: 8, height: 8)
            }
        }
    }
    
    // MARK: - Style Helpers
    
    private func textColor(for stage: PipelineStage) -> Color {
        switch stage.status {
        case .completed, .active: return .staffTextPrimary
        case .pending: return .staffTextTertiary
        }
    }
    
    private func remarksColor(for stage: PipelineStage) -> Color {
        let titleLower = stage.title.lowercased()
        if (titleLower.contains("document") || titleLower.contains("back")) && stage.status == .active {
            return .staffOrange
        } else if titleLower.contains("reject") && stage.status == .active {
            return .staffRed
        } else {
            return .staffGreen
        }
    }
    
    private func remarksBgColor(for stage: PipelineStage) -> Color {
        let titleLower = stage.title.lowercased()
        if (titleLower.contains("document") || titleLower.contains("back")) && stage.status == .active {
            return .staffOrange.opacity(0.1)
        } else if titleLower.contains("reject") && stage.status == .active {
            return .staffRed.opacity(0.1)
        } else {
            return .staffSurfaceMuted
        }
    }
}
