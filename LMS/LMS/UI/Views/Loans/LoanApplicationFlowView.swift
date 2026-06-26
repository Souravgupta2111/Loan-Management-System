import SwiftUI

/// Loan Application Flow Wizard (design.md §8.6)
/// A beautiful multi-step questionnaire that guides the borrower through applying.
struct LoanApplicationFlowView: View {
    @Environment(\.dismiss) private var dismiss

    let initialLoanType: LoanType?

    @State private var step = 1
    @State private var loanProducts: [LoanProduct] = []
    @State private var selectedProduct: LoanProduct?
    @State private var isLoadingProducts = true
    
    // Application state
    @State private var amount: Double = 100000
    @State private var tenureMonths: Double = 12
    @State private var isSubmitting = false
    @State private var applicationSuccess = false
    @State private var applicationDocuments: [String: Data] = [:]
    @State private var submissionError: String?
    @State private var applicationNumber: String?
    @State private var agreedToTerms = false

    init(initialLoanType: LoanType? = nil) {
        self.initialLoanType = initialLoanType
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                if applicationSuccess {
                    successState
                } else {
                    VStack(spacing: 0) {
                        // Custom Step Indicator Header — only show from step 2 onwards
                        if step > 1 {
                            VStack(spacing: 8) {
                                stepIndicator
                                stepLabels
                            }
                            .padding(.vertical, Spacing.lg)
                            .background(Color.white)
                            .shadow(color: .black.opacity(0.02), radius: 6, x: 0, y: 3)
                        }
                        
                        ScrollView {
                            VStack(spacing: Spacing.xl) {
                                if step == 1 {
                                    SelectProductStep(
                                        products: loanProducts,
                                        selected: $selectedProduct,
                                        isLoading: isLoadingProducts,
                                        emptyMessage: initialLoanType == nil
                                            ? "No active loan products are available right now."
                                            : "No \(initialLoanType?.displayName.lowercased() ?? "selected") options are available right now."
                                    )
                                } else if step == 2 {
                                    AmountTenureStep(
                                        product: selectedProduct!,
                                        amount: $amount,
                                        tenureMonths: $tenureMonths
                                    )
                                } else if step == 3 {
                                    DocumentUploadStep(
                                        product: selectedProduct!,
                                        documents: $applicationDocuments
                                    )
                                } else {
                                    ReviewSubmitStep(
                                        product: selectedProduct!,
                                        amount: amount,
                                        tenure: Int(tenureMonths)
                                    )
                                }
                            }
                            .padding(Spacing.xl)
                            .padding(.bottom, 20)
                        }
                        
                        // Step 4 Terms Checkbox
                        if step == 4 {
                            HStack(alignment: .top, spacing: 10) {
                                Button {
                                    agreedToTerms.toggle()
                                } label: {
                                    Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                                        .font(.title3)
                                        .foregroundColor(agreedToTerms ? .accentGreen : .textSecondary)
                                }
                                .buttonStyle(.plain)
                                
                                Text("I agree to the terms and conditions and authorize the verification of my submitted documents.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.textSecondary)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(.horizontal, Spacing.xl)
                            .padding(.bottom, Spacing.md)
                        }
                        
                        // Footer Actions
                        VStack(spacing: 8) {
                            if let submissionError {
                                Text(submissionError)
                                    .font(.caption2)
                                    .foregroundColor(.accentRed)
                                    .padding(.horizontal, Spacing.xl)
                            }

                            HStack(spacing: 12) {
                                if step > 1 {
                                    Button {
                                        withAnimation { step -= 1 }
                                    } label: {
                                        Text("Back")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.textPrimary)
                                            .frame(width: 90)
                                            .padding(.vertical, 18)
                                            .background(Color.surfaceMuted)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isSubmitting)
                                }

                                if isSubmitting {
                                    ZStack {
                                        Capsule()
                                            .fill(Color(hex: "#1A1A1A"))
                                            .frame(height: 56)
                                        ProgressView().tint(.white)
                                    }
                                    .frame(maxWidth: .infinity)
                                } else {
                                    let isDisabled = (step == 1 && selectedProduct == nil) || (step == 4 && !agreedToTerms)
                                    Button {
                                        if step < 4 {
                                            withAnimation { step += 1 }
                                        } else {
                                            submitApplication()
                                        }
                                    } label: {
                                        HStack(spacing: 8) {
                                            Text(step == 4 ? "SUBMIT" : "NEXT")
                                                .font(.system(size: 16, weight: .bold))
                                                .tracking(1.5)
                                            Image(systemName: step == 4 ? "checkmark" : "arrow.right")
                                                .font(.system(size: 14, weight: .bold))
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 18)
                                        .background(isDisabled ? Color(hex: "#1A1A1A").opacity(0.4) : Color(hex: "#1A1A1A"))
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isDisabled)
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.xl)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: -6)
                    }
                }
            }
            .navigationTitle("Apply for Loan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.textPrimary)
                    }
                }
            }
            .task {
                do {
                    let fetchedProducts = try await LoanService.shared.fetchActiveProducts(for: initialLoanType)
                    isLoadingProducts = false
                    loanProducts = fetchedProducts
                    if let first = fetchedProducts.first {
                        selectedProduct = first
                        amount = first.minAmount
                        tenureMonths = Double(first.minTenureMonths)
                    }
                } catch {
                    isLoadingProducts = false
                    print("Failed to fetch products: \(error)")
                }
            }
        }
    }
    
    private var stepIndicator: some View {
        HStack(spacing: 0) {
            ForEach(1...4, id: \.self) { index in
                // Step Circle
                ZStack {
                    Circle()
                        .fill(index <= step ? Color.accentGreen : Color.white)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(Color.accentGreen, lineWidth: 2)
                        )
                    
                    if index < step {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    } else if index == step {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                    }
                }
                
                // Connecting line
                if index < 4 {
                    Rectangle()
                        .fill(index < step ? Color.accentGreen : Color.border)
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 32)
    }
    
    private var stepLabels: some View {
        HStack {
            stepLabel(text: "Product", isActive: step >= 1)
            Spacer()
            stepLabel(text: "Details", isActive: step >= 2)
            Spacer()
            stepLabel(text: "Docs", isActive: step >= 3)
            Spacer()
            stepLabel(text: "Review", isActive: step >= 4)
        }
        .padding(.horizontal, 16)
    }
    
    private func stepLabel(text: String, isActive: Bool) -> some View {
        Text(text)
            .font(.system(size: 12, weight: isActive ? .semibold : .medium))
            .foregroundColor(isActive ? .textPrimary : .textTertiary)
    }
    
    private var successState: some View {
        VStack(spacing: Spacing.xxl) {
            ZStack {
                Circle()
                    .fill(Color.accentGreenBg)
                    .frame(width: 120, height: 120)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.accentGreen)
            }
            
            VStack(spacing: Spacing.sm) {
                Text("Application Submitted!")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                
                Text("Your loan application has been successfully submitted and is under review. Our loan officer will get in touch with you shortly.")
                    .font(.bodyRegular)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            
            if let applicationNumber {
                VStack(spacing: 4) {
                    Text("APPLICATION NUMBER")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.textSecondary)
                        .tracking(1.5)
                    
                    Text(applicationNumber)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: Corner.md))
                }
            }
            
            PillButton(title: "Back to Dashboard", style: .primary) {
                dismiss()
            }
            .frame(width: 240)
        }
        .padding(Spacing.xxl)
    }
    
    private func submitApplication() {
        guard let product = selectedProduct, let userId = SupabaseManager.shared.currentUserId else { return }
        let required = product.requiredDocumentTitles
        guard required.allSatisfy({ applicationDocuments[$0] != nil }) else {
            submissionError = "Upload every required document before submitting."
            return
        }
        submissionError = nil
        isSubmitting = true
        Task {
            do {
                applicationNumber = try await LoanService.shared.submitApplication(
                    userId: userId,
                    productId: product.id,
                    amount: amount,
                    tenure: Int(tenureMonths),
                    purpose: "General Funding",
                    documents: applicationDocuments
                )
                withAnimation {
                    applicationSuccess = true
                }
            } catch {
                submissionError = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

// MARK: - Steps

struct SelectProductStep: View {
    let products: [LoanProduct]
    @Binding var selected: LoanProduct?
    let isLoading: Bool
    let emptyMessage: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("Select Loan Product")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.textPrimary)
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if products.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray")
                        .font(.system(size: 28))
                        .foregroundColor(.textSecondary)
                    Text(emptyMessage)
                        .font(.bodyLarge)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(products) { product in
                        ProductOptionRow(
                            title: product.name,
                            subtitle: product.formattedAmountRange,
                            isSelected: selected?.id == product.id
                        )
                        .onTapGesture {
                            selected = product
                        }
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Corner.xl))
        .overlay(
            RoundedRectangle(cornerRadius: Corner.xl)
                .stroke(Color.border, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.02), radius: 10, x: 0, y: 4)
    }
}

