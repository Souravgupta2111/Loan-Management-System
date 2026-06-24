import SwiftUI

/// EMI Calculator (US-06) — standalone tool, accessible from tab bar.
struct EMICalculatorView: View {
    @State private var amount: Double = 1000000
    @State private var tenureMonths: Double = 120
    @State private var interestRate: Double = 8.5
    @State private var interestType: String = "Reducing"
    
    let interestTypes = ["Reducing", "Fixed", "Compound", "Floating"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xxl) {
                    // MARK: - EMI Result Hero
                    VStack(spacing: Spacing.sm) {
                        Text("Estimated Monthly EMI")
                            .font(.label)
                            .foregroundColor(.textSecondary)

                        AmountDisplay(amount: calculateEMI(), style: .hero)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xxl)
                    .background(
                        LinearGradient(
                            colors: [Color.gradientMintStart, Color.gradientMintEnd],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Corner.xl))

                    // MARK: - Sliders
                    VStack(spacing: Spacing.xl) {
                        
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Interest Type")
                                .font(.label)
                                .foregroundColor(.textSecondary)
                            Picker("Interest Type", selection: $interestType) {
                                ForEach(interestTypes, id: \.self) { type in
                                    Text(type).tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    
                        // Loan Amount
                        sliderSection(
                            title: "Loan Amount",
                            valueText: "₹\(formatIndian(amount))",
                            value: $amount,
                            range: 50000...20000000,
                            step: 50000
                        )

                        // Tenure
                        sliderSection(
                            title: "Tenure",
                            valueText: "\(Int(tenureMonths)) months (\(Int(tenureMonths / 12)) yrs)",
                            value: $tenureMonths,
                            range: 6...360,
                            step: 6
                        )

                        // Interest Rate
                        sliderSection(
                            title: "Interest Rate (p.a.)",
                            valueText: String(format: "%.1f%%", interestRate),
                            value: $interestRate,
                            range: 5.0...24.0,
                            step: 0.1
                        )
                    }
                    .padding(Spacing.xl)
                    .background(Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Corner.xl))
                    .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)

                    // MARK: - Summary Cards
                    HStack(spacing: Spacing.md) {
                        StatCard("Total Interest", value: "₹\(formatIndian(calculateTotalInterest()))", backgroundColor: .accentAmberBg)
                        StatCard("Total Amount", value: "₹\(formatIndian(amount + calculateTotalInterest()))", backgroundColor: .accentGreenBg)
                    }

                    // MARK: - Breakdown
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Breakdown")
                            .font(.cardTitle)
                            .foregroundColor(.textPrimary)

                        breakdownRow("Principal", value: formatIndian(amount), color: .accentGreen)
                        breakdownRow("Total Interest", value: formatIndian(calculateTotalInterest()), color: .accentAmber)
                        Divider()
                        breakdownRow("Total Payable", value: formatIndian(amount + calculateTotalInterest()), color: .textPrimary)
                    }
                    .padding(Spacing.xl)
                    .background(Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Corner.xl))
                    .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, 100)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("EMI Calculator")
        }
    }

    // MARK: - Slider Section
    private func sliderSection(title: String, valueText: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(title)
                    .font(.label)
                    .foregroundColor(.textSecondary)
                Spacer()
                Text(valueText)
                    .font(.bodyLarge)
                    .foregroundColor(.textPrimary)
            }
            Slider(value: value, in: range, step: step)
                .tint(.accentGreen)
        }
    }

    // MARK: - Breakdown Row
    private func breakdownRow(_ label: String, value: String, color: Color) -> some View {
        HStack {
            HStack(spacing: Spacing.sm) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(.bodyRegular)
                    .foregroundColor(.textSecondary)
            }
            Spacer()
            Text("₹\(value)")
                .font(.bodyLarge)
                .foregroundColor(.textPrimary)
        }
    }

    // MARK: - Calculations
    private func calculateEMI() -> Double {
        let p = amount
        let r = (interestRate / 12) / 100
        let n = tenureMonths

        if r == 0 { return p / n }
        
        if interestType == "Fixed" {
            let totalInterest = p * (interestRate / 100) * (n / 12)
            return (p + totalInterest) / n
        } else if interestType == "Compound" {
            let amountAfterCompound = p * pow(1 + (interestRate / 100), (n / 12))
            return amountAfterCompound / n
        } else {
            // Reducing or Floating uses standard EMI formula
            let emi = p * r * pow(1 + r, n) / (pow(1 + r, n) - 1)
            return emi
        }
    }

    private func calculateTotalInterest() -> Double {
        let emi = calculateEMI()
        return (emi * tenureMonths) - amount
    }

    private func formatIndian(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
}
