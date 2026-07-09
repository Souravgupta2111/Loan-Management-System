import SwiftUI
import Supabase

/// Loan Application Flow Wizard (design.md §8.6)
///
/// Screen flow:
///   step 1              — Select loan product (list, fetched from backend)
///   step 2              — Product Details
///   step 3              — Amount & Tenure (Requirement)
///   step 4              — Document Upload
///   step 5              — Review & Submit (Preview)
///
/// Toolbar: single glass-circle back button (top-left) that always returns
/// to SelectLoanTypeView by dismissing the entire flow.
struct LoanApplicationFlowView: View {
    @Environment(\.dismiss) private var dismiss

    let initialLoanType: LoanType?
    @Binding var path: NavigationPath

    @State private var step = 1
    @State private var loanProducts: [LoanProduct] = []
    @State private var selectedProduct: LoanProduct?
    @State private var isLoadingProducts = true

    @State private var amount: Double = 100_000
    @State private var tenureMonths: Double = 12
    @State private var isSubmitting = false
    @State private var applicationSuccess = false
    @State private var applicationDocuments: [String: Data] = [:]
    @State private var submissionError: String?
    @State private var applicationNumber: String?
    @State private var agreedToTerms = false

    @State private var kycStatus: String = "pending"
    @State private var showKYCAlert = false
    @State private var showKYCSheet = false
    @State private var isCheckingKYC = false