struct ProductOptionRow: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.bodyLarge)
                    .foregroundColor(.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentGreen)
                    .font(.title3)
            } else {
                Circle()
                    .strokeBorder(Color.border, lineWidth: 1.5)
                    .frame(width: 22, height: 22)
            }
        }
        .padding(Spacing.lg)
        .background(isSelected ? Color.accentGreenBg.opacity(0.3) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: Corner.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Corner.lg)
                .stroke(isSelected ? Color.accentGreen : Color.border, lineWidth: 1)
        )
    }
}

struct AmountTenureStep: View {
    let product: LoanProduct
    @Binding var amount: Double
    @Binding var tenureMonths: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
             Text("Loan Amount & Tenure")
                 .font(.system(size: 20, weight: .bold, design: .rounded))
                 .foregroundColor(.textPrimary)
                 
             // Amount selection with custom labels
             VStack(alignment: .leading, spacing: Spacing.sm) {
                 HStack {
                     Text("Amount")
                         .font(.bodyLarge)
                         .foregroundColor(.textSecondary)
                     Spacer()
                     Text("₹\(formatIndian(amount))")
                         .font(.system(size: 22, weight: .bold, design: .rounded))
                         .foregroundColor(.textPrimary)
                 }
                 
                 Slider(value: $amount, in: product.minAmount...product.maxAmount, step: 10000)
                     .tint(.accentGreen)
                 
                 HStack {
                     Text(formatCompact(product.minAmount))
                     Spacer()
                     Text(formatCompact(product.maxAmount))
                 }
                 .font(.caption)
                 .foregroundColor(.textTertiary)
             }
             
