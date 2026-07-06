import SwiftUI
import Supabase

// MARK: - Temp model for EMI Calculator (avoids eligibility_criteria JSONB decode issue)
private struct EMILoanProduct: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var type: LoanType
    var minAmount: Double
    var maxAmount: Double
    var minTenureMonths: Int
    var maxTenureMonths: Int
    var minInterestRate: Double
    var maxInterestRate: Double
    var supportedInterestTypes: [InterestType]

    enum CodingKeys: String, CodingKey {
        case id, name, type
        case minAmount = "min_amount"
        case maxAmount = "max_amount"
        case minTenureMonths = "min_tenure_months"
        case maxTenureMonths = "max_tenure_months"
        case minInterestRate = "min_interest_rate"
        case maxInterestRate = "max_interest_rate"
        case supportedInterestTypes = "supported_interest_types"
    }
}

/// EMI Calculator (US-06) — standalone tool, accessible from tab bar.
struct EMICalculatorView: View {
    @State private var amount: Double = 10000
    @State private var tenureMonths: Double = 6
    @State private var interestRate: Double = 5.0
    @State private var interestType: String = "Reducing"
    @State private var loanProducts: [EMILoanProduct] = []
    @State private var selectedProduct: EMILoanProduct?
    @State private var isLoadingProducts = true
    @State private var isUsingGeneralCalculator = false
    @State private var showAmortizationSchedule = false

    // Text field state
    @State private var amountText: String = "10000"
    @State private var tenureText: String = "6"
    @State private var interestRateText: String = "5.00"
    @FocusState private var activeField: InputField?
    
    // Validation error states
    @State private var amountError: String? = nil
    @State private var tenureError: String? = nil
    @State private var interestRateError: String? = nil
    
