//
//  LoanProductListView.swift
//  LMS Staff
//
//  Full-featured Loan Catalog manager with comprehensive create/edit forms.
//

import SwiftUI

struct LoanProductListView: View {
    @StateObject private var vm = LoanProductViewModel()
    @State private var selectedProduct: LoanProduct?
    @State private var showCreateSheet: Bool = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Product List
            VStack(alignment: .leading, spacing: 0) {
                VStack(spacing: 0) {
                    HStack {
                        Text("Loan Catalog")
                            .font(.staffTitle)
                            .foregroundColor(.staffTextPrimary)
                        Spacer()
                        Button(action: { showCreateSheet = true }) {
                            Image(systemName: "text.pad.header.badge.plus")
                                .font(.system(size: 20))
                                .foregroundColor(.staffAccent)
                        }
                    }
                    .padding(.horizontal, StaffSpacing.lg)
                    .padding(.top, StaffSpacing.lg)
                    
                    TextField("Search products...", text: $vm.searchText)
                        .padding(12)
                        .background(Color.staffSurface)
                        .cornerRadius(StaffCorner.md)
                        .foregroundColor(.staffTextPrimary)
                        .tint(.staffAccent)
                        .padding(.horizontal, StaffSpacing.lg)
                        .padding(.vertical, StaffSpacing.sm)
                }
                .background(Color.white)
                
                Divider().background(Color.staffBorder)
                
                if vm.isLoading {
                    Spacer()
                    ProgressView("Loading products...")
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else if vm.filteredProducts.isEmpty {
                    Spacer()
                    EmptyStateView(icon: "scroll", title: "No Products", message: "No loan products found. Create one to get started.")
                    Spacer()
                } else {
                    List(vm.filteredProducts, selection: $selectedProduct) { product in
                        HStack(spacing: StaffSpacing.md) {
                            Image(systemName: productIcon(for: product.type))
                                .font(.system(size: 20))
                                .foregroundColor(.staffAccent)
                                .frame(width: 36, height: 36)
                                .background(Color.staffAccentBg)
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(product.name)
                                    .font(.staffBody)
                                    .fontWeight(.bold)
                                    .foregroundColor(.staffTextPrimary)
                                Text(product.type.displayName)
                                    .font(.staffCaption)
                                    .foregroundColor(.staffTextSecondary)
                            }
                            
                            Spacer()
                            
                            // Active badge
                            Text(product.isActive ? "Active" : "Inactive")
                                .font(.staffBadge)
                                .foregroundColor(product.isActive ? .staffGreen : .staffTextTertiary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(product.isActive ? Color.staffGreenBg : Color.staffSurfaceLight)
                                .clipShape(Capsule())
                        }
                        .padding(.vertical, 4)
                        .tag(product)
                        .listRowBackground(Color.white)
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden)
                    .background(Color.staffBackground)
                }
            }
            .frame(width: 340)
            .background(Color.staffBackground)
            
            Divider().background(Color.staffBorder)
            
            // Right Detail Panel
            if let product = selectedProduct {
                ProductDetailPanel(product: product, vm: vm, selectedProduct: $selectedProduct)
            } else {
                VStack(spacing: StaffSpacing.md) {
                    Image(systemName: "scroll.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.staffTextSecondary.opacity(0.3))
                    Text("Select a Product to View Details")
                        .font(.staffTitle)
                        .foregroundColor(.staffTextSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.staffSurface.opacity(0.1))
            }
        }
        .background(Color.staffBackground)
        .onAppear {
            Task { await vm.loadProducts() }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateProductSheet(vm: vm, isPresented: $showCreateSheet)
        }
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }
    
    private func productIcon(for type: LoanType) -> String {
        switch type {
        case .personal: return "person.fill"
        case .home: return "house.fill"
        case .vehicle: return "car.fill"
        case .education: return "graduationcap.fill"
        case .business: return "building.2.fill"
        case .gold: return "sparkles"
        case .agriculture: return "leaf.fill"
        case .other: return "doc.fill"
        }
    }
}

// MARK: - Product Detail Panel

struct ProductDetailPanel: View {
    let product: LoanProduct
    @ObservedObject var vm: LoanProductViewModel
    @Binding var selectedProduct: LoanProduct?
    @State private var isEditing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.name)
                        .font(.staffTitle)
                        .foregroundColor(.staffTextPrimary)
                    Text("\(product.type.displayName) • \(product.isActive ? "Active" : "Inactive")")
                        .font(.staffCaption)
                        .foregroundColor(.staffTextSecondary)
                }
                Spacer()
                StaffButton(title: "Edit Product", style: .outline, icon: "pencil", isFullWidth: false) {
                    isEditing = true
                }
                .frame(width: 160)
            }
            .padding(StaffSpacing.lg)
            .background(Color.staffBackground)
            
            ScrollView {
                VStack(alignment: .leading, spacing: StaffSpacing.lg) {
                    // Description
                    if let desc = product.description, !desc.isEmpty {
                        StaffCard {
                            VStack(alignment: .leading, spacing: StaffSpacing.sm) {
                                Text("Description")
                                    .font(.staffSectionTitle)
                                    .foregroundColor(.staffTextPrimary)
                                Text(desc)
                                    .font(.staffBodyRegular)
                                    .foregroundColor(.staffTextSecondary)
                            }
                        }
                    }
                    
                    // Amount & Tenure
                    HStack(spacing: StaffSpacing.lg) {
                        StaffCard {
                            VStack(alignment: .leading, spacing: StaffSpacing.md) {
                                Text("Amount Range")
                                    .font(.staffSectionTitle)
                                    .foregroundColor(.staffTextPrimary)
                                Divider()
                                detailRow("Minimum", "₹\(formatAmount(product.minAmount))")
                                detailRow("Maximum", "₹\(formatAmount(product.maxAmount))")
                            }
                        }
                        
                        StaffCard {
                            VStack(alignment: .leading, spacing: StaffSpacing.md) {
                                Text("Tenure Range")
                                    .font(.staffSectionTitle)
                                    .foregroundColor(.staffTextPrimary)
                                Divider()
                                detailRow("Minimum", "\(product.minTenureMonths) months")
                                detailRow("Maximum", "\(product.maxTenureMonths) months")
                            }
                        }
                    }
                    
                    // Interest Configuration
                    StaffCard {
                        VStack(alignment: .leading, spacing: StaffSpacing.md) {
                            Text("Interest Configuration")
                                .font(.staffSectionTitle)
                                .foregroundColor(.staffTextPrimary)
                            Divider()
                            HStack(spacing: StaffSpacing.xxxl) {
                                detailRow("Min Rate", "\(String(format: "%.2f", product.minInterestRate))%")
                                detailRow("Max Rate", "\(String(format: "%.2f", product.maxInterestRate))%")
                                detailRow("Spread Over Base", "\(String(format: "%.2f", product.spreadOverBase))%")
                            }
                            
                            HStack(spacing: StaffSpacing.sm) {
                                Text("Interest Types:")
                                    .font(.staffLabel)
                                    .foregroundColor(.staffTextSecondary)
                                ForEach(product.supportedInterestTypes, id: \.self) { type in
                                    Text(type.displayName)
                                        .font(.staffBadge)
                                        .foregroundColor(.staffAccent)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.staffAccentBg)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    
                    // Fees & Configuration
                    HStack(spacing: StaffSpacing.lg) {
                        StaffCard {
                            VStack(alignment: .leading, spacing: StaffSpacing.md) {
                                Text("Fees & Penalties")
                                    .font(.staffSectionTitle)
                                    .foregroundColor(.staffTextPrimary)
                                Divider()
                                detailRow("Processing Fee", "\(String(format: "%.2f", product.processingFeePct))%")
                                detailRow("Prepayment Penalty", "\(String(format: "%.2f", product.prepaymentPenaltyPct))%")
                                detailRow("Late Penalty/Month", "\(String(format: "%.2f", product.latePenaltyPctPerMonth))%")
                            }
                        }
                        
                        StaffCard {
                            VStack(alignment: .leading, spacing: StaffSpacing.md) {
                                Text("Configuration")
                                    .font(.staffSectionTitle)
                                    .foregroundColor(.staffTextPrimary)
                                Divider()
                                detailRow("Requires Collateral", product.requiresCollateral ? "Yes" : "No")
                                detailRow("Status", product.isActive ? "Active" : "Inactive")
                            }
                        }
                    }
                    
                    // Eligibility Criteria
                    if let criteria = product.eligibilityCriteria, !criteria.isEmpty {
                        StaffCard {
                            VStack(alignment: .leading, spacing: StaffSpacing.md) {
                                Text("Eligibility Criteria")
                                    .font(.staffSectionTitle)
                                    .foregroundColor(.staffTextPrimary)
                                Divider()
                                ForEach(Array(criteria.keys.sorted()), id: \.self) { key in
                                    if let val = criteria[key] {
                                        detailRow(formatCriteriaKey(key), "\(val)")
                                    }
                                }
                            }
                        }
                    }
                    
                    // Required Documents
                    if let docs = product.requiredDocuments, !docs.isEmpty {
                        StaffCard {
                            VStack(alignment: .leading, spacing: StaffSpacing.md) {
                                Text("Required Documents (\(docs.count))")
                                    .font(.staffSectionTitle)
                                    .foregroundColor(.staffTextPrimary)
                                Divider()
                                ForEach(docs, id: \.self) { doc in
                                    HStack(spacing: StaffSpacing.sm) {
                                        Image(systemName: "doc.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.staffAccent)
                                        Text(doc.name)
                                            .font(.staffBody)
                                            .foregroundColor(.staffTextPrimary)
                                        if doc.isMandatory {
                                            Text("*")
                                                .font(.staffBody)
                                                .foregroundColor(.staffRed)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(StaffSpacing.lg)
            }
        }
        .background(Color.staffBackground)
        .sheet(isPresented: $isEditing) {
            EditProductSheet(product: product, vm: vm, isPresented: $isEditing, selectedProduct: $selectedProduct)
        }
    }
    
    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.staffLabel)
                .foregroundColor(.staffTextSecondary)
            Spacer()
            Text(value)
                .font(.staffBody)
                .foregroundColor(.staffTextPrimary)
        }
    }
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_IN")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
    
    private func formatCriteriaKey(_ key: String) -> String {
        key.replacingOccurrences(of: "_", with: " ").capitalized
    }
}


// MARK: - Create Product Sheet

struct CreateProductSheet: View {
    @ObservedObject var vm: LoanProductViewModel
    @Binding var isPresented: Bool
    
    // Basic Info
    @State private var name = ""
    @State private var selectedType: LoanType = .personal
    @State private var description = ""
    
    // Amount
    @State private var minAmount = ""
    @State private var maxAmount = ""
    
    // Tenure
    @State private var minTenure = ""
    @State private var maxTenure = ""
    
    // Interest
    @State private var minInterestRate = ""
    @State private var maxInterestRate = ""
    @State private var spreadOverBase = ""
    @State private var interestFixed = false
    @State private var interestFloating = false
    @State private var interestReducing = true
    
    // Fees
    @State private var processingFee = ""
    @State private var prepaymentPenalty = ""
    @State private var latePenalty = ""
    
    // Config
    @State private var requiresCollateral = false
    @State private var isActive = true
    
    // Eligibility
    @State private var minIncome = ""
    @State private var minCreditScore = ""
    @State private var minAge = ""
    @State private var maxAge = ""
    @State private var minBusinessYears = ""
    
    // Documents
    @State private var documentItems: [DocumentRequirement] = [
        DocumentRequirement(name: "Aadhaar Card", isMandatory: true),
        DocumentRequirement(name: "PAN Card", isMandatory: true)
    ]
    @State private var newDocText = ""
    
    // Validation
    @State private var validationError: String?
    @State private var validationClearTask: Task<Void, Never>?
    @State private var isCreating = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: StaffSpacing.xl) {
                    ZStack {
                        Circle()
                            .fill(Color.staffAccent)
                            .frame(width: 56, height: 56)
                        Image(systemName: "scroll.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.top, StaffSpacing.xl)
                    
                    Text("Create Loan Product")
                        .font(.staffSectionTitle)
                        .foregroundColor(.staffTextPrimary)
                    
                    validationWarning
                    
                    VStack(alignment: .leading, spacing: StaffSpacing.xxl) {
                        // Section 1: Basic Info
                        sectionHeader("Basic Information", icon: "info.circle.fill")
                        
                        StaffFormField(label: "Product Name *", placeholder: "e.g. Personal Loan Express", text: $name, icon: "textformat")
                        
                        VStack(alignment: .leading, spacing: StaffSpacing.sm) {
                            Text("Product Type")
                                .font(.staffLabel)
                                .foregroundColor(.staffTextSecondary)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: StaffSpacing.sm),
                                GridItem(.flexible(), spacing: StaffSpacing.sm),
                                GridItem(.flexible(), spacing: StaffSpacing.sm)
                            ], spacing: StaffSpacing.sm) {
                                ForEach(LoanType.allCases) { type in
                                    Button(action: {
                                        selectedType = type
                                    }) {
                                        HStack(spacing: StaffSpacing.xs) {
                                            Image(systemName: type.icon)
                                                .font(.system(size: 14))
                                            Text(type.displayName)
                                                .font(.staffLabel)
                                                .lineLimit(1)
                                        }
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, StaffSpacing.sm)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(selectedType == type ? Color.staffGreen : Color.staffSurfaceMuted)
                                        .foregroundColor(selectedType == type ? .white : .staffTextPrimary)
                                        .cornerRadius(StaffCorner.sm)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: StaffCorner.sm)
                                                .stroke(selectedType == type ? Color.staffGreen : Color.staffBorder, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        
                        StaffTextEditor(label: "Description", placeholder: "Describe this loan product, its target audience, and key features...", text: $description, minHeight: 80)
                    
                    Divider().background(Color.staffBorder)
                    
                    // Section 2: Amount
                    sectionHeader("Amount Limits (₹)", icon: "indianrupeesign.circle.fill")
                    
                    HStack(spacing: StaffSpacing.lg) {
                        StaffFormField(label: "Minimum Amount", placeholder: "e.g. 50,000", text: $minAmount, keyboardType: .decimalPad, inputSanitizer: sanitizePositiveDecimalInput, onInvalidInput: showInvalidNumberWarning)
                        StaffFormField(label: "Maximum Amount", placeholder: "e.g. 25,00,000", text: $maxAmount, keyboardType: .decimalPad, inputSanitizer: sanitizePositiveDecimalInput, onInvalidInput: showInvalidNumberWarning)
                    }
                    
                    Divider().background(Color.staffBorder)
                    
                    // Section 3: Tenure
                    sectionHeader("Tenure Range (Months)", icon: "calendar.circle.fill")
                    
                    HStack(spacing: StaffSpacing.lg) {
                        StaffFormField(label: "Min Tenure", placeholder: "e.g. 12", text: $minTenure, keyboardType: .numberPad, inputSanitizer: sanitizePositiveIntegerInput, onInvalidInput: showInvalidNumberWarning)
                        StaffFormField(label: "Max Tenure", placeholder: "e.g. 84", text: $maxTenure, keyboardType: .numberPad, inputSanitizer: sanitizePositiveIntegerInput, onInvalidInput: showInvalidNumberWarning)
                    }
                    
                    Divider().background(Color.staffBorder)
                    
                    // Section 4: Interest
                    sectionHeader("Interest Configuration", icon: "percent")
                    
                    HStack(spacing: StaffSpacing.lg) {
                        StaffFormField(label: "Min Interest Rate (%)", placeholder: "e.g. 9.50", text: $minInterestRate, keyboardType: .decimalPad, inputSanitizer: sanitizePositiveDecimalInput, onInvalidInput: showInvalidNumberWarning)
                        StaffFormField(label: "Max Interest Rate (%)", placeholder: "e.g. 16.00", text: $maxInterestRate, keyboardType: .decimalPad, inputSanitizer: sanitizePositiveDecimalInput, onInvalidInput: showInvalidNumberWarning)
                    }
                    
                    StaffFormField(label: "Spread Over Base Rate (%)", placeholder: "e.g. 2.25", text: $spreadOverBase, keyboardType: .decimalPad, inputSanitizer: sanitizePositiveDecimalInput, onInvalidInput: showInvalidNumberWarning)
                    
                    VStack(alignment: .leading, spacing: StaffSpacing.sm) {
                        Text("Supported Interest Types")
                            .font(.staffLabel)
                            .foregroundColor(.staffTextSecondary)
                        HStack(spacing: StaffSpacing.lg) {
                            interestTypeButton("Fixed", isSelected: interestFixed) {
                                interestFixed.toggle()
                                if interestFixed { interestReducing = false }
                            }
                            interestTypeButton("Floating", isSelected: interestFloating) {
                                interestFloating.toggle()
                                if interestFloating { interestReducing = false }
                            }
                            interestTypeButton("Reducing", isSelected: interestReducing) {
                                interestReducing.toggle()
                                if interestReducing {
                                    interestFixed = false
                                    interestFloating = false
                                }
                            }
                        }
                    }
                    
                    Divider().background(Color.staffBorder)
                    
                    // Section 5: Fees
                    sectionHeader("Fees & Penalties", icon: "banknote.fill")
                    
                    HStack(spacing: StaffSpacing.lg) {
                        StaffFormField(label: "Processing Fee (%)", placeholder: "e.g. 1.00", text: $processingFee, keyboardType: .decimalPad, inputSanitizer: sanitizePositiveDecimalInput, onInvalidInput: showInvalidNumberWarning)
                        StaffFormField(label: "Prepayment Penalty (%)", placeholder: "e.g. 2.00", text: $prepaymentPenalty, keyboardType: .decimalPad, inputSanitizer: sanitizePositiveDecimalInput, onInvalidInput: showInvalidNumberWarning)
                    }
                    StaffFormField(label: "Late Penalty (% per month)", placeholder: "e.g. 1.50", text: $latePenalty, keyboardType: .decimalPad, inputSanitizer: sanitizePositiveDecimalInput, onInvalidInput: showInvalidNumberWarning)
                    
                    Divider().background(Color.staffBorder)
                    
                    // Section 6: Configuration
                    sectionHeader("Product Configuration", icon: "gearshape.fill")
                    
                    HStack(spacing: StaffSpacing.xxxl) {
                        Toggle(isOn: $requiresCollateral) {
                            Text("Requires Collateral")
                                .font(.staffBody)
                                .foregroundColor(.staffTextPrimary)
                        }
                        .tint(.staffAccent)
                        
                        Toggle(isOn: $isActive) {
                            Text("Active on Launch")
                                .font(.staffBody)
                                .foregroundColor(.staffTextPrimary)
                        }
                        .tint(.staffGreen)
                    }
                    
                    Divider().background(Color.staffBorder)
                    
                    // Section 7: Eligibility
                    sectionHeader("Eligibility Criteria", icon: "checkmark.shield.fill")
                    
                    HStack(spacing: StaffSpacing.lg) {
                        StaffFormField(label: "Min Monthly Income (₹)", placeholder: "e.g. 30,000", text: $minIncome, keyboardType: .numberPad, inputSanitizer: sanitizePositiveIntegerInput, onInvalidInput: showInvalidNumberWarning)
                        StaffFormField(label: "Min Credit Score", placeholder: "e.g. 700", text: $minCreditScore, keyboardType: .numberPad, inputSanitizer: sanitizePositiveIntegerInput, onInvalidInput: showInvalidNumberWarning)
                    }
                    HStack(spacing: StaffSpacing.lg) {
                        StaffFormField(label: "Min Age (Years)", placeholder: "e.g. 21", text: $minAge, keyboardType: .numberPad, inputSanitizer: sanitizePositiveIntegerInput, onInvalidInput: showInvalidNumberWarning)
                        StaffFormField(label: "Max Age (Years)", placeholder: "e.g. 65", text: $maxAge, keyboardType: .numberPad, inputSanitizer: sanitizePositiveIntegerInput, onInvalidInput: showInvalidNumberWarning)
                    }
                    StaffFormField(label: "Min Business Years (if applicable)", placeholder: "e.g. 2", text: $minBusinessYears, keyboardType: .numberPad, inputSanitizer: sanitizePositiveIntegerInput, onInvalidInput: showInvalidNumberWarning)
                    
                    Divider().background(Color.staffBorder)
                    
                    // Section 8: Required Documents
                    sectionHeader("Required Documents Checklist", icon: "doc.text.fill")
                    
                    HStack {
                        TextField("Enter document name", text: $newDocText)
                            .padding(12)
                            .background(Color.staffSurfaceMuted)
                            .cornerRadius(StaffCorner.md)
                            .foregroundColor(.staffTextPrimary)
                            .tint(.staffAccent)
                        
                        Button(action: {
                            guard !newDocText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            documentItems.append(DocumentRequirement(name: newDocText.trimmingCharacters(in: .whitespaces), isMandatory: true))
                            newDocText = ""
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.staffAccent)
                        }
                    }
                    
                    ForEach(documentItems, id: \.self) { doc in
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundColor(.staffAccent)
                            Text(doc.name)
                                .font(.staffBody)
                                .foregroundColor(.staffTextPrimary)
                            Spacer()
                            Button(action: {
                                documentItems.removeAll { $0.id == doc.id }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.staffRed)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                }
                .padding(.horizontal, StaffSpacing.xl)
                
                StaffButton(title: "Create Product", style: .primary, icon: "plus.circle.fill", isLoading: isCreating) {
                    createProduct()
                }
                .disabled(isCreating)
                .padding(.horizontal, StaffSpacing.xl)
                .padding(.bottom, StaffSpacing.xl)
            }
            .background(Color.staffBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.staffAccent)
                }
            }
        }
        }
        .presentationBackground(Color.staffBackground)
        .preferredColorScheme(.dark)
    }
    
    private func createProduct() {
        validationError = nil
        
        // Validation
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            showValidationWarning("Product name is required")
            return
        }
        guard let minAmt = decimalValue(minAmount), minAmt > 0 else {
            showValidationWarning("Minimum amount must be greater than 0")
            return
        }
        guard let maxAmt = decimalValue(maxAmount), maxAmt > minAmt else {
            showValidationWarning("Maximum amount must be greater than minimum amount")
            return
        }
        guard let minTen = intValue(minTenure), minTen > 0 else {
            showValidationWarning("Minimum tenure must be greater than 0 months")
            return
        }
        guard let maxTen = intValue(maxTenure), maxTen > minTen else {
            showValidationWarning("Maximum tenure must be greater than minimum tenure")
            return
        }
        guard let minRate = decimalValue(minInterestRate), minRate >= 0, minRate <= 100 else {
            showValidationWarning("Minimum interest rate must be between 0 and 100")
            return
        }
        guard let maxRate = decimalValue(maxInterestRate), maxRate >= minRate, maxRate <= 100 else {
            showValidationWarning("Maximum interest rate must be at least the minimum rate and no more than 100")
            return
        }
        guard interestFixed || interestFloating || interestReducing else {
            showValidationWarning("Select at least one interest type")
            return
        }
        guard let spread = optionalPercentValue(spreadOverBase, field: "Spread over base rate") else { return }
        guard let processing = optionalPercentValue(processingFee, field: "Processing fee") else { return }
        guard let prepayment = optionalPercentValue(prepaymentPenalty, field: "Prepayment penalty") else { return }
        guard let late = optionalPercentValue(latePenalty, field: "Late penalty") else { return }
        guard validateOptionalEligibility() else { return }
        
        // Build interest types
        var types: [InterestType] = []
        if interestFixed { types.append(.fixed) }
        if interestFloating { types.append(.floating) }
        if interestReducing { types.append(.reducing) }
        
        // Build eligibility criteria
        var criteria: [String: Double] = [:]
        if let v = intValue(minIncome), v > 0 { criteria["min_income"] = Double(v) }
        if let v = intValue(minCreditScore), v > 0 { criteria["min_credit_score"] = Double(v) }
        if let v = intValue(minAge), v > 0 { criteria["min_age"] = Double(v) }
        if let v = intValue(maxAge), v > 0 { criteria["max_age"] = Double(v) }
        if let v = intValue(minBusinessYears), v > 0 { criteria["min_business_years"] = Double(v) }
        
        isCreating = true
        
        Task {
            let product = LoanProduct(
                id: UUID(),
                name: name.trimmingCharacters(in: .whitespaces),
                type: selectedType,
                description: description.isEmpty ? nil : description,
                minAmount: minAmt,
                maxAmount: maxAmt,
                minTenureMonths: minTen,
                maxTenureMonths: maxTen,
                minInterestRate: minRate,
                maxInterestRate: maxRate,
                supportedInterestTypes: types,
                spreadOverBase: spread,
                processingFeePct: processing,
                prepaymentPenaltyPct: prepayment,
                latePenaltyPctPerMonth: late,
                requiresCollateral: requiresCollateral,
                isActive: isActive,
                eligibilityCriteria: criteria.isEmpty ? nil : criteria,
                requiredDocuments: documentItems.isEmpty ? nil : documentItems,
                createdAt: nil,
                updatedAt: nil
            )
            
            let success = await vm.createProduct(product)
            isCreating = false
            if success {
                isPresented = false
            }
        }
    }
    
    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: StaffSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.staffAccent)
            Text(title)
                .font(.staffCardTitle)
                .foregroundColor(.staffTextPrimary)
        }
    }
    
    private func interestTypeButton(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.staffBody)
                .foregroundColor(isSelected ? .staffTextPrimary : .staffTextSecondary)
                .padding(.horizontal, StaffSpacing.lg)
                .padding(.vertical, StaffSpacing.sm)
                .background(isSelected ? Color.staffAccentBg : Color.staffSurfaceMuted)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var validationWarning: some View {
        if let error = validationError {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(error)
            }
            .font(.staffCaption)
            .foregroundColor(.staffRed)
            .padding(StaffSpacing.md)
            .background(Color.staffRedBg)
            .cornerRadius(StaffCorner.sm)
            .padding(.horizontal, StaffSpacing.xl)
        }
    }
    
    private func positiveDecimalBinding(_ text: Binding<String>, field: String) -> Binding<String> {
        Binding(
            get: { text.wrappedValue },
            set: { newValue in
                guard isValidPositiveNumberInput(newValue, allowsDecimal: true, field: field) else { return }
                text.wrappedValue = newValue
            }
        )
    }
    
    private func positiveIntegerBinding(_ text: Binding<String>, field: String) -> Binding<String> {
        Binding(
            get: { text.wrappedValue },
            set: { newValue in
                guard isValidPositiveNumberInput(newValue, allowsDecimal: false, field: field) else { return }
                text.wrappedValue = newValue
            }
        )
    }
    
    private func isValidPositiveNumberInput(_ value: String, allowsDecimal: Bool, field: String) -> Bool {
        guard !value.isEmpty else { return true }
        if value.contains("-") {
            showValidationWarning("\(field) cannot be negative")
            return false
        }
        if !allowsDecimal && value.contains(".") {
            showValidationWarning("\(field) must be a whole number")
            return false
        }
        if allowsDecimal && value.filter({ $0 == "." }).count > 1 {
            showValidationWarning("\(field) can contain only one decimal point")
            return false
        }
        let allowedCharacters = allowsDecimal ? "0123456789,." : "0123456789,"
        if value.contains(where: { !allowedCharacters.contains($0) }) {
            showValidationWarning("Only positive numbers are allowed for \(field.lowercased())")
            return false
        }
        return true
    }
    
    private func sanitizePositiveDecimalInput(_ value: String) -> String {
        sanitizePositiveNumberInput(value, allowsDecimal: true)
    }
    
    private func sanitizePositiveIntegerInput(_ value: String) -> String {
        sanitizePositiveNumberInput(value, allowsDecimal: false)
    }
    
    private func sanitizePositiveNumberInput(_ value: String, allowsDecimal: Bool) -> String {
        var result = ""
        var hasDecimal = false
        
        for character in value {
            if character.isNumber || character == "," {
                result.append(character)
            } else if allowsDecimal && character == "." && !hasDecimal {
                hasDecimal = true
                result.append(character)
            }
        }
        
        return result
    }
    
    private func showInvalidNumberWarning() {
        showValidationWarning("Enter a valid positive number")
    }
    
    private func showValidationWarning(_ message: String) {
        validationClearTask?.cancel()
        validationError = message
        validationClearTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled {
                validationError = nil
            }
        }
    }
    
    private func cleanedNumber(_ value: String) -> String {
        value.replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func decimalValue(_ value: String) -> Double? {
        Double(cleanedNumber(value))
    }
    
    private func intValue(_ value: String) -> Int? {
        Int(cleanedNumber(value))
    }
    
    private func optionalPercentValue(_ value: String, field: String) -> Double? {
        let cleaned = cleanedNumber(value)
        guard !cleaned.isEmpty else { return 0 }
        guard let number = Double(cleaned), number >= 0, number <= 100 else {
            showValidationWarning("\(field) must be between 0 and 100")
            return nil
        }
        return number
    }
    
    private func validateOptionalEligibility() -> Bool {
        if !cleanedNumber(minIncome).isEmpty, (intValue(minIncome) ?? -1) < 0 {
            showValidationWarning("Minimum monthly income cannot be negative")
            return false
        }
        if !cleanedNumber(minCreditScore).isEmpty {
            guard let score = intValue(minCreditScore), (300...900).contains(score) else {
                showValidationWarning("Minimum credit score must be between 300 and 900")
                return false
            }
        }
        let minAgeValue = intValue(minAge)
        let maxAgeValue = intValue(maxAge)
        if !cleanedNumber(minAge).isEmpty, !(18...75).contains(minAgeValue ?? -1) {
            showValidationWarning("Minimum age must be between 18 and 75")
            return false
        }
        if !cleanedNumber(maxAge).isEmpty, !(18...75).contains(maxAgeValue ?? -1) {
            showValidationWarning("Maximum age must be between 18 and 75")
            return false
        }
        if let minAgeValue, let maxAgeValue, maxAgeValue < minAgeValue {
            showValidationWarning("Maximum age must be greater than or equal to minimum age")
            return false
        }
        if !cleanedNumber(minBusinessYears).isEmpty, (intValue(minBusinessYears) ?? -1) < 0 {
            showValidationWarning("Minimum business years cannot be negative")
            return false
        }
        return true
    }
}

