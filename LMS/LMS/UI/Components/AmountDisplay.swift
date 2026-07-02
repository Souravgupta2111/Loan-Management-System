import SwiftUI

struct AmountDisplay: View {
    let amount: Double
    let style: AmountStyle
    var color: Color? = nil

    enum AmountStyle {
        case hero   
        case large
        case card
    }

    var body: some View {
        let parts = formattedParts
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(parts.integer)
                .font(integerFont)
                .foregroundColor(color ?? .textPrimary)
            Text(parts.decimal)
                .font(.amountSuper)
                .foregroundColor(color?.opacity(0.8) ?? .textSecondary)
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
