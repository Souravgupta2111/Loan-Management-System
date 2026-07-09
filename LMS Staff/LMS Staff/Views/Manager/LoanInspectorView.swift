//
//  LoanInspectorView.swift
//  LMS Staff
//
//  Unified detail view for Active and NPA loans.
//

import SwiftUI

struct LoanInspectorView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    let loanWithDetails: LoanWithDetails
    let onActionTriggered: () -> Void
    
    @StateObject private var vm: LoanDetailViewModel
    @Environment(\.openURL) private var openURL
    @Environment(\.presentationMode) private var presentationMode
    
    @State private var activeTab: InspectorTab = .profile
    
    // Bottom Action Sheets
    @State private var showRestructureSheet: Bool = false
    @State private var showWriteOffSheet: Bool = false
    @State private var showEscalateSheet: Bool = false
    @State private var reason: String = ""
    @State private var isProcessing: Bool = false
    
    // Restructure parameters
    @State private var revisedRate: Double = 0.0
    @State private var revisedTenure: Int = 0
    @State private var waivedPenalty: Double = 0.0
    
    enum InspectorTab: String, CaseIterable {
        case profile = "KYC & Credit"
        case documents = "Documents"
        case emiSchedule = "EMI Schedule"
        case recovery = "Recovery"
        case chat = "Chat Support"
        case timeline = "Timeline Log"
    }
    
    init(loanWithDetails: LoanWithDetails, onActionTriggered: @escaping () -> Void) {
        self.loanWithDetails = loanWithDetails
        self.onActionTriggered = onActionTriggered
        _vm = StateObject(wrappedValue: LoanDetailViewModel(loanWithDetails: loanWithDetails))
    }
    
    var visibleTabs: [InspectorTab] {
        var tabs: [InspectorTab] = [.profile, .documents]
        
        if vm.loanWithDetails.loan.status == .active || vm.loanWithDetails.loan.status == .restructured {
            tabs.append(.emiSchedule)
        } else if vm.loanWithDetails.loan.status == .npa {
            tabs.append(.recovery)
        }
        
        tabs.append(contentsOf: [.chat, .timeline])
        return tabs
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Info Bar
            HStack(spacing: StaffSpacing.lg) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(vm.loanWithDetails.borrower.fullName)
                            .font(.staffTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.staffTextPrimary)
                        
                        StaffStatusBadge(status: vm.loanWithDetails.loan.status.displayName)
                    }
                    
                    Text("Loan No: \(vm.loanWithDetails.loan.loanNumber ?? "N/A") | Product: \(vm.loanWithDetails.product.name)")
                        .font(.staffCaption)
                        .foregroundColor(.staffTextSecondary)
                }
                
                Spacer()
                
                // Primary Application metrics
                HStack(spacing: StaffSpacing.lg) {
                    if let app = vm.application {
                        InspectorDetailMetric(label: "Asked", value: "INR \(String(format: "%.2f", app.requestedAmount))")
                    } else {
                        InspectorDetailMetric(label: "Asked", value: "INR --")
                    }
                    InspectorDetailMetric(label: "Disbursed", value: "INR \(String(format: "%.2f", vm.loanWithDetails.loan.principalAmount))")
                    InspectorDetailMetric(label: "Outstanding", value: "INR \(String(format: "%.2f", vm.loanWithDetails.loan.outstandingPrincipal))")
                    if vm.loanWithDetails.loan.status == .npa {
                        InspectorDetailMetric(label: "Overdue Days", value: "\(vm.loanWithDetails.loan.overdueDays)")
                    }
                    InspectorDetailMetric(label: "Branch", value: "HQ - Main Branch")
                }
            }
            .padding(StaffSpacing.lg)
            .background(Color.staffSurface)
            
            // Tab Selector bar
            HStack(spacing: 0) {
                ForEach(visibleTabs, id: \.self) { tab in
                    Button(action: { activeTab = tab }) {
                        VStack(spacing: 0) {
                            Text(tab.rawValue)
                                .font(.staffBody)
                                .fontWeight(activeTab == tab ? .bold : .regular)
                                .foregroundColor(activeTab == tab ? .staffAccent : .staffTextSecondary)
                                .padding(.vertical, 12)
                            
                            // Indicator line
                            Rectangle()
                                .fill(activeTab == tab ? Color.staffAccent : Color.clear)
                                .frame(height: 3)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .background(Color.staffSurface.opacity(0.5))
            
            // Content Body based on selected Tab
            if activeTab == .chat {
                if let appWithBorrower = vm.appWithBorrower {
                    ChatSupportConsole(appWithBorrower: appWithBorrower, forceInternalOnly: true)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: StaffSpacing.xl) {
                        switch activeTab {
                        case .profile:
                            kycAndCreditSection
                        case .documents:
                            documentsSection
                        case .emiSchedule:
                            emiScheduleSection
                        case .recovery:
                            recoverySection
                        case .chat:
                            EmptyView()
                        case .timeline:
                            timelineSection
                        }
                    }
                    .padding(StaffSpacing.lg)
                }
                .background(Color.staffBackground)
            }
            
            if activeTab != .chat && activeTab != .timeline {
                if vm.loanWithDetails.loan.status == .npa && authViewModel.currentUser?.role == .manager {
                    Divider()
                        .background(Color.staffBorder)
                    actionButtonBar
                }
            }
        }
        .task {
            await vm.loadAllDetails()
            // Reset tab if it became invalid
            if !visibleTabs.contains(activeTab) {
                activeTab = .profile
            }
        }
        .navigationTitle("Loan Inspector")
        .navigationBarTitleDisplayMode(.inline)
        // MODALS/SHEETS LIST
        .sheet(isPresented: $showRestructureSheet) {
            restructureActionSheet()
                .presentationBackground(Color.staffBackground)
        }
        .sheet(isPresented: $showWriteOffSheet) {
            actionSheet(title: "Write-off Loan", actionColor: .staffRed, actionLabel: "Confirm Write-Off") {
                Task {
                    isProcessing = true
                    try? await NPAService.shared.writeOffLoan(loan: vm.loanWithDetails.loan, reason: reason)
                    isProcessing = false
                    showWriteOffSheet = false
                    onActionTriggered()
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .presentationBackground(Color.staffBackground)
        }
        .sheet(isPresented: $showEscalateSheet) {
            actionSheet(title: "Escalate to Admin", actionColor: .staffRed, actionLabel: "Escalate") {
                Task {
                    isProcessing = true
                    try? await NPAService.shared.escalateToAdmin(loan: vm.loanWithDetails.loan, reason: reason)
                    isProcessing = false
                    showEscalateSheet = false
                    onActionTriggered()
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .presentationBackground(Color.staffBackground)
        }
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { isPresented in if !isPresented { vm.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "An unknown error occurred.")
        }
    }
    
    // MARK: - Subviews
    
    private var kycAndCreditSection: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.lg) {
            HStack(alignment: .top, spacing: StaffSpacing.lg) {
                VStack(spacing: StaffSpacing.lg) {
                    // Personal KYC info
                    StaffCard {
                        VStack(alignment: .leading, spacing: StaffSpacing.md) {
                            Text("Borrower Details")
                                .font(.staffTitle)
                                .foregroundColor(.staffTextPrimary)
                            
                            Divider()
                            
                            KYCRow(label: "Full Name", value: vm.loanWithDetails.borrower.fullName)
                            KYCRow(label: "Email", value: vm.loanWithDetails.borrower.email ?? "N/A")
                            KYCRow(label: "Phone", value: vm.loanWithDetails.borrower.phone ?? "N/A")
                            KYCRow(label: "PAN ID", value: vm.borrowerProfile?.panNumber ?? "N/A")
                            KYCRow(label: "Aadhaar Card", value: vm.borrowerProfile?.aadhaarNumber ?? "N/A")
                            KYCRow(label: "Employment Type", value: vm.borrowerProfile?.employmentType?.displayName ?? "N/A")
                            KYCRow(label: "Monthly Income", value: vm.borrowerProfile?.monthlyIncome != nil ? "INR \(String(format: "%.2f", vm.borrowerProfile!.monthlyIncome!))" : "N/A")
                        }
                    }
                    
                    // Loan Details Card
                    StaffCard {
                        VStack(alignment: .leading, spacing: StaffSpacing.md) {
                            Text("Loan Details & Terms")
                                .font(.staffTitle)
                                .foregroundColor(.staffTextPrimary)
                            
                            Divider()
                            
                            if let app = vm.application {
                                KYCRow(label: "Asked Amount (Requested)", value: "INR \(String(format: "%.2f", app.requestedAmount))")
                            } else {
                                KYCRow(label: "Asked Amount (Requested)", value: "INR --")
                            }
                            
                            KYCRow(label: "Approved & Disbursed Amount", value: "INR \(String(format: "%.2f", vm.loanWithDetails.loan.principalAmount))")
                            KYCRow(label: "Interest Rate", value: String(format: "%.2f%% (Interest Type: %@)", vm.loanWithDetails.loan.interestRate, vm.loanWithDetails.loan.interestType.rawValue.capitalized))
                            KYCRow(label: "Tenure", value: "\(vm.loanWithDetails.loan.tenureMonths) Months")
                            KYCRow(label: "Outstanding Principal", value: "INR \(String(format: "%.2f", vm.loanWithDetails.loan.outstandingPrincipal))")
                            KYCRow(label: "Maturity Date", value: vm.loanWithDetails.loan.maturityDate ?? "N/A")
                            KYCRow(label: "Repayment Mode", value: vm.loanWithDetails.loan.repaymentMode.rawValue.uppercased())
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Credit Bureau Score Gauge
                VStack(spacing: StaffSpacing.md) {
                    StaffCard {
                        VStack(spacing: StaffSpacing.md) {
                            Text("Credit Bureau Rating")
                                .font(.staffTitle)
                                .foregroundColor(.staffTextPrimary)
                            
                            Divider()
                            
                            CreditScoreGauge(score: vm.borrowerProfile?.creditScore ?? 300)
                        }
                    }
                }
                .frame(width: 320)
            }
        }
    }
    
    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.md) {
            Text("Loan Documents")
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
            
            if vm.documents.isEmpty {
                EmptyStateView(
                    icon: "doc.text.magnifyingglass",
                    title: "No Documents Found",
                    message: "No documents are associated with this loan application."
                )
            } else {
                ForEach(vm.documents) { doc in
                    HStack(spacing: StaffSpacing.md) {
                        Image(systemName: "doc.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                            .foregroundColor(.staffAccent)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(doc.documentType)
                                .font(.staffBody)
                                .fontWeight(.bold)
                                .foregroundColor(.staffTextPrimary)
                            
                            Text(doc.fileName)
                                .font(.staffCaption)
                                .foregroundColor(.staffTextSecondary)
                        }
                        
                        Spacer()
                        
                        // Action buttons
                        Button(action: {
                            Task {
                                if let url = await vm.getDocumentUrl(for: doc) {
                                    openURL(url)
                                }
                            }
                        }) {
                            Text("View")
                                .font(.staffCaption)
                                .fontWeight(.bold)
                                .foregroundColor(.staffAccent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.staffAccent.opacity(0.15))
                                .cornerRadius(StaffCorner.sm)
                        }
                        
                        if doc.isVerified {
                            Text("Verified")
                                .font(.staffCaption)
                                .fontWeight(.bold)
                                .foregroundColor(.staffGreen)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.staffGreen.opacity(0.15))
                                .cornerRadius(StaffCorner.sm)
                        }
                    }
                    .padding(StaffSpacing.md)
                    .background(Color.staffSurface)
                    .cornerRadius(StaffCorner.md)
                }
            }
        }
    }
    
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.md) {
            Text("Application Pipeline")
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
            
            StaffLoanPipelineView(stages: vm.pipelineStages)
        }
    }
    
    private var emiScheduleSection: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.md) {
            Text("EMI Schedule & Payments")
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
            
            if vm.emiSchedule.isEmpty {
                EmptyStateView(
                    icon: "calendar.badge.clock",
                    title: "No EMI Schedule",
                    message: "The EMI schedule has not been generated for this loan."
                )
            } else {
                ForEach(vm.emiSchedule.sorted(by: { $0.installmentNumber < $1.installmentNumber })) { emi in
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Installment #\(emi.installmentNumber)")
                                .font(.staffBody)
                                .fontWeight(.bold)
                                .foregroundColor(.staffTextPrimary)
                            Text("Due: \(emi.dueDate)")
                                .font(.staffCaption)
                                .foregroundColor(.staffTextSecondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("INR \(String(format: "%.2f", emi.totalEmi))")
                                .font(.staffBody)
                                .fontWeight(.bold)
                                .foregroundColor(.staffTextPrimary)
                            
                            StaffStatusBadge(status: emi.status.rawValue.capitalized)
                        }
                    }
                    .padding(StaffSpacing.md)
                    .background(Color.staffSurface)
                    .cornerRadius(StaffCorner.md)
                }
            }
        }
    }
    
    private var recoverySection: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.md) {
            Text("NPA Recovery Details")
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
            
            StaffCard {
                VStack(alignment: .leading, spacing: StaffSpacing.md) {
                    Text("Delinquency Overview")
                        .font(.headline)
                        .foregroundColor(.staffTextPrimary)
                    
                    Divider()
                    
                    KYCRow(label: "Overdue Days", value: "\(vm.loanWithDetails.loan.overdueDays)")
                    KYCRow(label: "Missed EMIs", value: "\(vm.emiSchedule.filter { $0.status == .overdue }.count)")
                    KYCRow(label: "Total Arrears", value: "INR \(String(format: "%.2f", vm.emiSchedule.filter { $0.status == .overdue }.reduce(0) { $0 + $1.totalEmi }))")
                }
            }
        }
    }
    
    private var actionButtonBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: StaffSpacing.md) {
                
                StaffButton(title: "Restructure Loan", style: .primary, icon: "arrow.triangle.2.circlepath") {
                    reason = ""
                    showRestructureSheet = true
                }
                
                StaffButton(title: "Write-off Loan", style: .destructive, icon: "xmark.seal.fill") {
                    reason = ""
                    showWriteOffSheet = true
                }
                
            }
            .padding(StaffSpacing.lg)
        }
        .background(Color.staffSurface)
    }
    
    // Helper to generate consistent action sheets
    private func actionSheet(title: String, actionColor: Color, actionLabel: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: StaffSpacing.lg) {
            Text(title)
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
            
            Text("Please provide detailed justification for this action. This will be recorded in the audit logs.")
                .font(.staffCaption)
                .foregroundColor(.staffTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            TextEditor(text: $reason)
                .frame(height: 120)
                .padding(8)
                .background(Color.staffSurface)
                .cornerRadius(StaffCorner.md)
                .foregroundColor(.staffTextPrimary)
            
            HStack {
                Button("Cancel") {
                    showRestructureSheet = false
                    showWriteOffSheet = false
                    showEscalateSheet = false
                }
                .foregroundColor(.staffTextSecondary)
                .disabled(isProcessing)
                
                Spacer()
                
                Button(actionLabel) {
                    action()
                }
                .foregroundColor(actionColor)
                .fontWeight(.bold)
                .disabled(reason.isEmpty || isProcessing)
                
                if isProcessing {
                    ProgressView().padding(.leading, 8)
                }
            }
        }
        .padding(30)
        .background(Color.staffBackground.ignoresSafeArea())
    }
    
    private func restructureActionSheet() -> some View {
        VStack(spacing: StaffSpacing.lg) {
            Text("Restructure Loan")
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
            
            Text("Please provide new terms for the loan restructure.")
                .font(.staffCaption)
                .foregroundColor(.staffTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: StaffSpacing.md) {
                HStack {
                    Text("Revised Interest Rate (%)")
                        .font(.staffBody)
                    Spacer()
                    TextField("Rate", value: $revisedRate, format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 100)
                        .keyboardType(.decimalPad)
                }
                
                HStack {
                    Text("Revised Tenure (Months)")
                        .font(.staffBody)
                    Spacer()
                    TextField("Tenure", value: $revisedTenure, format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 100)
                        .keyboardType(.numberPad)
                }
                
                HStack {
                    Text("Waived Penalty Amount (INR)")
                        .font(.staffBody)
                    Spacer()
                    TextField("Amount", value: $waivedPenalty, format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 100)
                        .keyboardType(.decimalPad)
                }
            }
            .padding(.horizontal)
            
            Text("Reason for restructure:")
                .font(.staffBody)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            TextEditor(text: $reason)
                .frame(height: 80)
                .padding(8)
                .background(Color.staffSurface)
                .cornerRadius(StaffCorner.md)
                .foregroundColor(.staffTextPrimary)
                .padding(.horizontal)
            
            HStack {
                Button("Cancel") {
                    showRestructureSheet = false
                }
                .foregroundColor(.staffTextSecondary)
                .disabled(isProcessing)
                
                Spacer()
                
                Button("Confirm Restructure") {
                    Task {
                        isProcessing = true
                        try? await NPAService.shared.restructureLoan(
                            loan: vm.loanWithDetails.loan,
                            revisedRate: revisedRate,
                            revisedTenure: revisedTenure,
                            waivedPenalty: waivedPenalty,
                            reason: reason
                        )
                        isProcessing = false
                        showRestructureSheet = false
                        onActionTriggered()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                .foregroundColor(.staffAmber)
                .fontWeight(.bold)
                .disabled(reason.isEmpty || isProcessing || revisedTenure <= 0 || revisedRate <= 0.0)
                
                if isProcessing {
                    ProgressView().padding(.leading, 8)
                }
            }
            .padding(.horizontal)
        }
        .padding(30)
        .background(Color.staffBackground.ignoresSafeArea())
    }
}

// MARK: - Local Inspector Detail Metric
private struct InspectorDetailMetric: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.staffCaption)
                .foregroundColor(.staffTextSecondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Text(value)
                .font(.staffBody)
                .fontWeight(.bold)
                .foregroundColor(.staffAccent)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }
}
