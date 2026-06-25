import SwiftUI

/// EMI Calculator (US-06) — standalone tool, accessible from tab bar.
struct EMICalculatorView: View {
    @State private var amount: Double = 10000
    @State private var tenureMonths: Double = 6
    @State private var interestRate: Double = 5.0
    @State private var interestType: String = "Reducing"
    @State private var loanProducts: [LoanProduct] = []
    @State private var selectedProduct: LoanProduct?
    @State private var isLoadingProducts = true
    @State private var isUsingGeneralCalculator = false
    @State private var showAmortizationSchedule = false
    
    // Inline editing state
    @State private var isEditingAmount = false
    @State private var isEditingTenure = false
    @State private var isEditingInterest = false
    @State private var editingText = ""
    @FocusState private var focusedField: EditableField?
    
    enum EditableField: Hashable {
        case amount, tenure, interest
    }
    
    @Environment(\.dismiss) var dismiss

    private let fallbackAmountRange: ClosedRange<Double> = 10000...100000000
    private let fallbackTenureRange: ClosedRange<Double> = 6...360
    private let fallbackInterestRateRange: ClosedRange<Double> = 5.0...24.0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Custom Header
                HStack {
//                    Button(action: {
//                        dismiss()
//                    }) {
//                        Image(systemName: "chevron.left")
//                            .font(.system(size: 20, weight: .semibold))
//                            .foregroundColor(Color(hex: "#0A4F8B"))
//                    }
                    Spacer()
                    Text("EMI Calculator")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Spacer()
                    // Spacer balancing the left button
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20))
                        .foregroundColor(.clear)
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                // MARK: - Hero EMI Amount
                VStack(spacing: 4) {
                    AmountDisplay(amount: calculateEMI(), style: .hero)
                    Text("Estimated Monthly EMI")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.textSecondary)
                }
                .padding(.bottom, 24)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.xl) {
                        inputFieldsCard
                        summaryCards
                        breakdownCard
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.bottom, 100)
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAmortizationSchedule) {
                CalculatorAmortizationSheet(
                    amount: amount,
                    tenureMonths: Int(tenureMonths),
                    interestRate: interestRate,
                    emi: calculateEMI()
                )
            }
            .task {
                await fetchLoanProducts()
            }
        }
    }

    // MARK: - Sections
    private var inputFieldsCard: some View {
        VStack(spacing: Spacing.xl) {
            loanTypeSelector
            sliderSection(
                title: "Loan Amount",
                value: $amount,
                range: amountRange,
                step: 50000,
                field: .amount,
                isEditing: isEditingAmount,
                displayText: "₹\(formatIndian(amount))",
                formatForEdit: { String(Int($0)) },
                parseFromEdit: { Double($0.filter { $0.isNumber }) },
                onToggleEdit: { isEditingAmount = $0 }
            )
            sliderSection(
                title: "Tenure",
                value: $tenureMonths,
                range: tenureRange,
                step: 1,
                field: .tenure,
                isEditing: isEditingTenure,
                displayText: "\(Int(tenureMonths)) months (\(Int(tenureMonths / 12)) yrs)",
                formatForEdit: { String(Int($0)) },
                parseFromEdit: { Double($0.filter { $0.isNumber }) },
                onToggleEdit: { isEditingTenure = $0 }
            )
            sliderSection(
                title: "Interest Rate (p.a.)",
                value: $interestRate,
                range: interestRateRange,
                step: 0.1,
                field: .interest,
                isEditing: isEditingInterest,
                displayText: String(format: "%.1f%%", interestRate),
                formatForEdit: { String(format: "%.1f", $0) },
                parseFromEdit: { Double($0.filter { $0.isNumber || $0 == "." }) },
                onToggleEdit: { isEditingInterest = $0 }
            )
        }
        .padding(Spacing.xl)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Corner.xl))
        .shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: Corner.xl)
                .stroke(Color.borderSubtle, lineWidth: 1)
        )
    }

    private var loanTypeSelector: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Loan Type")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.textSecondary)

            Menu {
                loanTypeMenuItems
            } label: {
                HStack {
                    Text(loanTypeTitle)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(selectedProduct == nil && !isUsingGeneralCalculator ? .textSecondary : .textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textSecondary)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, 14)
                .background(Color(hex: "#EFF3FA"))
                .clipShape(RoundedRectangle(cornerRadius: Corner.md))
                .contentShape(Rectangle())
            }
            .disabled(isLoadingProducts)
        }
    }

    @ViewBuilder
    private var loanTypeMenuItems: some View {
        if isLoadingProducts {
            Button("Loading loan types") {}
                .disabled(true)
        } else {
            Button("General EMI Calculator") {
                selectedProduct = nil
                useGeneralCalculator()
            }

            ForEach(loanProducts) { product in
                Button(product.name) {
                    selectedProduct = product
                    applyProductDefaults(product)
                }
            }
        }
    }



    private var summaryCards: some View {
        HStack(spacing: Spacing.md) {
            StatCard("Total Interest", value: "₹\(formatIndian(calculateTotalInterest()))", backgroundColor: Color(hex: "#FFF8EE"))
            StatCard("Total Amount", value: "₹\(formatIndian(amount + calculateTotalInterest()))", backgroundColor: Color(hex: "#EEF9F4"))
        }
    }

    private var breakdownCard: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("Breakdown")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.textPrimary)
                .padding(.bottom, Spacing.xs)

            breakdownRow("Principal", value: formatIndian(amount), color: .accentGreen)
            breakdownRow("Total Interest", value: formatIndian(calculateTotalInterest()), color: .accentAmber)
            breakdownRow("Total Payable", value: formatIndian(amount + calculateTotalInterest()), color: Color(hex: "#D1D1D6"))

            Button(action: {
                showAmortizationSchedule = true
            }) {
                HStack {
                    Text("View Amortization Schedule")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "#0A4F8B"))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: "#0A4F8B"))
                }
            }
            .buttonStyle(.plain)
            .padding(.top, Spacing.xs)

        }
        .padding(Spacing.xl)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Corner.xl))
        .shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: Corner.xl)
                .stroke(Color.borderSubtle, lineWidth: 1)
        )
    }

    // MARK: - Product Loading
    @MainActor
    private func fetchLoanProducts() async {
        isLoadingProducts = true
        do {
            let products = try await LoanService.shared.fetchActiveProducts()
            loanProducts = products
            if let first = products.first {
                selectedProduct = first
                isUsingGeneralCalculator = false
                applyProductDefaults(first)
            } else {
                selectedProduct = nil
                useGeneralCalculator()
            }
        } catch {
            print("Failed to fetch loan products for EMI calculator: \(error)")
            loanProducts = []
            selectedProduct = nil
            useGeneralCalculator()
        }
        isLoadingProducts = false
    }

    private func applyProductDefaults(_ product: LoanProduct) {
        isUsingGeneralCalculator = false
        amount = product.minAmount
        tenureMonths = Double(product.minTenureMonths)
        interestRate = product.minInterestRate
        interestType = product.supportedInterestTypes.first?.displayName ?? "Reducing"
    }

    private func useGeneralCalculator() {
        isUsingGeneralCalculator = true
        amount = fallbackAmountRange.lowerBound
        tenureMonths = fallbackTenureRange.lowerBound
        interestRate = fallbackInterestRateRange.lowerBound
        interestType = "Reducing"
    }

    // MARK: - Slider Section
    private func sliderSection(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        field: EditableField,
        isEditing: Bool,
        displayText: String,
        formatForEdit: @escaping (Double) -> String,
        parseFromEdit: @escaping (String) -> Double?,
        onToggleEdit: @escaping (Bool) -> Void
    ) -> some View {
        let isFixedValue = range.lowerBound == range.upperBound
        let sliderRange = isFixedValue ? range.lowerBound...(range.lowerBound + step) : range

        let minLabel: String
        let maxLabel: String
        if title.contains("Amount") {
            minLabel = "Min: ₹\(formatIndian(range.lowerBound))"
            maxLabel = "Max: ₹\(formatIndian(range.upperBound))"
        } else if title.contains("Tenure") {
            minLabel = "Min: \(Int(range.lowerBound)) mo"
            maxLabel = "Max: \(Int(range.upperBound)) mo"
        } else {
            minLabel = "Min: \(String(format: "%.1f%%", range.lowerBound))"
            maxLabel = "Max: \(String(format: "%.1f%%", range.upperBound))"
        }

        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.textSecondary)
                Spacer()

                if isEditing {
                    TextField("", text: $editingText)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(field == .interest ? .decimalPad : .numberPad)
                        .focused($focusedField, equals: field)
                        .frame(width: 140)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#EFF3FA"))
                        .clipShape(RoundedRectangle(cornerRadius: Corner.sm))
                        .onSubmit {
                            commitEdit(value: value, range: range, step: step, parseFromEdit: parseFromEdit)
                            onToggleEdit(false)
                        }
                } else {
                    Text(displayText)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#EFF3FA"))
                        .clipShape(RoundedRectangle(cornerRadius: Corner.sm))
                        .onTapGesture {
                            editingText = formatForEdit(value.wrappedValue)
                            onToggleEdit(true)
                            focusedField = field
                        }
                }
            }
            Slider(value: value, in: sliderRange, step: step)
                .tint(.accentGreen)
                .disabled(isFixedValue)
            
            HStack {
                Text(minLabel)
                Spacer()
                Text(maxLabel)
            }
            .font(.system(size: 12, weight: .regular))
            .foregroundColor(.textTertiary)
        }
        .onChange(of: focusedField) { _, newFocus in
            // When focus leaves this field, commit and close editing
            if newFocus != field && isEditing {
                commitEdit(value: value, range: range, step: step, parseFromEdit: parseFromEdit)
                onToggleEdit(false)
            }
        }
    }

    /// Parses the editing text, clamps to range, snaps to step, and writes the value.
    private func commitEdit(value: Binding<Double>, range: ClosedRange<Double>, step: Double, parseFromEdit: @escaping (String) -> Double?) {
        if let parsed = parseFromEdit(editingText) {
            let clamped = clamp(parsed, to: range)
            // Snap to step
            let snapped = (clamped / step).rounded() * step
            value.wrappedValue = clamp(snapped, to: range)
        }
        editingText = ""
    }

    // MARK: - Breakdown Row
    private func breakdownRow(_ label: String, value: String, color: Color) -> some View {
        HStack {
            HStack(spacing: Spacing.sm) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.textSecondary)
            }
            Spacer()
            Text("₹\(value)")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.textPrimary)
        }
    }

    // MARK: - Calculations
    private var loanTypeTitle: String {
        if isLoadingProducts {
            return "Loading loan types..."
        }
        if let selectedProduct {
            return selectedProduct.name
        }
        return "General EMI Calculator"
    }

    private var amountRange: ClosedRange<Double> {
        guard let product = selectedProduct else { return fallbackAmountRange }
        return product.minAmount...product.maxAmount
    }

    private var tenureRange: ClosedRange<Double> {
        guard let product = selectedProduct else { return fallbackTenureRange }
        return Double(product.minTenureMonths)...Double(product.maxTenureMonths)
    }

    private var interestRateRange: ClosedRange<Double> {
        guard let product = selectedProduct else { return fallbackInterestRateRange }
        return product.minInterestRate...product.maxInterestRate
    }

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

    private func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

