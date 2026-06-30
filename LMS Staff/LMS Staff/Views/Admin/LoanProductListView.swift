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
                HStack {
                    Text("Loan Catalog")
                        .font(.staffTitle)
                        .foregroundColor(.staffTextPrimary)
                    Spacer()
                    StaffButton(title: "New Product", style: .primary, icon: "plus.circle.fill", isFullWidth: false) {
                        showCreateSheet = true
                    }
                    .frame(width: 180)
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
                                .clipShape(RoundedRectangle(cornerRadius: StaffCorner.sm))
                            
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
                        .listRowBackground(Color.staffSurface)
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
            .background(Color.staffSurface)
            
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
    @State private var isCreating = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: StaffSpacing.xxl) {
                    // Section 1: Basic Info
                    sectionHeader("Basic Information", icon: "info.circle.fill")
                    
                    StaffFormField(label: "Product Name", placeholder: "e.g. Personal Loan Express", text: $name)
                    
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
                        StaffFormField(label: "Minimum Amount", placeholder: "50000", text: $minAmount, keyboardType: .decimalPad)
                        StaffFormField(label: "Maximum Amount", placeholder: "2500000", text: $maxAmount, keyboardType: .decimalPad)
                    }
                    
                    Divider().background(Color.staffBorder)
                    
                    // Section 3: Tenure
                    sectionHeader("Tenure Range (Months)", icon: "calendar.circle.fill")
                    
                    HStack(spacing: StaffSpacing.lg) {
                        StaffFormField(label: "Min Tenure", placeholder: "6", text: $minTenure, keyboardType: .numberPad)
                        StaffFormField(label: "Max Tenure", placeholder: "60", text: $maxTenure, keyboardType: .numberPad)
                    }
                    
                    Divider().background(Color.staffBorder)
                    
                    // Section 4: Interest
                    sectionHeader("Interest Configuration", icon: "percent")
                    
                    HStack(spacing: StaffSpacing.lg) {
                        StaffFormField(label: "Min Interest Rate (%)", placeholder: "8.50", text: $minInterestRate, keyboardType: .decimalPad)
                        StaffFormField(label: "Max Interest Rate (%)", placeholder: "14.50", text: $maxInterestRate, keyboardType: .decimalPad)
                    }
                    
                    StaffFormField(label: "Spread Over Base Rate (%)", placeholder: "2.00", text: $spreadOverBase, keyboardType: .decimalPad)
                    
                    VStack(alignment: .leading, spacing: StaffSpacing.sm) {
                        Text("Supported Interest Types")
                            .font(.staffLabel)
                            .foregroundColor(.staffTextSecondary)
                        HStack(spacing: StaffSpacing.lg) {
                            interestTypeToggle("Fixed", isOn: $interestFixed)
                            interestTypeToggle("Floating", isOn: $interestFloating)
                            interestTypeToggle("Reducing", isOn: $interestReducing)
                        }
                    }
                    
                    Divider().background(Color.staffBorder)
                    
                    // Section 5: Fees
                    sectionHeader("Fees & Penalties", icon: "banknote.fill")
                    
                    HStack(spacing: StaffSpacing.lg) {
                        StaffFormField(label: "Processing Fee (%)", placeholder: "1.50", text: $processingFee, keyboardType: .decimalPad)
                        StaffFormField(label: "Prepayment Penalty (%)", placeholder: "2.00", text: $prepaymentPenalty, keyboardType: .decimalPad)
                    }
                    StaffFormField(label: "Late Penalty (% per month)", placeholder: "2.00", text: $latePenalty, keyboardType: .decimalPad)
                    
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
                        StaffFormField(label: "Min Monthly Income (₹)", placeholder: "25000", text: $minIncome, keyboardType: .numberPad)
                        StaffFormField(label: "Min Credit Score", placeholder: "650", text: $minCreditScore, keyboardType: .numberPad)
                    }
                    HStack(spacing: StaffSpacing.lg) {
                        StaffFormField(label: "Min Age (Years)", placeholder: "21", text: $minAge, keyboardType: .numberPad)
                        StaffFormField(label: "Max Age (Years)", placeholder: "58", text: $maxAge, keyboardType: .numberPad)
                    }
                    StaffFormField(label: "Min Business Years (if applicable)", placeholder: "3", text: $minBusinessYears, keyboardType: .numberPad)
                    
                    Divider().background(Color.staffBorder)
                    
                    // Section 8: Required Documents
                    sectionHeader("Required Documents Checklist", icon: "doc.text.fill")
                    
                    HStack {
                        TextField("Add document requirement...", text: $newDocText)
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
                    
                    if let error = validationError {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.staffRed)
                            Text(error)
                                .font(.staffCaption)
                                .foregroundColor(.staffRed)
                        }
                    }
                }
                .padding(StaffSpacing.xxl)
            }
            .background(Color.staffBackground.ignoresSafeArea())
            .navigationTitle("Create Loan Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                        .foregroundColor(.staffTextSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: createProduct) {
                        if isCreating {
                            ProgressView()
                        } else {
                            Text("Create Product")
                                .fontWeight(.bold)
                        }
                    }
                    .disabled(isCreating)
                    .foregroundColor(.staffAccent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func createProduct() {
        validationError = nil
        
        // Validation
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationError = "Product name is required"
            return
        }
        guard let minAmt = Double(minAmount), minAmt > 0 else {
            validationError = "Enter a valid minimum amount"
            return
        }
        guard let maxAmt = Double(maxAmount), maxAmt > minAmt else {
            validationError = "Maximum amount must be greater than minimum"
            return
        }
        guard let minTen = Int(minTenure), minTen > 0 else {
            validationError = "Enter a valid minimum tenure"
            return
        }
        guard let maxTen = Int(maxTenure), maxTen > minTen else {
            validationError = "Maximum tenure must be greater than minimum"
            return
        }
        guard let minRate = Double(minInterestRate), minRate >= 0 else {
            validationError = "Enter a valid minimum interest rate"
            return
        }
        guard let maxRate = Double(maxInterestRate), maxRate >= minRate else {
            validationError = "Maximum rate must be ≥ minimum rate"
            return
        }
        guard interestFixed || interestFloating || interestReducing else {
            validationError = "Select at least one interest type"
            return
        }
        
        // Build interest types
        var types: [InterestType] = []
        if interestFixed { types.append(.fixed) }
        if interestFloating { types.append(.floating) }
        if interestReducing { types.append(.reducing) }
        
        // Build eligibility criteria
        var criteria: [String: Double] = [:]
        if let v = Int(minIncome), v > 0 { criteria["min_income"] = Double(v) }
        if let v = Int(minCreditScore), v > 0 { criteria["min_credit_score"] = Double(v) }
        if let v = Int(minAge), v > 0 { criteria["min_age"] = Double(v) }
        if let v = Int(maxAge), v > 0 { criteria["max_age"] = Double(v) }
        if let v = Int(minBusinessYears), v > 0 { criteria["min_business_years"] = Double(v) }
        
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
                spreadOverBase: Double(spreadOverBase) ?? 0.0,
                processingFeePct: Double(processingFee) ?? 0.0,
                prepaymentPenaltyPct: Double(prepaymentPenalty) ?? 0.0,
                latePenaltyPctPerMonth: Double(latePenalty) ?? 0.0,
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
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.staffAccent)
            Text(title)
                .font(.staffSectionTitle)
                .foregroundColor(.staffTextPrimary)
        }
    }
    
    private func interestTypeToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(label)
                .font(.staffBody)
                .foregroundColor(.staffTextPrimary)
        }
        .toggleStyle(.button)
        .tint(.staffAccent)
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
                VStack(alignment: .leading, spacing: StaffSpacing.xxl) {
                    sectionHeader("Basic Information", icon: "info.circle.fill")
                    StaffFormField(label: "Product Name", placeholder: "Product name", text: $name)
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
                        StaffFormField(label: "Minimum Amount", placeholder: "50000", text: $minAmount, keyboardType: .decimalPad)
                        StaffFormField(label: "Maximum Amount", placeholder: "2500000", text: $maxAmount, keyboardType: .decimalPad)
                    }
                    
                    Divider().background(Color.staffBorder)
                    sectionHeader("Tenure Range (Months)", icon: "calendar.circle.fill")
                    HStack(spacing: StaffSpacing.lg) {
                        StaffFormField(label: "Min Tenure", placeholder: "6", text: $minTenure, keyboardType: .numberPad)
                        StaffFormField(label: "Max Tenure", placeholder: "60", text: $maxTenure, keyboardType: .numberPad)
                    }
                    
                    Divider().background(Color.staffBorder)
                    sectionHeader("Interest Configuration", icon: "percent")
                    HStack(spacing: StaffSpacing.lg) {
                        StaffFormField(label: "Min Interest Rate (%)", placeholder: "8.50", text: $minInterestRate, keyboardType: .decimalPad)
                        StaffFormField(label: "Max Interest Rate (%)", placeholder: "14.50", text: $maxInterestRate, keyboardType: .decimalPad)
                    }
                    StaffFormField(label: "Spread Over Base Rate (%)", placeholder: "2.00", text: $spreadOverBase, keyboardType: .decimalPad)
                    VStack(alignment: .leading, spacing: StaffSpacing.sm) {
                        Text("Supported Interest Types")
                            .font(.staffLabel)
                            .foregroundColor(.staffTextSecondary)
                        HStack(spacing: StaffSpacing.lg) {
                            interestTypeToggle("Fixed", isOn: $interestFixed)
                            interestTypeToggle("Floating", isOn: $interestFloating)
                            interestTypeToggle("Reducing", isOn: $interestReducing)
                        }
                    }
                    
                    Divider().background(Color.staffBorder)
                    sectionHeader("Fees & Penalties", icon: "banknote.fill")
                    HStack(spacing: StaffSpacing.lg) {
                        StaffFormField(label: "Processing Fee (%)", placeholder: "1.50", text: $processingFee, keyboardType: .decimalPad)
                        StaffFormField(label: "Prepayment Penalty (%)", placeholder: "2.00", text: $prepaymentPenalty, keyboardType: .decimalPad)
                    }
                    StaffFormField(label: "Late Penalty (% per month)", placeholder: "2.00", text: $latePenalty, keyboardType: .decimalPad)
                    
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
                        StaffFormField(label: "Min Monthly Income (₹)", placeholder: "25000", text: $minIncome, keyboardType: .numberPad)
                        StaffFormField(label: "Min Credit Score", placeholder: "650", text: $minCreditScore, keyboardType: .numberPad)
                    }
                    HStack(spacing: StaffSpacing.lg) {
                        StaffFormField(label: "Min Age", placeholder: "21", text: $minAge, keyboardType: .numberPad)
                        StaffFormField(label: "Max Age", placeholder: "58", text: $maxAge, keyboardType: .numberPad)
                    }
                    StaffFormField(label: "Min Business Years", placeholder: "3", text: $minBusinessYears, keyboardType: .numberPad)
                    
                    Divider().background(Color.staffBorder)
                    sectionHeader("Required Documents", icon: "doc.text.fill")
                    HStack {
                        TextField("Add document...", text: $newDocText)
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
                    
                    if let error = validationError {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.staffRed)
                            Text(error).font(.staffCaption).foregroundColor(.staffRed)
                        }
                    }
                }
                .padding(StaffSpacing.xxl)
            }
            .background(Color.staffBackground.ignoresSafeArea())
            .navigationTitle("Edit \(product.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }.foregroundColor(.staffTextSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: saveProduct) {
                        if isSaving { ProgressView() } else { Text("Save Changes").fontWeight(.bold) }
                    }
                    .disabled(isSaving)
                    .foregroundColor(.staffAccent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func saveProduct() {
        validationError = nil
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { validationError = "Product name is required"; return }
        guard let minAmt = Double(minAmount), minAmt > 0 else { validationError = "Enter a valid minimum amount"; return }
        guard let maxAmt = Double(maxAmount), maxAmt > minAmt else { validationError = "Max amount must be > min amount"; return }
        guard let minTen = Int(minTenure), minTen > 0 else { validationError = "Enter a valid min tenure"; return }
        guard let maxTen = Int(maxTenure), maxTen > minTen else { validationError = "Max tenure must be > min tenure"; return }
        guard let minRate = Double(minInterestRate), minRate >= 0 else { validationError = "Enter valid min rate"; return }
        guard let maxRate = Double(maxInterestRate), maxRate >= minRate else { validationError = "Max rate must be ≥ min rate"; return }
        guard interestFixed || interestFloating || interestReducing else { validationError = "Select at least one interest type"; return }
        
        var types: [InterestType] = []
        if interestFixed { types.append(.fixed) }
        if interestFloating { types.append(.floating) }
        if interestReducing { types.append(.reducing) }
        
        var criteria: [String: Double] = [:]
        if let v = Int(minIncome), v > 0 { criteria["min_income"] = Double(v) }
        if let v = Int(minCreditScore), v > 0 { criteria["min_credit_score"] = Double(v) }
        if let v = Int(minAge), v > 0 { criteria["min_age"] = Double(v) }
        if let v = Int(maxAge), v > 0 { criteria["max_age"] = Double(v) }
        if let v = Int(minBusinessYears), v > 0 { criteria["min_business_years"] = Double(v) }
        
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
        updated.spreadOverBase = Double(spreadOverBase) ?? 0.0
        updated.processingFeePct = Double(processingFee) ?? 0.0
        updated.prepaymentPenaltyPct = Double(prepaymentPenalty) ?? 0.0
        updated.latePenaltyPctPerMonth = Double(latePenalty) ?? 0.0
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
            Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundColor(.staffAccent)
            Text(title).font(.staffSectionTitle).foregroundColor(.staffTextPrimary)
        }
    }
    
    private func interestTypeToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(label).font(.staffBody).foregroundColor(.staffTextPrimary)
        }
        .toggleStyle(.button)
        .tint(.staffAccent)
    }
}