    enum InputField: Hashable {
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
                    Button {
                        dismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 44, height: 44)
                                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Color(hex: "#2D8B4E"))
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()
                    Text("EMI Calculator")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Spacer()
                    // Spacer balancing the left button
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 44, height: 44)
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
            .background(
                LinearGradient(
                    colors: [Color(hex: "#E7EFE5"), Color(hex: "#EFF4EA"), Color(hex: "#E7EFE5")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
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
            .onChange(of: activeField) { _, _ in
                commitFields()
            }
        }
    }

    // MARK: - Sections
    private var inputFieldsCard: some View {
        VStack(spacing: Spacing.xl) {
            loanTypeSelector

            // Loan Amount — full width
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Loan Amount (₹\(formatIndian(amountRange.lowerBound)) - ₹\(formatIndian(amountRange.upperBound)))")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.textSecondary)

                HStack(spacing: 4) {
                    Text("₹")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.textPrimary)
                    TextField("Amount", text: $amountText)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.textPrimary)
                        .keyboardType(.numberPad)
                        .focused($activeField, equals: .amount)
                        .onChange(of: amountText) { _, newValue in
                            let digits = newValue.filter { $0.isNumber || $0 == "-" }
                            if digits.count > 10 {
                                amountText = String(digits.prefix(10))
                            }
                            validateFields()
                        }
                        .onSubmit { commitFields() }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, 14)
                .background(Color.black.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: Corner.md))
                .overlay(
                    RoundedRectangle(cornerRadius: Corner.md)
                        .stroke(amountError != nil ? Color.accentRed : Color.clear, lineWidth: 1)
                )

                if let amountError = amountError {
                    Text(amountError)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.accentRed)
                        .padding(.horizontal, Spacing.xs)
                }
            }

            // Tenure & Interest Rate — side by side
            HStack(alignment: .top, spacing: Spacing.md) {
                // Tenure (Months)
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Tenure (\(Int(tenureRange.lowerBound)) - \(Int(tenureRange.upperBound)) Months)")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.textSecondary)

                    TextField("Months", text: $tenureText)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.textPrimary)
                        .keyboardType(.numberPad)
                        .focused($activeField, equals: .tenure)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, 14)
                        .background(Color.black.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: Corner.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: Corner.md)
                                .stroke(tenureError != nil ? Color.accentRed : Color.clear, lineWidth: 1)
                        )
                        .onChange(of: tenureText) { _, newValue in
                            let digits = newValue.filter { $0.isNumber || $0 == "-" }
                            if digits.count > 4 {
                                tenureText = String(digits.prefix(4))
                            }
                            validateFields()
                        }
                        .onSubmit { commitFields() }

                    if let tenureError = tenureError {
                        Text(tenureError)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.accentRed)
                            .padding(.horizontal, Spacing.xs)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Interest Rate (%)
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Rate (\(String(format: "%.1f", interestRateRange.lowerBound))% - \(String(format: "%.1f", interestRateRange.upperBound))%)")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.textSecondary)

                    HStack(spacing: 4) {
                        TextField("Rate", text: $interestRateText)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.textPrimary)
                            .keyboardType(.decimalPad)
                            .focused($activeField, equals: .interest)
                            .onChange(of: interestRateText) { _, newValue in
                                let filtered = newValue.filter { $0.isNumber || $0 == "." || $0 == "-" }
                                if filtered.count > 6 {
                                    interestRateText = String(filtered.prefix(6))
                                }
                                validateFields()
                            }
                            .onSubmit { commitFields() }
                        Text("%")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, 14)
                    .background(Color.black.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: Corner.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: Corner.md)
                            .stroke(interestRateError != nil ? Color.accentRed : Color.clear, lineWidth: 1)
                    )

                    if let interestRateError = interestRateError {
                        Text(interestRateError)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.accentRed)
                            .padding(.horizontal, Spacing.xs)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(Spacing.xl)
        .liquidGlass()
    }
    
    /// Parses all text fields, validates them against allowed ranges, updates the calculation Doubles, and formats input if valid.
    private func commitFields() {
        validateFields()
        
        // Format the text fields if they are valid, otherwise keep user input
        if amountError == nil, let val = Double(amountText.filter { $0.isNumber || $0 == "-" }) {
            amountText = String(Int(val))
        }
        
        if tenureError == nil, let val = Double(tenureText.filter { $0.isNumber || $0 == "-" }) {
            tenureText = String(Int(val))
        }
        
        if interestRateError == nil, let val = Double(interestRateText) {
            interestRateText = String(format: "%.2f", val)
        }
    }

    private func validateFields() {
        // Amount validation
        let cleanAmount = amountText.filter { $0.isNumber || $0 == "-" }
        if cleanAmount.isEmpty {
            amountError = "Amount is required"
            amount = 0
        } else if let val = Double(cleanAmount) {
            amount = val
            if val < 0 {
                amountError = "Amount cannot be negative"
            } else if val < amountRange.lowerBound || val > amountRange.upperBound {
                amountError = "Amount must be between ₹\(formatIndian(amountRange.lowerBound)) and ₹\(formatIndian(amountRange.upperBound))"
            } else {
                amountError = nil
            }
        } else {
            amountError = "Invalid amount"
            amount = 0
        }

        // Tenure validation
        let cleanTenure = tenureText.filter { $0.isNumber || $0 == "-" }
        if cleanTenure.isEmpty {
            tenureError = "Tenure is required"
            tenureMonths = 0
        } else if let val = Double(cleanTenure) {
            tenureMonths = val
            if val < 0 {
                tenureError = "Tenure cannot be negative"
            } else if val < tenureRange.lowerBound || val > tenureRange.upperBound {
                tenureError = "Tenure must be between \(Int(tenureRange.lowerBound)) and \(Int(tenureRange.upperBound)) months"
            } else {
                tenureError = nil
            }
        } else {
            tenureError = "Invalid tenure"
            tenureMonths = 0
        }

        // Interest Rate validation
        let cleanRate = interestRateText.filter { $0.isNumber || $0 == "." || $0 == "-" }
        if cleanRate.isEmpty {
            interestRateError = "Rate is required"
            interestRate = 0
        } else if let val = Double(cleanRate) {
            interestRate = val
            if val < 0 {
                interestRateError = "Rate cannot be negative"
            } else if val < interestRateRange.lowerBound || val > interestRateRange.upperBound {
                interestRateError = "Rate must be between \(String(format: "%.1f", interestRateRange.lowerBound))% and \(String(format: "%.1f", interestRateRange.upperBound))%"
            } else {
                interestRateError = nil
            }
        } else {
            interestRateError = "Invalid rate"
            interestRate = 0
        }
    }
    
    private var hasErrors: Bool {
        amountError != nil || tenureError != nil || interestRateError != nil
    }

    private var loanTypeSelector: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Loan Type")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.textSecondary)

            Menu {
                loanTypeMenuItems
            } label: {
                HStack {
                    Text(loanTypeTitle)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(selectedProduct == nil && !isUsingGeneralCalculator ? .textSecondary : .textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textSecondary)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, 14)
                .background(Color.black.opacity(0.05))
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
            // Total Interest card
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("₹\(formatIndian(calculateTotalInterest()))")
                    .font(.cardTitle)
                    .foregroundColor(.textPrimary)
                Text("Total Interest")
                    .font(.caption2)
                    .foregroundColor(.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.lg)
            .liquidGlass(cornerRadius: 16)

            // Total Amount card
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("₹\(formatIndian(amount + calculateTotalInterest()))")
                    .font(.cardTitle)
                    .foregroundColor(.textPrimary)
                Text("Total Amount")
                    .font(.caption2)
                    .foregroundColor(.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.lg)
            .liquidGlass(cornerRadius: 16)
        }
    }

    private var breakdownCard: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("Breakdown")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.textPrimary)
                .padding(.bottom, Spacing.xs)

            breakdownRow("Principal", value: formatIndian(amount), color: .accentGreen)
            breakdownRow("Total Interest", value: formatIndian(calculateTotalInterest()), color: .red)
            breakdownRow("Total Payable", value: formatIndian(amount + calculateTotalInterest()), color: .gray)

            Button(action: {
                if !hasErrors {
                    showAmortizationSchedule = true
                }
            }) {
                HStack {
                    Text("View Amortization Schedule")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(hasErrors ? .textSecondary : .accentGreen)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(hasErrors ? .textSecondary : .accentGreen)
                }
            }
            .buttonStyle(.plain)
            .disabled(hasErrors)
            .padding(.top, Spacing.xs)

        }
        .padding(Spacing.xl)
        .liquidGlass()
    }

    // MARK: - Product Loading
    @MainActor
    private func fetchLoanProducts() async {
        isLoadingProducts = true
        do {
            let products: [EMILoanProduct] = try await SupabaseManager.shared.client
                .from("loan_products")
                .select("id, name, type, min_amount, max_amount, min_tenure_months, max_tenure_months, min_interest_rate, max_interest_rate, supported_interest_types")
                .eq("is_active", value: true)
                .execute()
                .value
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

    private func applyProductDefaults(_ product: EMILoanProduct) {
        isUsingGeneralCalculator = false
        amount = product.minAmount
        tenureMonths = Double(product.minTenureMonths)
        interestRate = product.minInterestRate
        interestType = product.supportedInterestTypes.first?.displayName ?? "Reducing"
        amountText = String(Int(product.minAmount))
        tenureText = String(product.minTenureMonths)
        interestRateText = String(format: "%.2f", product.minInterestRate)
        
        amountError = nil
        tenureError = nil
        interestRateError = nil
    }

    private func useGeneralCalculator() {
        isUsingGeneralCalculator = true
        amount = fallbackAmountRange.lowerBound
        tenureMonths = fallbackTenureRange.lowerBound
        interestRate = fallbackInterestRateRange.lowerBound
        interestType = "Reducing"
        amountText = String(Int(fallbackAmountRange.lowerBound))
        tenureText = String(Int(fallbackTenureRange.lowerBound))
        interestRateText = String(format: "%.2f", fallbackInterestRateRange.lowerBound)
        
        amountError = nil
        tenureError = nil
        interestRateError = nil
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
        guard let product = selectedProduct else { 
            return 1...fallbackAmountRange.upperBound 
        }
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

        if n <= 0 { return 0.0 }
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
        let total = (emi * tenureMonths) - amount
        return total.isNaN || total.isInfinite ? 0.0 : max(0.0, total)
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
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.textSecondary)
                    }
                    Spacer()
                    Text("Amortization Schedule")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Spacer()
                    // Balance spacer
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 34, height: 34)
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
                        .liquidGlass(cornerRadius: 16)
                        
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
                        .liquidGlass(cornerRadius: 16)
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.bottom, 40)
                }
            }
            .background(
                LinearGradient(
                    colors: [Color(hex: "#E7EFE5"), Color(hex: "#EFF4EA"), Color(hex: "#E7EFE5")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
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
        .foregroundColor(.accentGreen)
        .tracking(0.3)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 12)
        .background(Color.accentGreenBg)
    }
    
    // MARK: - Table Row
    private func tableRow(item: ScheduleItem, isYearly: Bool) -> some View {
        HStack(spacing: 0) {
            Text("\(item.installmentNumber)")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.textPrimary)
                .frame(width: 50, alignment: .leading)
            
            Text("₹\(formatIndian(item.openingBalance))")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.textPrimary)
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            Text("₹\(formatIndian(item.interestComponent))")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.textPrimary)
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
