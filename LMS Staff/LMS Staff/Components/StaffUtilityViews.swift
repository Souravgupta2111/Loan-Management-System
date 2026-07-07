import SwiftUI

/// Empty state placeholder with icon, message, and optional action button
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: StaffSpacing.xxl) {
            Spacer()

            Image(systemName: icon)
                .font(.title.weight(.light))
                .foregroundColor(.staffTextTertiary)
                .frame(width: 100, height: 100)
                .background(Color.staffSurfaceLight)
                .clipShape(Circle())

            VStack(spacing: StaffSpacing.sm) {
                Text(title)
                    .font(.staffCardTitle)
                    .foregroundColor(.staffTextPrimary)

                Text(message)
                    .font(.staffBodyRegular)
                    .foregroundColor(.staffTextSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }

            if let actionTitle = actionTitle, let action = action {
                StaffButton(title: actionTitle, style: .outline, isFullWidth: false, action: action)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Loading state overlay
struct StaffLoadingView: View {
    var message: String = "Loading..."

    var body: some View {
        VStack(spacing: StaffSpacing.lg) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .staffAccent))
                .scaleEffect(1.2)

            Text(message)
                .font(.staffCaption)
                .foregroundColor(.staffTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.staffBackground.opacity(0.8))
    }
}

/// Section header with optional action button
struct StaffSectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.staffSectionTitle)
                .foregroundColor(.staffTextPrimary)

            Spacer()

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(actionTitle)
                            .font(.staffCaption)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundColor(.staffAccent)
                }
            }
        }
    }
}

/// Amount display with Indian formatting
struct StaffAmountDisplay: View {
    let amount: Double
    var style: AmountStyle = .regular
    var prefix: String = "₹"

    enum AmountStyle {
        case hero
        case large
        case regular
        case caption
    }

    var body: some View {
        Text("\(prefix)\(formattedAmount)")
            .font(amountFont)
            .foregroundColor(.staffTextPrimary)
    }

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_IN")
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }

    private var amountFont: Font {
        switch style {
        case .hero:    return .staffHeroAmount
        case .large:   return .staffLargeAmount
        case .regular: return .staffBody
        case .caption: return .staffCaption
        }
    }
}