// MARK: - Amortization Schedule Sheet View
struct CalculatorAmortizationSheet: View {
    let amount: Double
    let tenureMonths: Int
    let interestRate: Double
    let emi: Double
    
    @Environment(\.dismiss) var dismiss
    @State private var viewMode: ViewMode = .yearly
    
    enum ViewMode: String, CaseIterable {
        case yearly = "Yearly"
        case monthly = "Monthly"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Custom Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(hex: "#0A4F8B"))
                    }
                    Spacer()
                    Text("Amortization Schedule")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Spacer()
                    // Balance spacer
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18))
                        .foregroundColor(.clear)
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, 16)
                .padding(.bottom, 16)
                
                // MARK: - Segmented Picker
                Picker("View Mode", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, 16)
                
                // MARK: - Table Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.xl) {
                        // Table Card
                        VStack(spacing: 0) {
                            // Table Header
                            tableHeaderRow
                            
                            Divider()
                                .background(Color.border)
                            
                            // Table Rows
                            let items = viewMode == .yearly ? generateYearlySchedule() : generateMonthlySchedule()
                            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                                tableRow(item: item, isYearly: viewMode == .yearly)
                                
                                if index < items.count - 1 {
                                    Divider()
                                        .background(Color.borderSubtle)
                                        .padding(.leading, Spacing.lg)
                                }
                            }
                        }
                        .background(Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Corner.lg))
                        .overlay(
                            RoundedRectangle(cornerRadius: Corner.lg)
                                .stroke(Color.border, lineWidth: 0.5)
                        )
                        
                        // MARK: - Loan Overview Card
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text("LOAN OVERVIEW")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.textSecondary)
                                .tracking(0.5)
                            
                            HStack {
                                Text("Total Interest")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.textPrimary)
                                Spacer()
                                Text("₹\(formatIndian(calculateTotalInterest()))")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color(hex: "#D94040"))
                            }
                            
                            HStack {
                                Text("Total Principal")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.textPrimary)
                                Spacer()
                                Text("₹\(formatIndian(amount))")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color(hex: "#1B6B3A"))
                            }
                        }
                        .padding(Spacing.xl)
                        .background(Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Corner.lg))
                        .overlay(
                            RoundedRectangle(cornerRadius: Corner.lg)
                                .stroke(Color.border, lineWidth: 0.5)
                        )
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.bottom, 40)
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
    
    // MARK: - Table Header
    private var tableHeaderRow: some View {
        HStack(spacing: 0) {
            Text(viewMode == .yearly ? "YEAR" : "MONTH")
                .frame(width: 50, alignment: .leading)
            Text("OPENING BALANCE")
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text("INTEREST")
                .frame(width: 100, alignment: .trailing)
            Text("PRINCIPAL")
                .frame(width: 100, alignment: .trailing)
        }
        .font(.system(size: 11, weight: .bold))
        .foregroundColor(Color(hex: "#0A4F8B"))
        .tracking(0.3)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 12)
        .background(Color(hex: "#EFF3FA"))
    }
    
    // MARK: - Table Row
    private func tableRow(item: ScheduleItem, isYearly: Bool) -> some View {
        HStack(spacing: 0) {
            Text("\(item.installmentNumber)")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.textPrimary)
                .frame(width: 50, alignment: .leading)
            
            Text("₹\(formatIndian(item.openingBalance))")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.textPrimary)
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            Text("₹\(formatIndian(item.interestComponent))")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "#1B6B3A"))
                .frame(width: 100, alignment: .trailing)
            
            Text("₹\(formatIndian(item.principalComponent))")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.textPrimary)
                .frame(width: 100, alignment: .trailing)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 14)
    }
    
    // MARK: - Data Model
    struct ScheduleItem {
        let installmentNumber: Int
        let openingBalance: Double
        let principalComponent: Double
        let interestComponent: Double
        let totalEmi: Double
        let closingBalance: Double
    }
    
    // MARK: - Monthly Schedule Generator
    private func generateMonthlySchedule() -> [ScheduleItem] {
        var items: [ScheduleItem] = []
        var remainingPrincipal = amount
        let r = (interestRate / 12) / 100
        
        for i in 1...tenureMonths {
            let interest = remainingPrincipal * r
            var principal = emi - interest
            if principal > remainingPrincipal || i == tenureMonths {
                principal = remainingPrincipal
            }
            let closing = max(0, remainingPrincipal - principal)
            
            items.append(ScheduleItem(
                installmentNumber: i,
                openingBalance: remainingPrincipal,
                principalComponent: principal,
                interestComponent: interest,
                totalEmi: principal + interest,
                closingBalance: closing
            ))
            remainingPrincipal = closing
        }
        
        return items
    }
    
    // MARK: - Yearly Schedule Generator
    private func generateYearlySchedule() -> [ScheduleItem] {
        let monthlyItems = generateMonthlySchedule()
        var yearlyItems: [ScheduleItem] = []
        
        let totalYears = Int(ceil(Double(tenureMonths) / 12.0))
        
        for year in 1...totalYears {
            let startMonth = (year - 1) * 12
            let endMonth = min(year * 12, tenureMonths)
            
            guard startMonth < monthlyItems.count else { break }
            
            let yearMonths = Array(monthlyItems[startMonth..<min(endMonth, monthlyItems.count)])
            
            let yearInterest = yearMonths.reduce(0.0) { $0 + $1.interestComponent }
            let yearPrincipal = yearMonths.reduce(0.0) { $0 + $1.principalComponent }
            let openingBalance = yearMonths.first?.openingBalance ?? 0
            let closingBalance = yearMonths.last?.closingBalance ?? 0
            
            yearlyItems.append(ScheduleItem(
                installmentNumber: year,
                openingBalance: openingBalance,
                principalComponent: yearPrincipal,
                interestComponent: yearInterest,
                totalEmi: yearPrincipal + yearInterest,
                closingBalance: closingBalance
            ))
        }
        
        return yearlyItems
    }
    
    // MARK: - Helpers
    private func calculateTotalInterest() -> Double {
        return (emi * Double(tenureMonths)) - amount
    }
    
    private func formatIndian(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
}
