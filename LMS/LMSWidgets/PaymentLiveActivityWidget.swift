//
//  PaymentLiveActivityWidget.swift
//  LMSWidgets
//
//  Live Activity UI for an in-progress EMI payment (lock screen banner +
//  Dynamic Island). Uses the shared PaymentActivityAttributes type, which must
//  also be a member of this widget target (see the note in that file).
//

import WidgetKit
import SwiftUI
import ActivityKit

private func stageIcon(_ stage: String) -> String {
    switch stage {
    case "confirmed": return "checkmark.circle.fill"
    case "failed": return "xmark.circle.fill"
    default: return "arrow.triangle.2.circlepath"
    }
}

private func stageColor(_ stage: String) -> Color {
    switch stage {
    case "confirmed": return .green
    case "failed": return .red
    default: return .blue
    }
}

struct PaymentLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PaymentActivityAttributes.self) { context in
            // Lock screen / banner presentation
            HStack(spacing: 14) {
                Image(systemName: stageIcon(context.state.stage))
                    .font(.title2)
                    .foregroundStyle(stageColor(context.state.stage))
                    .symbolEffect(.pulse, isActive: context.state.stage == "processing")
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.title).font(.subheadline.weight(.semibold))
                    Text(context.state.message).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(inr(context.attributes.amount)).font(.headline)
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.35))
            .activitySystemActionForegroundColor(.primary)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: stageIcon(context.state.stage))
                        .font(.title2)
                        .foregroundStyle(stageColor(context.state.stage))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(inr(context.attributes.amount)).font(.headline)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.title).font(.caption.weight(.semibold)).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.message).font(.caption).foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: stageIcon(context.state.stage))
                    .foregroundStyle(stageColor(context.state.stage))
            } compactTrailing: {
                Text(inrCompact(context.attributes.amount)).font(.caption2.weight(.semibold))
            } minimal: {
                Image(systemName: stageIcon(context.state.stage))
                    .foregroundStyle(stageColor(context.state.stage))
            }
        }
    }
}