    init(initialLoanType: LoanType? = nil, path: Binding<NavigationPath> = .constant(NavigationPath())) {
        self.initialLoanType = initialLoanType
        self._path = path
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.gradientMintStart, Color.gradientMintEnd, Color.gradientMintStart],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if applicationSuccess {
                successState
            } else {
                wizardContent
            }
            
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if !applicationSuccess {
                    GlassBackButton { 
                        if step > 1 {
                            withAnimation { step -= 1 }
                        } else {
                            dismiss()
                        }
                    }
                }
            }
        }
        .alert("KYC Required", isPresented: $showKYCAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Complete KYC") { showKYCSheet = true }
        } message: {
            Text("Please complete your KYC before applying for a loan.")
        }
        .navigationDestination(isPresented: $showKYCSheet) {
            KYCDashboardView(allowsSkip: false)
                .onDisappear {
                    Task { await fetchKYCStatus() }
                }
        }
        .task {
            // Request location permission early so GPS is ready for branch assignment on submit
            LocationService.shared.requestPermission()
            
            await fetchKYCStatus()
            do {
                let fetched = try await LoanService.shared.fetchActiveProducts(for: initialLoanType)
                isLoadingProducts = false
                loanProducts = fetched
                if let first = fetched.first {
                    selectedProduct = first
                    amount = first.minAmount
                    tenureMonths = Double(first.minTenureMonths)
                    // We intentionally do NOT auto-advance to showProductDetail here,
                    // so the user can see the "Select Loan Product" page and choose.
                }
            } catch {
                isLoadingProducts = false
                print("Failed to fetch products: \(error)")
            }
        }
        .onChange(of: selectedProduct) { _, newValue in
            if let product = newValue {
                amount = product.minAmount
                tenureMonths = Double(product.minTenureMonths)
            }
        }
    }

    private func fetchKYCStatus() async {
        do {
            if let userId = SupabaseManager.shared.currentUserId {
                struct BorrowerRow: Decodable { let kyc_status: String }
                let profiles: [BorrowerRow] = try await SupabaseManager.shared.client
                    .from("borrower_profiles")
                    .select("kyc_status")
                    .eq("user_id", value: userId.uuidString)
                    .execute()
                    .value
                if let profile = profiles.first {
                    kycStatus = profile.kyc_status
                }
            }
        } catch {
            print("Failed to fetch KYC status: \(error)")
        }
    }

    // MARK: - Navigation title

    private var navigationTitle: String {
        if applicationSuccess      { return "Application Submitted" }
        switch step {
        case 1:  return "Select Product"
        case 2:  return selectedProduct?.name ?? "Product Details"
        case 3:  return "User Request"
        case 4:  return "Documents"
        case 5:  return "Review & Submit"
        default: return "Apply for Loan"
        }
    }

    // MARK: - Wizard content

    private var wizardContent: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) { stepIndicator; stepLabels }
                .padding(.vertical, 16)
                .liquidGlass(cornerRadius: 0)
                .shadow(color: .black.opacity(0.02), radius: 6, x: 0, y: 3)

            ScrollView {
                VStack(spacing: 24) {
                    if step == 1 {
                        SelectProductStep(
                            products: loanProducts,
                            selected: $selectedProduct,
                            isLoading: isLoadingProducts,
                            emptyMessage: initialLoanType == nil
                                ? "No active loan products are available right now."
                                : "No \(initialLoanType?.displayName.lowercased() ?? "selected") options are available right now.",
                            onViewDetails: { product in
                                selectedProduct = product
                                amount = product.minAmount
                                tenureMonths = Double(product.minTenureMonths)
                                withAnimation { step = 2 }
                            }
                        )
                    } else if step == 2 {
                        if let product = selectedProduct {
                            productDetailScreen(product: product)
                        }
                    } else if step == 3 {
                        AmountTenureStep(product: selectedProduct!, amount: $amount, tenureMonths: $tenureMonths)
                    } else if step == 4 {
                        DocumentUploadStep(product: selectedProduct!, documents: $applicationDocuments)
                    } else {
                        ReviewSubmitStep(product: selectedProduct!, amount: amount, tenure: Int(tenureMonths))
                    }
                }
                .padding(24)
                .padding(.bottom, 20)
            }

            if step == 5 {
                HStack(alignment: .top, spacing: 10) {
                    Button { agreedToTerms.toggle() } label: {
                        Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                            .font(.title3)
                            .foregroundColor(agreedToTerms ? .accentGreen : .textSecondary)
                    }
                    .buttonStyle(.plain)
                    Text("I agree to the terms and conditions and authorize the verification of my submitted documents.")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                .accessibilityElement(children: .ignore)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("I agree to the terms and conditions and authorize verification of my submitted documents")
                .accessibilityValue(agreedToTerms ? "Checked" : "Unchecked")
                .accessibilityHint("Double tap to toggle agreement")
                .accessibilityAction { agreedToTerms.toggle() }
            }

            footerActions
        }
    }

    // MARK: - Product detail screen

    private func productDetailScreen(product: LoanProduct) -> some View {
        VStack(alignment: .leading, spacing: 24) {

            // Hero
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.themeGreen.opacity(0.18))
                            .frame(width: 52, height: 52)
                        Image(systemName: product.type.icon)
                            .font(.title3.weight(.semibold))
                            .foregroundColor(Color.accentGreen)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(product.name)
                            .font(.title3.weight(.bold)).fontDesign(.rounded)
                            .foregroundColor(.textPrimary)
                        Text(product.type.displayName)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.textSecondary)
                    }
                }
                if let desc = product.description, !desc.isEmpty {
                    Text(desc)
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlass(cornerRadius: 20)
            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)

            // Interest & Rates — fully backend-driven
            detailSection(title: "Interest & Rates") {
                detailRow(icon: "percent",                    label: "Interest Rate Range",   value: product.formattedRateRange)
                detailRow(icon: "arrow.up.arrow.down",        label: "Interest Types",         value: product.formattedInterestTypes)
            }

            // Amount & Tenure — fully backend-driven
            detailSection(title: "Loan Amount & Tenure") {
                detailRow(icon: "indianrupeesign.circle", label: "Amount Range",       value: product.formattedCompactAmountRange)
                detailRow(icon: "calendar",               label: "Tenure Range",       value: product.formattedTenureRange)
                detailRow(icon: "lock.shield",            label: "Requires Collateral", value: product.requiresCollateral ? "Yes" : "No")
            }

            // Fees & Penalties — fully backend-driven
            detailSection(title: "Fees & Penalties") {
                detailRow(icon: "creditcard",             label: "Processing Fee",       value: String(format: "%.2f%%", product.processingFeePct))
                detailRow(icon: "arrow.counterclockwise", label: "Prepayment Penalty",   value: String(format: "%.2f%%", product.prepaymentPenaltyPct))
                detailRow(icon: "exclamationmark.circle", label: "Late Penalty/Month",   value: String(format: "%.2f%%", product.latePenaltyPctPerMonth))
            }

            // Eligibility criteria — from backend JSON column, admin-editable
            if let criteria = product.eligibilityCriteria, !criteria.isEmpty {
                detailSection(title: "Eligibility Criteria") {
                    ForEach(criteria.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        let displayValue: String = {
                            if key.lowercased().contains("age") {
                                return "\(value) years"
                            } else if key.lowercased().contains("income") {
                                if let intValue = Int(value) {
                                    let formatter = NumberFormatter()
                                    formatter.numberStyle = .decimal
                                    formatter.locale = Locale(identifier: "en_IN")
                                    return "₹\(formatter.string(from: NSNumber(value: intValue)) ?? value)"
                                }
                                return "₹\(value)"
                            }
                            return value
                        }()
                        detailRow(
                            icon: "checkmark.seal",
                            label: key.replacingOccurrences(of: "_", with: " ").capitalized,
                            value: displayValue
                        )
                    }
                }
            }

            // Required documents — from backend JSON column, admin-editable
            let docs = product.requiredDocumentTitles
            if !docs.isEmpty {
                detailSection(title: "Required Documents") {
                    ForEach(docs, id: \.self) { doc in
                        HStack(spacing: 10) {
                            Image(systemName: "doc.text")
                                .font(.subheadline)
                                .foregroundColor(Color.accentGreen)
                                .frame(width: 24)
                            Text(doc)
                                .font(.subheadline)
                                .foregroundColor(.textPrimary)
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        Divider().opacity(0.5)
                    }
                }
            }
        }
    }

    // MARK: - Detail section helpers

    private func detailSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundColor(.accentGreen)
                .tracking(1.5)
            VStack(spacing: 0) { content() }
                .padding(16)
                .liquidGlass(cornerRadius: 16)
                .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 3)
        }
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(Color.accentGreen)
                    .frame(width: 24)
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                Spacer()
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, 10)
            Divider().opacity(0.4)
        }
    }

    // MARK: - Footer actions

    private var footerActions: some View {
        VStack(spacing: 8) {
            if let submissionError {
                Text(submissionError)
                    .font(.caption2)
                    .foregroundColor(.accentRed)
                    .padding(.horizontal, 24)
            }
            
            HStack(spacing: 12) {
                // Back button (left of NEXT) — kept as-is per requirement 4
                if step > 1 {
                    Button {
                        withAnimation { step -= 1 }
                    } label: {
                        Text("Back")
                            .font(.body.weight(.semibold))
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
                        Capsule().fill(Color(hex: "#1A1A1A")).frame(height: 56)
                        ProgressView().tint(.white)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    let isDisabled: Bool = {
                        if step == 1 {
                            return selectedProduct == nil
                        } else if step == 2 {
                            return false
                        } else if step == 4 {
                            if let product = selectedProduct {
                                return !product.requiredDocumentTitles.allSatisfy { applicationDocuments[$0] != nil }
                            }
                            return true
                        } else if step == 5 {
                            return !agreedToTerms
                        }
                        return false
                    }()
                    Button {
                        if step == 2 {
                            guard !isCheckingKYC else { return }
                            Task {
                                isCheckingKYC = true
                                await fetchKYCStatus()
                                isCheckingKYC = false
                                if kycStatus.lowercased() != "verified" && kycStatus.lowercased() != "approved" {
                                    showKYCAlert = true
                                } else {
                                    withAnimation { step = 3 }
                                }
                            }
                        } else if step < 5 {
                            withAnimation { step += 1 }
                        } else {
                            submitApplication()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isCheckingKYC {
                                ProgressView().tint(.white)
                                Text("CHECKING...")
                            } else {
                                Text(step == 5 ? "SUBMIT" : "NEXT")
                                Image(systemName: step == 5 ? "checkmark" : "arrow.right")
                            }
                        }
                        .font(.body.weight(.bold))
                        .tracking(1.5)
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
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 18)
    }

    // MARK: - Step indicator

    private var stepIndicator: some View {
        HStack(spacing: 0) {
            ForEach(1...5, id: \.self) { index in
                let isCompleted = index < step
                let isActive = index == step
                let isFilled = isCompleted || isActive

                ZStack {
                    Circle()
                        .fill(isFilled ? Color.accentGreen : Color.white)
                        .frame(width: 24, height: 24)
                        .overlay(Circle().stroke(Color.accentGreen, lineWidth: 2))
                    if isCompleted {
                        Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                    } else if isActive {
                        Circle().fill(Color.white).frame(width: 8, height: 8)
                    }
                }
                if index < 5 {
                    let fillRatio: CGFloat = index < step ? 1.0 : 0.0
                    
                    if fillRatio == 1.0 {
                        Rectangle().fill(Color.accentGreen).frame(height: 2).frame(maxWidth: .infinity)
                    } else {
                        Rectangle().fill(Color.border).frame(height: 2).frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.horizontal, 32)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step) of 4")
    }

    private var stepLabels: some View {
        HStack {
            stepLabel(text: "Product", isActive: step >= 1); Spacer()
            stepLabel(text: "Details", isActive: step >= 2); Spacer()
            stepLabel(text: "Request", isActive: step >= 3); Spacer()
            stepLabel(text: "Docs",    isActive: step >= 4); Spacer()
            stepLabel(text: "Preview",  isActive: step >= 5)
        }
        .padding(.horizontal, 16)
    }

    private func stepLabel(text: String, isActive: Bool) -> some View {
        Text(text)
            .font(.caption.weight(isActive ? .semibold : .medium))
            .foregroundColor(isActive ? .textPrimary : .textTertiary)
    }

    // MARK: - Success state

    private var successState: some View {
        VStack(spacing: 32) {
            ZStack {
                Circle().fill(Color.accentGreenBg).frame(width: 120, height: 120)
                Image(systemName: "checkmark.seal.fill").font(.title).foregroundColor(.accentGreen)
            }
            VStack(spacing: 12) {
                Text("Application Submitted!")
                    .font(.title2.weight(.bold)).fontDesign(.rounded).foregroundColor(.textPrimary)
                Text("Your loan application has been successfully submitted and is under review. Our loan officer will get in touch with you shortly.")
                    .font(.bodyRegular).foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 16)
            }
            if let applicationNumber {
                VStack(spacing: 4) {
                    Text("APPLICATION NUMBER")
                        .font(.caption.weight(.semibold)).foregroundColor(.textSecondary).tracking(1.5)
                    Text(applicationNumber)
                        .font(.headline.weight(.bold)).fontDesign(.rounded).foregroundColor(.textPrimary)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            PillButton(title: "Back to Dashboard", style: .primary) {
                path = NavigationPath()
            }
                .frame(width: 240)
        }
        .padding(32)
    }

    // MARK: - Submit

    private func submitApplication() {
        guard let product = selectedProduct,
              let userId = SupabaseManager.shared.currentUserId else { return }
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
                    userId: userId, productId: product.id, amount: amount,
                    tenure: Int(tenureMonths), purpose: "General Funding",
                    documents: applicationDocuments
                )
                withAnimation { applicationSuccess = true }
            } catch {
                submissionError = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

// MARK: - SelectProductStep

struct SelectProductStep: View {
    let products: [LoanProduct]
    @Binding var selected: LoanProduct?
    let isLoading: Bool
    let emptyMessage: String
    var onViewDetails: ((LoanProduct) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select Loan Product")
                .font(.title3.weight(.bold)).fontDesign(.rounded)
                .foregroundColor(.textPrimary)

            if isLoading {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
            } else if products.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray").font(.title2).foregroundColor(.textSecondary)
                    Text(emptyMessage).font(.bodyLarge).foregroundColor(.textSecondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(products) { product in
                        ProductOptionRow(
                            title: product.name,
                            subtitle: product.formattedCompactAmountRange,
                            rate: product.formattedStartingRate,
                            isSelected: selected?.id == product.id
                        )
                        .onTapGesture { 
                            selected = product 
                        }
                    }
                }
            }
        }
        .padding(16)
        .liquidGlass(cornerRadius: 20)
        .shadow(color: .black.opacity(0.02), radius: 10, x: 0, y: 4)
    }
}

struct ProductOptionRow: View {
    let title: String
    let subtitle: String
    let rate: String
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.bodyLarge).foregroundColor(.textPrimary)
                Text(subtitle).font(.caption).foregroundColor(.textSecondary)
                Text(rate).font(.caption.weight(.semibold)).foregroundColor(Color.accentGreen)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill").foregroundColor(Color.accentGreen).font(.title3)
            } else {
                Circle().strokeBorder(Color.accentGreen.opacity(0.3), lineWidth: 1.5).frame(width: 22, height: 22)
            }
        }
        .padding(16)
        .background(Color.accentGreenBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(isSelected ? Color.accentGreen : Color.accentGreen.opacity(0.3), lineWidth: 1.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(subtitle), \(rate)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - AmountTenureStep

struct AmountTenureStep: View {
    let product: LoanProduct
    @Binding var amount: Double
    @Binding var tenureMonths: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Loan Amount & Tenure")
                    .font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(.textPrimary)
                Text("Enter the desired loan amount and the tenure")
                    .font(.bodyRegular).foregroundColor(.textSecondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Amount").font(.bodyLarge).foregroundColor(.textSecondary)
                    Spacer()
                    Text("₹\(formatIndian(amount))")
                        .font(.title3.weight(.bold)).fontDesign(.rounded).foregroundColor(.textPrimary)
                }
                Slider(value: $amount, in: product.minAmount...product.maxAmount, step: 10_000).tint(.accentGreen)
                    .accessibilityLabel("Loan amount")
                    .accessibilityValue("₹\(formatIndian(amount))")
                HStack {
                    Text(formatCompact(product.minAmount)); Spacer(); Text(formatCompact(product.maxAmount))
                }.font(.caption).foregroundColor(.textTertiary)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Tenure").font(.bodyLarge).foregroundColor(.textSecondary)
                    Spacer()
                    Text("\(Int(tenureMonths)) Months")
                        .font(.title3.weight(.bold)).fontDesign(.rounded).foregroundColor(.textPrimary)
                }
                Slider(value: $tenureMonths, in: Double(product.minTenureMonths)...Double(product.maxTenureMonths), step: 1).tint(.accentGreen)
                    .accessibilityLabel("Loan tenure")
                    .accessibilityValue("\(Int(tenureMonths)) months")
                HStack {
                    Text("\(product.minTenureMonths) Mo"); Spacer(); Text("\(product.maxTenureMonths) Mo")
                }.font(.caption).foregroundColor(.textTertiary)
            }

            LiveCalculationCard(product: product, amount: amount, tenureMonths: tenureMonths)
        }
        .padding(16)
        .liquidGlass(cornerRadius: 20, tint: Color.accentGreen, tintOpacity: 0.04)
    }

    private struct TenureOption: Identifiable {
        let id = UUID(); let label: String; let months: Double
    }
    private var availableTenureOptions: [TenureOption] {
        let all = [
            TenureOption(label: "1 Year",   months: 12),  TenureOption(label: "2 Years",  months: 24),
            TenureOption(label: "3 Years",  months: 36),  TenureOption(label: "5 Years",  months: 60),
            TenureOption(label: "10 Years", months: 120), TenureOption(label: "15 Years", months: 180),
            TenureOption(label: "20 Years", months: 240), TenureOption(label: "25 Years", months: 300),
            TenureOption(label: "30 Years", months: 360)
        ]
        let filtered = all.filter { $0.months >= Double(product.minTenureMonths) && $0.months <= Double(product.maxTenureMonths) }
        return filtered.isEmpty ? [TenureOption(label: "\(product.minTenureMonths) Mo", months: Double(product.minTenureMonths))] : filtered
    }
    private func formatCompact(_ v: Double) -> String {
        if v >= 10_000_000 { return String(format: "₹%.0fCr", v/10_000_000) }
        if v >= 100_000    { return String(format: "₹%.0fL",  v/100_000) }
        if v >= 1_000      { return String(format: "₹%.0fK",  v/1_000) }
        return "₹\(Int(v))"
    }
    private func formatIndian(_ v: Double) -> String {
        let f = NumberFormatter(); f.locale = Locale(identifier: "en_IN")
        f.numberStyle = .decimal; f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "\(Int(v))"
    }
}

// MARK: - LiveCalculationCard

struct LiveCalculationCard: View {
    let product: LoanProduct; let amount: Double; let tenureMonths: Double
    var emiDetails: (emi: Double, totalInterest: Double) {
        let r = product.minInterestRate / 12 / 100; let n = tenureMonths; let p = amount
        let emi: Double = r > 0 ? (p * r * pow(1+r,n)) / (pow(1+r,n) - 1) : p/n
        let roundedEMI = round(emi)
        return (roundedEMI, max(0, roundedEMI * n - p))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ESTIMATED LOAN DETAILS")
                .font(.caption.weight(.semibold)).foregroundColor(.accentGreen).tracking(1.5)
            VStack(spacing: 8) {
                row("Estimated EMI",           "₹\(fmt(emiDetails.emi))/mo", highlight: true)
                Divider().background(Color.accentGreen.opacity(0.2))
                row("Interest Rate Range",     product.formattedRateRange)
                row("Interest Type",           product.formattedInterestTypes)
                row("Spread over RBI",         String(format: "%.2f%%", product.spreadOverBase))
                row("Total Estimated Interest","₹\(fmt(emiDetails.totalInterest))")
            }
        }
        .padding(16)
        .background(Color.accentGreenBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.accentGreen.opacity(0.3), lineWidth: 1))
    }
    private func row(_ label: String, _ value: String, highlight: Bool = false) -> some View {
        HStack {
            Text(label).font(.subheadline.weight(highlight ? .semibold : .regular))
                .foregroundColor(highlight ? .accentGreen : .textSecondary)
            Spacer()
            Text(value).font(.subheadline.weight(.bold))
                .foregroundColor(highlight ? .accentGreen : .textPrimary)
        }
    }
    private func fmt(_ v: Double) -> String {
        let f = NumberFormatter(); f.locale = Locale(identifier: "en_IN")
        f.numberStyle = .decimal; f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "\(Int(v))"
    }
}

