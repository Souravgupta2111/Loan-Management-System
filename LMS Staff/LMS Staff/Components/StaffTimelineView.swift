import SwiftUI

/// Chronological action timeline for approval history (US-44)
struct StaffTimelineView: View {
    let items: [TimelineItem]

    struct TimelineItem: Identifiable {
        let id: UUID
        let action: String
        let actor: String
        let role: String
        let remarks: String?
        let timestamp: Date
        let icon: String
        let color: Color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(alignment: .top, spacing: StaffSpacing.lg) {
                    // Timeline line + dot
                    VStack(spacing: 0) {
                        Circle()
                            .fill(item.color)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .fill(item.color.opacity(0.3))
                                    .frame(width: 24, height: 24)
                            )

                        if index < items.count - 1 {
                            Rectangle()
                                .fill(Color.staffBorder)
                                .frame(width: 2)
                                .frame(minHeight: 50)
                        }
                    }
                    .frame(width: 24)

                    // Content
                    VStack(alignment: .leading, spacing: StaffSpacing.sm) {
                        HStack {
                            Image(systemName: item.icon)
                                .font(.subheadline)
                                .foregroundColor(item.color)

                            Text(item.action)
                                .font(.staffBody)
                                .fontWeight(.semibold)
                                .foregroundColor(.staffTextPrimary)

                            Spacer()

                            Text(formatDate(item.timestamp))
                                .font(.staffCaption)
                                .foregroundColor(.staffTextTertiary)
                        }

                        HStack(spacing: StaffSpacing.sm) {
                            Text(item.actor)
                                .font(.staffCaption)
                                .foregroundColor(.staffTextSecondary)

                            StaffRoleBadge(role: item.role)
                        }

                        if let remarks = item.remarks, !remarks.isEmpty {
                            Text(remarks)
                                .font(.staffBodyRegular)
                                .foregroundColor(.staffTextSecondary)
                                .padding(StaffSpacing.md)
                                .background(Color.staffSurfaceMuted)
                                .clipShape(RoundedRectangle(cornerRadius: StaffCorner.sm))
                        }
                    }
                    .padding(.bottom, index < items.count - 1 ? StaffSpacing.lg : 0)
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy, HH:mm"
        return formatter.string(from: date)
    }
}
