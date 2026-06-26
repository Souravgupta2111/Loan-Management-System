import SwiftUI

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

    init(initialLoanType: LoanType? = nil) {
        self.initialLoanType = initialLoanType
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                if applicationSuccess {
                    VStack(spacing: Spacing.xl) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.accentGreen)
                        Text("Application Submitted!")
                            .font(.cardTitle)
                        Text("Your loan application has been successfully submitted and is under review.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.textSecondary)
                        if let applicationNumber {
                            Text(applicationNumber)
                                .font(.bodyLarge)
                                .foregroundColor(.textPrimary)
                        }
                        
                        PillButton(title: "View Dashboard", style: .primary) {
                            dismiss()
                        }
                    }
                    .padding(Spacing.xl)
                } else {
                    VStack {
                        // Progress Header
                        HStack(spacing: 8) {
                            ForEach(1...4, id: \.self) { index in
                                Rectangle()
                                    .fill(index <= step ? Color.accentGreen : Color.accentGreen.opacity(0.2))
                                    .frame(height: 4)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, Spacing.xl)
                        .padding(.top, Spacing.md)
                        
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
                                    AmountTenureStep(product: selectedProduct!, amount: $amount, tenureMonths: $tenureMonths)
                                } else if step == 3 {
                                    DocumentUploadStep(product: selectedProduct!, documents: $applicationDocuments)
                                } else {
                                    ReviewSubmitStep(product: selectedProduct!, amount: amount, tenure: Int(tenureMonths))
                                }
                            }
                            .padding(Spacing.xl)
                        }
                        
                        // Footer Actions
                        if let submissionError {
                            Text(submissionError)
                                .font(.caption2)
                                .foregroundColor(.accentRed)
                                .padding(.horizontal, Spacing.xl)
                        }
                        HStack(spacing: Spacing.md) {
                            if step > 1 {
                                PillButton(title: "Back", style: .outline) {
                                    withAnimation { step -= 1 }
                                }
                                .disabled(isSubmitting)
                            }
                            
                            if isSubmitting {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                PillButton(title: step == 4 ? "Submit" : "Next", style: .primary) {
                                    if step < 4 {
                                        withAnimation { step += 1 }
                                    } else {
                                        submitApplication()
                                    }
                                }
                                .disabled(step == 1 && selectedProduct == nil)
                            }
                        }
                        .padding(Spacing.xl)
                        .background(Color.surface)
                        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: -4)
                    }
                }
            }
            .navigationTitle("Apply for Loan")
            .navigationBarTitleDisplayMode(.inline)
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
                    purpose: "General",
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
                .font(.cardTitle)
                .foregroundColor(.textPrimary)
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
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
        .padding(Spacing.xl)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Corner.xl))
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
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
                    .strokeBorder(Color.border, lineWidth: 2)
                    .frame(width: 24, height: 24)
            }
        }
        .padding(Spacing.lg)
        .background(isSelected ? Color.accentGreenBg : Color.surface)
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
        VStack(alignment: .leading, spacing: Spacing.lg) {
             Text("Loan Amount & Tenure")
                 .font(.cardTitle)
                 .foregroundColor(.textPrimary)
                 
             VStack(alignment: .leading, spacing: Spacing.sm) {
                 HStack {
                     Text("Amount")
                     Spacer()
                     Text("₹\(Int(amount))")
                 }
                 Slider(value: $amount, in: product.minAmount...product.maxAmount, step: 10000)
             }
             
             VStack(alignment: .leading, spacing: Spacing.sm) {
                 HStack {
                     Text("Tenure")
                     Spacer()
                     Text("\(Int(tenureMonths)) Months")
                 }
                 Slider(value: $tenureMonths, in: Double(product.minTenureMonths)...Double(product.maxTenureMonths), step: 1)
             }
        }
        .padding(Spacing.xl)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Corner.xl))
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
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
                .font(.cardTitle)
                .foregroundColor(.textPrimary)
            
            Text("Please upload the documents required for this loan product.")
                .font(.bodyRegular)
                .foregroundColor(.textSecondary)
            
            ForEach(requiredDocuments, id: \.id) { document in
                DocumentUploadView(
                    title: document.name,
                    subtitle: document.isMandatory ? "Required" : "Optional",
                    documentData: Binding(
                        get: { documents[document.name] },
                        set: { documents[document.name] = $0 }
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
                .font(.cardTitle)
                .foregroundColor(.textPrimary)
            
            VStack(spacing: Spacing.md) {
                ReviewRow(label: "Product", value: product.name)
                ReviewRow(label: "Amount", value: "₹\(Int(amount))")
                ReviewRow(label: "Tenure", value: "\(tenure) Months")
                ReviewRow(label: "Interest Rate", value: product.formattedStartingRate)
            }
        }
        .padding(Spacing.xl)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Corner.xl))
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
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