// MARK: - DocumentUploadStep

struct DocumentUploadStep: View {
    let product: LoanProduct
    @Binding var documents: [String: Data]
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Required Documents")
                .font(.title3.weight(.bold)).fontDesign(.rounded).foregroundColor(.textPrimary)
            Text("Please upload the documents required for this loan product.")
                .font(.bodyRegular).foregroundColor(.textSecondary)
            ForEach(product.requiredDocumentTitles, id: \.self) { doc in
                DocumentUploadView(
                    title: doc, subtitle: "Required Document",
                    documentData: Binding(get: { documents[doc] }, set: { documents[doc] = $0 })
                )
            }
        }
    }
}

// MARK: - ReviewSubmitStep

struct ReviewSubmitStep: View {
    let product: LoanProduct; let amount: Double; let tenure: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Review Application")
                .font(.title3.weight(.bold)).fontDesign(.rounded).foregroundColor(.textPrimary)
            VStack(spacing: 12) {
                ReviewRow(label: "Product",       value: product.name)
                Divider()
                ReviewRow(label: "Amount",        value: "₹\(fmt(amount))")
                Divider()
                ReviewRow(label: "Tenure",        value: "\(tenure) Months")
                Divider()
                ReviewRow(label: "Starting Rate", value: product.formattedStartingRate)
            }
        }
        .padding(24)
        .liquidGlass(cornerRadius: 20)
        .shadow(color: .black.opacity(0.02), radius: 12, x: 0, y: 4)
    }
    private func fmt(_ v: Double) -> String {
        let f = NumberFormatter(); f.locale = Locale(identifier: "en_IN")
        f.numberStyle = .decimal; f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "\(Int(v))"
    }
}

struct ReviewRow: View {
    let label: String; let value: String
    var body: some View {
        HStack {
            Text(label).font(.bodyRegular).foregroundColor(.textSecondary)
            Spacer()
            Text(value).font(.bodyLarge).foregroundColor(.textPrimary)
        }
    }
}