             // Tenure selection using pill/capsule selector
             VStack(alignment: .leading, spacing: Spacing.sm) {
                 HStack {
                     Text("Tenure")
                         .font(.bodyLarge)
                         .foregroundColor(.textSecondary)
                     Spacer()
                     Text("\(Int(tenureMonths)) Months")
                         .font(.system(size: 22, weight: .bold, design: .rounded))
                         .foregroundColor(.textPrimary)
                 }
                 
                 ScrollView(.horizontal, showsIndicators: false) {
                     HStack(spacing: Spacing.sm) {
                         ForEach(availableTenureOptions) { option in
                             Button {
                                 tenureMonths = option.months
                             } label: {
                                 Text(option.label)
                                     .font(.system(size: 14, weight: .semibold))
                                     .foregroundColor(tenureMonths == option.months ? .white : .textPrimary)
                                     .padding(.horizontal, 20)
                                     .padding(.vertical, 12)
                                     .background(tenureMonths == option.months ? Color.accentDark : Color.surfaceMuted)
                                     .clipShape(Capsule())
                             }
                             .buttonStyle(.plain)
                         }
                     }
                     .padding(.vertical, 2)
                 }
             }
             
             // Dynamic calculations card
             LiveCalculationCard(
                 product: product,
                 amount: amount,
                 tenureMonths: tenureMonths
             )
        }
        .padding(Spacing.lg)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Corner.xl))
        .overlay(
            RoundedRectangle(cornerRadius: Corner.xl)
                .stroke(Color.border, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.02), radius: 10, x: 0, y: 4)
    }

    private struct TenureOption: Identifiable {
        let id = UUID()
        let label: String
        let months: Double
    }

    private var availableTenureOptions: [TenureOption] {
        let allOptions = [
            TenureOption(label: "1 Year", months: 12),
            TenureOption(label: "2 Years", months: 24),
            TenureOption(label: "3 Years", months: 36),
            TenureOption(label: "5 Years", months: 60),
            TenureOption(label: "10 Years", months: 120),
            TenureOption(label: "15 Years", months: 180),
            TenureOption(label: "20 Years", months: 240),
            TenureOption(label: "25 Years", months: 300),
            TenureOption(label: "30 Years", months: 360)
        ]
        
        let filtered = allOptions.filter { $0.months >= Double(product.minTenureMonths) && $0.months <= Double(product.maxTenureMonths) }
        return filtered.isEmpty ? [TenureOption(label: "\(product.minTenureMonths) Mo", months: Double(product.minTenureMonths))] : filtered
    }

    private func formatCompact(_ value: Double) -> String {
        if value >= 10000000 {
            return String(format: "₹%.0fCr", value / 10000000)
        } else if value >= 100000 {
            return String(format: "₹%.0fL", value / 100000)
        } else if value >= 1000 {
            return String(format: "₹%.0fK", value / 1000)
        }
        return "₹\(Int(value))"
    }
    
    private func formatIndian(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
}