// MARK: - Edit Product Sheet

struct EditProductSheet: View {
    let product: LoanProduct
    @ObservedObject var vm: LoanProductViewModel
    @Binding var isPresented: Bool
    @Binding var selectedProduct: LoanProduct?
    
    @State private var name: String
    @State private var selectedType: LoanType
    @State private var description: String
    @State private var minAmount: String
    @State private var maxAmount: String
    @State private var minTenure: String
    @State private var maxTenure: String
    @State private var minInterestRate: String
    @State private var maxInterestRate: String
    @State private var spreadOverBase: String
    @State private var interestFixed: Bool
    @State private var interestFloating: Bool
    @State private var interestReducing: Bool
    @State private var processingFee: String
    @State private var prepaymentPenalty: String
    @State private var latePenalty: String
    @State private var requiresCollateral: Bool
    @State private var isActive: Bool
    @State private var minIncome: String
    @State private var minCreditScore: String
    @State private var minAge: String
    @State private var maxAge: String
    @State private var minBusinessYears: String
    @State private var documentItems: [DocumentRequirement]
    @State private var newDocText = ""
    @State private var validationError: String?
    @State private var validationClearTask: Task<Void, Never>?
    @State private var isSaving = false
    
    init(product: LoanProduct, vm: LoanProductViewModel, isPresented: Binding<Bool>, selectedProduct: Binding<LoanProduct?>) {
        self.product = product
        self.vm = vm
        self._isPresented = isPresented
        self._selectedProduct = selectedProduct
        
        _name = State(initialValue: product.name)
        _selectedType = State(initialValue: product.type)
        _description = State(initialValue: product.description ?? "")
        _minAmount = State(initialValue: "\(Int(product.minAmount))")
        _maxAmount = State(initialValue: "\(Int(product.maxAmount))")
        _minTenure = State(initialValue: "\(product.minTenureMonths)")
        _maxTenure = State(initialValue: "\(product.maxTenureMonths)")
        _minInterestRate = State(initialValue: String(format: "%.2f", product.minInterestRate))
        _maxInterestRate = State(initialValue: String(format: "%.2f", product.maxInterestRate))
        _spreadOverBase = State(initialValue: String(format: "%.2f", product.spreadOverBase))
        _interestFixed = State(initialValue: product.supportedInterestTypes.contains(.fixed))
        _interestFloating = State(initialValue: product.supportedInterestTypes.contains(.floating))
        _interestReducing = State(initialValue: product.supportedInterestTypes.contains(.reducing))
        _processingFee = State(initialValue: String(format: "%.2f", product.processingFeePct))
        _prepaymentPenalty = State(initialValue: String(format: "%.2f", product.prepaymentPenaltyPct))
        _latePenalty = State(initialValue: String(format: "%.2f", product.latePenaltyPctPerMonth))
        _requiresCollateral = State(initialValue: product.requiresCollateral)
        _isActive = State(initialValue: product.isActive)
        
        let criteria = product.eligibilityCriteria ?? [:]
        _minIncome = State(initialValue: criteria["min_income"].map { String(Int($0)) } ?? "")
        _minCreditScore = State(initialValue: criteria["min_credit_score"].map { String(Int($0)) } ?? "")
        _minAge = State(initialValue: criteria["min_age"].map { String(Int($0)) } ?? "")
        _maxAge = State(initialValue: criteria["max_age"].map { String(Int($0)) } ?? "")
        _minBusinessYears = State(initialValue: criteria["min_business_years"].map { String(Int($0)) } ?? "")
        _documentItems = State(initialValue: product.requiredDocuments ?? [])
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: StaffSpacing.xl) {
                    ZStack {
                        Circle()
                            .fill(Color.staffAccent)
                            .frame(width: 56, height: 56)
                        Image(systemName: "scroll.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.top, StaffSpacing.xl)
                    
                    Text("Edit \(product.name)")
                        .font(.staffSectionTitle)
                        .foregroundColor(.staffTextPrimary)
                        .multilineTextAlignment(.center)
                    
                    validationWarning
                    
                    VStack(alignment: .leading, spacing: StaffSpacing.xxl) {
                        sectionHeader("Basic Information", icon: "info.circle.fill")
                        StaffFormField(label: "Product Name *", placeholder: "e.g. Personal Loan Express", text: $name, icon: "textformat")
                        VStack(alignment: .leading, spacing: StaffSpacing.sm) {
                            Text("Product Type")
                                .font(.staffLabel)
                                .foregroundColor(.staffTextSecondary)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: StaffSpacing.sm),
                                GridItem(.flexible(), spacing: StaffSpacing.sm),
                                GridItem(.flexible(), spacing: StaffSpacing.sm)
                            ], spacing: StaffSpacing.sm) {
                                ForEach(LoanType.allCases) { type in
                                    Button(action: {
                                        selectedType = type
                                    }) {
                                        HStack(spacing: StaffSpacing.xs) {
                                            Image(systemName: type.icon)
                                                .font(.system(size: 14))
                                            Text(type.displayName)
                                                .font(.staffLabel)
                                                .lineLimit(1)
                                        }
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, StaffSpacing.sm)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(selectedType == type ? Color.staffGreen : Color.staffSurfaceMuted)
                                        .foregroundColor(selectedType == type ? .white : .staffTextPrimary)
                                        .cornerRadius(StaffCorner.sm)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: StaffCorner.sm)
                                                .stroke(selectedType == type ? Color.staffGreen : Color.staffBorder, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        StaffTextEditor(label: "Description", placeholder: "Product description...", text: $description, minHeight: 80)
                    
                    Divider().background(Color.staffBorder)
                    sectionHeader("Amount Limits (₹)", icon: "indianrupeesign.circle.fill")
                    HStack(spacing: StaffSpacing.lg) {
                        StaffFormField(label: "Minimum Amount", placeholder: "e.g. 50,000", text: $minAmount, keyboardType: .decimalPad, inputSanitizer: sanitizePositiveDecimalInput, onInvalidInput: showInvalidNumberWarning)
                        StaffFormField(label: "Maximum Amount", placeholder: "e.g. 25,00,000", text: $maxAmount, keyboardType: .decimalPad, inputSanitizer: sanitizePositiveDecimalInput, onInvalidInput: showInvalidNumberWarning)
                    }
                    
                    Divider().background(Color.staffBorder)
                    sectionHeader("Tenure Range (Months)", icon: "calendar.circle.fill")
                    HStack(spacing: StaffSpacing.lg) {
                        StaffFormField(label: "Min Tenure", placeholder: "e.g. 12", text: $minTenure, keyboardType: .numberPad, inputSanitizer: sanitizePositiveIntegerInput, onInvalidInput: showInvalidNumberWarning)
                        StaffFormField(label: "Max Tenure", placeholder: "e.g. 84", text: $maxTenure, keyboardType: .numberPad, inputSanitizer: sanitizePositiveIntegerInput, onInvalidInput: showInvalidNumberWarning)
                    }
                    
                    Divider().background(Color.staffBorder)
                    sectionHeader("Interest Configuration", icon: "percent")
                    HStack(spacing: StaffSpacing.lg) {
                        StaffFormField(label: "Min Interest Rate (%)", placeholder: "e.g. 9.50", text: $minInterestRate, keyboardType: .decimalPad, inputSanitizer: sanitizePositiveDecimalInput, onInvalidInput: showInvalidNumberWarning)
                        StaffFormField(label: "Max Interest Rate (%)", placeholder: "e.g. 16.00", text: $maxInterestRate, keyboardType: .decimalPad, inputSanitizer: sanitizePositiveDecimalInput, onInvalidInput: showInvalidNumberWarning)
                    }
                    StaffFormField(label: "Spread Over Base Rate (%)", placeholder: "e.g. 2.25", text: $spreadOverBase, keyboardType: .decimalPad, inputSanitizer: sanitizePositiveDecimalInput, onInvalidInput: showInvalidNumberWarning)
                    VStack(alignment: .leading, spacing: StaffSpacing.sm) {
                        Text("Supported Interest Types")
                            .font(.staffLabel)
                            .foregroundColor(.staffTextSecondary)
                        HStack(spacing: StaffSpacing.lg) {
                            interestTypeButton("Fixed", isSelected: interestFixed) {
                                interestFixed.toggle()
                                if interestFixed { interestReducing = false }
                            }
                            interestTypeButton("Floating", isSelected: interestFloating) {
                                interestFloating.toggle()
                                if interestFloating { interestReducing = false }
                            }
                            interestTypeButton("Reducing", isSelected: interestReducing) {
                                interestReducing.toggle()
                                if interestReducing {
                                    interestFixed = false
                                    interestFloating = false
                                }
                            }
                        }
                    }
                    
                    Divider().background(Color.staffBorder)
                    sectionHeader("Fees & Penalties", icon: "banknote.fill")
                    HStack(spacing: StaffSpacing.lg) {
                        StaffFormField(label: "Processing Fee (%)", placeholder: "e.g. 1.00", text: $processingFee, keyboardType: .decimalPad, inputSanitizer: sanitizePositiveDecimalInput, onInvalidInput: showInvalidNumberWarning)
                        StaffFormField(label: "Prepayment Penalty (%)", placeholder: "e.g. 2.00", text: $prepaymentPenalty, keyboardType: .decimalPad, inputSanitizer: sanitizePositiveDecimalInput, onInvalidInput: showInvalidNumberWarning)
                    }
                    StaffFormField(label: "Late Penalty (% per month)", placeholder: "e.g. 1.50", text: $latePenalty, keyboardType: .decimalPad, inputSanitizer: sanitizePositiveDecimalInput, onInvalidInput: showInvalidNumberWarning)
                    
                    Divider().background(Color.staffBorder)
                    sectionHeader("Product Configuration", icon: "gearshape.fill")
                    HStack(spacing: StaffSpacing.xxxl) {
                        Toggle(isOn: $requiresCollateral) {
                            Text("Requires Collateral").font(.staffBody).foregroundColor(.staffTextPrimary)
                        }.tint(.staffAccent)
                        Toggle(isOn: $isActive) {
                            Text("Active").font(.staffBody).foregroundColor(.staffTextPrimary)
                        }.tint(.staffGreen)
                    }
                    
                    Divider().background(Color.staffBorder)
                    sectionHeader("Eligibility Criteria", icon: "checkmark.shield.fill")
                    HStack(spacing: StaffSpacing.lg) {
                        StaffFormField(label: "Min Monthly Income (₹)", placeholder: "e.g. 30,000", text: $minIncome, keyboardType: .numberPad, inputSanitizer: sanitizePositiveIntegerInput, onInvalidInput: showInvalidNumberWarning)
                        StaffFormField(label: "Min Credit Score", placeholder: "e.g. 700", text: $minCreditScore, keyboardType: .numberPad, inputSanitizer: sanitizePositiveIntegerInput, onInvalidInput: showInvalidNumberWarning)
                    }
                    HStack(spacing: StaffSpacing.lg) {
                        StaffFormField(label: "Min Age (Years)", placeholder: "e.g. 21", text: $minAge, keyboardType: .numberPad, inputSanitizer: sanitizePositiveIntegerInput, onInvalidInput: showInvalidNumberWarning)
                        StaffFormField(label: "Max Age (Years)", placeholder: "e.g. 65", text: $maxAge, keyboardType: .numberPad, inputSanitizer: sanitizePositiveIntegerInput, onInvalidInput: showInvalidNumberWarning)
                    }
                    StaffFormField(label: "Min Business Years (if applicable)", placeholder: "e.g. 2", text: $minBusinessYears, keyboardType: .numberPad, inputSanitizer: sanitizePositiveIntegerInput, onInvalidInput: showInvalidNumberWarning)
                    
                    Divider().background(Color.staffBorder)
                    sectionHeader("Required Documents Checklist", icon: "doc.text.fill")
                    HStack {
                        TextField("Enter document name", text: $newDocText)
                            .padding(12)
                            .background(Color.staffSurfaceMuted)
                            .cornerRadius(StaffCorner.md)
                            .foregroundColor(.staffTextPrimary)
                            .tint(.staffAccent)
                        Button(action: {
                            guard !newDocText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            documentItems.append(DocumentRequirement(name: newDocText.trimmingCharacters(in: .whitespaces), isMandatory: true))
                            newDocText = ""
                        }) {
                            Image(systemName: "plus.circle.fill").font(.system(size: 28)).foregroundColor(.staffAccent)
                        }
                    }
                    ForEach(documentItems, id: \.self) { doc in
                        HStack {
                            Image(systemName: "doc.fill").foregroundColor(.staffAccent)
                            Text(doc.name).font(.staffBody).foregroundColor(.staffTextPrimary)
                            Spacer()
                            Button(action: { documentItems.removeAll { $0.id == doc.id } }) {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.staffRed)
                            }
                        }.padding(.vertical, 4)
                    }
                }
                .padding(.horizontal, StaffSpacing.xl)
                
                StaffButton(title: "Save Changes", style: .primary, icon: "checkmark.circle.fill", isLoading: isSaving) {
                    saveProduct()
                }
                .disabled(isSaving)
                .padding(.horizontal, StaffSpacing.xl)
                .padding(.bottom, StaffSpacing.xl)
            }
            .background(Color.staffBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.staffAccent)
                }
            }
        }
        }
        .presentationBackground(Color.staffBackground)
        .preferredColorScheme(.dark)
    }
    
    private func saveProduct() {
        validationError = nil
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { showValidationWarning("Product name is required"); return }
        guard let minAmt = decimalValue(minAmount), minAmt > 0 else { showValidationWarning("Minimum amount must be greater than 0"); return }
        guard let maxAmt = decimalValue(maxAmount), maxAmt > minAmt else { showValidationWarning("Maximum amount must be greater than minimum amount"); return }
        guard let minTen = intValue(minTenure), minTen > 0 else { showValidationWarning("Minimum tenure must be greater than 0 months"); return }
        guard let maxTen = intValue(maxTenure), maxTen > minTen else { showValidationWarning("Maximum tenure must be greater than minimum tenure"); return }
        guard let minRate = decimalValue(minInterestRate), minRate >= 0, minRate <= 100 else { showValidationWarning("Minimum interest rate must be between 0 and 100"); return }
        guard let maxRate = decimalValue(maxInterestRate), maxRate >= minRate, maxRate <= 100 else { showValidationWarning("Maximum interest rate must be at least the minimum rate and no more than 100"); return }
        guard interestFixed || interestFloating || interestReducing else { showValidationWarning("Select at least one interest type"); return }
        guard let spread = optionalPercentValue(spreadOverBase, field: "Spread over base rate") else { return }
        guard let processing = optionalPercentValue(processingFee, field: "Processing fee") else { return }
        guard let prepayment = optionalPercentValue(prepaymentPenalty, field: "Prepayment penalty") else { return }
        guard let late = optionalPercentValue(latePenalty, field: "Late penalty") else { return }
        guard validateOptionalEligibility() else { return }
        
        var types: [InterestType] = []
        if interestFixed { types.append(.fixed) }
        if interestFloating { types.append(.floating) }
        if interestReducing { types.append(.reducing) }
        
        var criteria: [String: Double] = [:]
        if let v = intValue(minIncome), v > 0 { criteria["min_income"] = Double(v) }
        if let v = intValue(minCreditScore), v > 0 { criteria["min_credit_score"] = Double(v) }
        if let v = intValue(minAge), v > 0 { criteria["min_age"] = Double(v) }
        if let v = intValue(maxAge), v > 0 { criteria["max_age"] = Double(v) }
        if let v = intValue(minBusinessYears), v > 0 { criteria["min_business_years"] = Double(v) }
        
        isSaving = true
        
        var updated = product
        updated.name = name.trimmingCharacters(in: .whitespaces)
        updated.type = selectedType
        updated.description = description.isEmpty ? nil : description
        updated.minAmount = minAmt
        updated.maxAmount = maxAmt
        updated.minTenureMonths = minTen
        updated.maxTenureMonths = maxTen
        updated.minInterestRate = minRate
        updated.maxInterestRate = maxRate
        updated.supportedInterestTypes = types
        updated.spreadOverBase = spread
        updated.processingFeePct = processing
        updated.prepaymentPenaltyPct = prepayment
        updated.latePenaltyPctPerMonth = late
        updated.requiresCollateral = requiresCollateral
        updated.isActive = isActive
        updated.eligibilityCriteria = criteria.isEmpty ? nil : criteria
        updated.requiredDocuments = documentItems.isEmpty ? nil : documentItems
        
        Task {
            let success = await vm.updateProduct(updated)
            isSaving = false
            if success {
                selectedProduct = updated
                isPresented = false
            }
        }
    }
    
    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: StaffSpacing.sm) {
            Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundColor(.staffAccent)
            Text(title).font(.staffCardTitle).foregroundColor(.staffTextPrimary)
        }
    }
    
    private func interestTypeButton(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.staffBody)
                .foregroundColor(isSelected ? .staffTextPrimary : .staffTextSecondary)
                .padding(.horizontal, StaffSpacing.lg)
                .padding(.vertical, StaffSpacing.sm)
                .background(isSelected ? Color.staffAccentBg : Color.staffSurfaceMuted)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var validationWarning: some View {
        if let error = validationError {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(error)
            }
            .font(.staffCaption)
            .foregroundColor(.staffRed)
            .padding(StaffSpacing.md)
            .background(Color.staffRedBg)
            .cornerRadius(StaffCorner.sm)
            .padding(.horizontal, StaffSpacing.xl)
        }
    }
    
    private func positiveDecimalBinding(_ text: Binding<String>, field: String) -> Binding<String> {
        Binding(
            get: { text.wrappedValue },
            set: { newValue in
                guard isValidPositiveNumberInput(newValue, allowsDecimal: true, field: field) else { return }
                text.wrappedValue = newValue
            }
        )
    }
    
    private func positiveIntegerBinding(_ text: Binding<String>, field: String) -> Binding<String> {
        Binding(
            get: { text.wrappedValue },
            set: { newValue in
                guard isValidPositiveNumberInput(newValue, allowsDecimal: false, field: field) else { return }
                text.wrappedValue = newValue
            }
        )
    }
    
    private func isValidPositiveNumberInput(_ value: String, allowsDecimal: Bool, field: String) -> Bool {
        guard !value.isEmpty else { return true }
        if value.contains("-") {
            showValidationWarning("\(field) cannot be negative")
            return false
        }
        if !allowsDecimal && value.contains(".") {
            showValidationWarning("\(field) must be a whole number")
            return false
        }
        if allowsDecimal && value.filter({ $0 == "." }).count > 1 {
            showValidationWarning("\(field) can contain only one decimal point")
            return false
        }
        let allowedCharacters = allowsDecimal ? "0123456789,." : "0123456789,"
        if value.contains(where: { !allowedCharacters.contains($0) }) {
            showValidationWarning("Only positive numbers are allowed for \(field.lowercased())")
            return false
        }
        return true
    }
    
    private func sanitizePositiveDecimalInput(_ value: String) -> String {
        sanitizePositiveNumberInput(value, allowsDecimal: true)
    }
    
    private func sanitizePositiveIntegerInput(_ value: String) -> String {
        sanitizePositiveNumberInput(value, allowsDecimal: false)
    }
    
    private func sanitizePositiveNumberInput(_ value: String, allowsDecimal: Bool) -> String {
        var result = ""
        var hasDecimal = false
        
        for character in value {
            if character.isNumber || character == "," {
                result.append(character)
            } else if allowsDecimal && character == "." && !hasDecimal {
                hasDecimal = true
                result.append(character)
            }
        }
        
        return result
    }
    
    private func showInvalidNumberWarning() {
        showValidationWarning("Enter a valid positive number")
    }
    
    private func showValidationWarning(_ message: String) {
        validationClearTask?.cancel()
        validationError = message
        validationClearTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled {
                validationError = nil
            }
        }
    }
    
    private func cleanedNumber(_ value: String) -> String {
        value.replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func decimalValue(_ value: String) -> Double? {
        Double(cleanedNumber(value))
    }
    
    private func intValue(_ value: String) -> Int? {
        Int(cleanedNumber(value))
    }
    
    private func optionalPercentValue(_ value: String, field: String) -> Double? {
        let cleaned = cleanedNumber(value)
        guard !cleaned.isEmpty else { return 0 }
        guard let number = Double(cleaned), number >= 0, number <= 100 else {
            showValidationWarning("\(field) must be between 0 and 100")
            return nil
        }
        return number
    }
    
    private func validateOptionalEligibility() -> Bool {
        if !cleanedNumber(minIncome).isEmpty, (intValue(minIncome) ?? -1) < 0 {
            showValidationWarning("Minimum monthly income cannot be negative")
            return false
        }
        if !cleanedNumber(minCreditScore).isEmpty {
            guard let score = intValue(minCreditScore), (300...900).contains(score) else {
                showValidationWarning("Minimum credit score must be between 300 and 900")
                return false
            }
        }
        let minAgeValue = intValue(minAge)
        let maxAgeValue = intValue(maxAge)
        if !cleanedNumber(minAge).isEmpty, !(18...75).contains(minAgeValue ?? -1) {
            showValidationWarning("Minimum age must be between 18 and 75")
            return false
        }
        if !cleanedNumber(maxAge).isEmpty, !(18...75).contains(maxAgeValue ?? -1) {
            showValidationWarning("Maximum age must be between 18 and 75")
            return false
        }
        if let minAgeValue, let maxAgeValue, maxAgeValue < minAgeValue {
            showValidationWarning("Maximum age must be greater than or equal to minimum age")
            return false
        }
        if !cleanedNumber(minBusinessYears).isEmpty, (intValue(minBusinessYears) ?? -1) < 0 {
            showValidationWarning("Minimum business years cannot be negative")
            return false
        }
        return true
    }
}
