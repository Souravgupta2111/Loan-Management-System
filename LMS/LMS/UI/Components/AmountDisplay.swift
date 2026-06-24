import SwiftUI

/// Amount Display (design.md §3 Amount Display Pattern)
/// Splits integer and decimal parts with superscript styling.
struct AmountDisplay: View {
    let amount: Double
    let style: AmountStyle

    enum AmountStyle {
        case hero    // 48pt
        case large   // 34pt
        case card    // 22pt
    }

    var body: some View {
        let parts = formattedParts
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(parts.integer)
                .font(integerFont)
                .foregroundColor(.textPrimary)
            Text(parts.decimal)
                .font(.amountSuper)
                .foregroundColor(.textSecondary)
                .baselineOffset(baselineOffset)
        }
    }

    private var integerFont: Font {
        switch style {
        case .hero:  return .heroAmount
        case .large: return .largeAmount
        case .card:  return .cardTitle
        }
    }

    private var baselineOffset: CGFloat {
        switch style {
        case .hero:  return 20
        case .large: return 14
        case .card:  return 8
        }
    }

    private var formattedParts: (integer: String, decimal: String) {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0

        let intPart = Int(amount)
        let decPart = Int(round((amount - Double(intPart)) * 100))

        let intStr = "₹" + (formatter.string(from: NSNumber(value: intPart)) ?? "\(intPart)")
        let decStr = String(format: ".%02d", decPart)

        return (intStr, decStr)
    }
}