struct LiveCalculationCard: View {
    let product: LoanProduct
    let amount: Double
    let tenureMonths: Double
    
    var emiDetails: (emi: Double, totalInterest: Double) {
        let annualRate = product.minInterestRate
        let monthlyRate = annualRate / 12 / 100
        let n = tenureMonths
        let p = amount
        let emi: Double
        if monthlyRate > 0 {
            emi = (p * monthlyRate * pow(1 + monthlyRate, n)) / (pow(1 + monthlyRate, n) - 1)
        } else {
            emi = p / n
        }
        let totalPayable = emi * n
        let totalInterest = totalPayable - p
        return (emi, max(0, totalInterest))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ESTIMATED LOAN DETAILS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.accentGreen)
                .tracking(1.5)
            
            VStack(spacing: 8) {
                calculationRow(label: "Estimated EMI", value: "₹\(formatIndian(emiDetails.emi))/mo", isHighlighted: true)
                Divider().background(Color.accentGreen.opacity(0.2))
                calculationRow(label: "Interest Rate Range", value: product.formattedRateRange)
                calculationRow(label: "Interest Type", value: product.formattedInterestTypes)
                calculationRow(label: "Spread over RBI", value: String(format: "%.2f%%", product.spreadOverBase))
                calculationRow(label: "Total Estimated Interest", value: "₹\(formatIndian(emiDetails.totalInterest))")
            }
        }
        .padding(16)
        .background(Color.accentGreenBg)
        .clipShape(RoundedRectangle(cornerRadius: Corner.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Corner.lg)
                .stroke(Color.accentGreen.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func calculationRow(label: String, value: String, isHighlighted: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: isHighlighted ? .semibold : .regular))
                .foregroundColor(isHighlighted ? .accentGreen : .textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(isHighlighted ? .accentGreen : .textPrimary)
        }
    }
    
    private func formatIndian(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
}

struct DocumentUploadStep: View {
    let product: LoanProduct
    @Binding var documents: [String: Data]

    private var requiredDocuments: [String] {
        product.requiredDocumentTitles
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("Required Documents")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.textPrimary)
            
            Text("Please upload the documents required for this loan product.")
                .font(.bodyRegular)
                .foregroundColor(.textSecondary)
            
            ForEach(requiredDocuments, id: \.self) { document in
                DocumentUploadView(
                    title: document,
                    subtitle: "Required Document",
                    documentData: Binding(
                        get: { documents[document] },
                        set: { documents[document] = $0 }
                    )
                )
            }
        }
    }
}

struct ReviewSubmitStep: View {
    let product: LoanProduct
    let amount: Double
    let tenure: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("Review Application")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.textPrimary)
            
            VStack(spacing: Spacing.md) {
                ReviewRow(label: "Product", value: product.name)
                Divider()
                ReviewRow(label: "Amount", value: "₹\(formatIndian(amount))")
                Divider()
                ReviewRow(label: "Tenure", value: "\(tenure) Months")
                Divider()
                ReviewRow(label: "Starting Rate", value: product.formattedStartingRate)
            }
        }
        .padding(Spacing.xl)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Corner.xl))
        .overlay(
            RoundedRectangle(cornerRadius: Corner.xl)
                .stroke(Color.border, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.02), radius: 12, x: 0, y: 4)
    }
    
    private func formatIndian(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
}

struct ReviewRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.bodyRegular)
                .foregroundColor(.textSecondary)
            Spacer()
            Text(value)
                .font(.bodyLarge)
                .foregroundColor(.textPrimary)
        }
    }
}
