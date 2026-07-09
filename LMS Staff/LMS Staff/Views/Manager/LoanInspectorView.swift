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
                    ChatSupportConsole(appWithBorrower: appWithBorrower, forceInternalOnly: authViewModel.currentUser?.role == .manager)
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
            HStack(spacing: StaffSpacing.lg) {
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
                        if let verifiedAnnual = vm.borrowerProfile?.verifiedAnnualIncome {
                            KYCRow(label: "Verified Monthly", value: "INR \(String(format: "%.2f", verifiedAnnual / 12))")
                        } else {
                            KYCRow(label: "Declared Monthly", value: vm.borrowerProfile?.monthlyIncome != nil ? "INR \(String(format: "%.2f", vm.borrowerProfile!.monthlyIncome!))" : "N/A")
                        }
                        
                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Credit Bureau Score Gauge
                StaffCard {
                    VStack(spacing: StaffSpacing.md) {
                        Text("Credit Bureau Rating")
                            .font(.staffTitle)
                            .foregroundColor(.staffTextPrimary)
                        
                        Divider()
                        
                        Spacer(minLength: 0)
                        
                        CreditScoreGauge(score: vm.borrowerProfile?.creditScore ?? 300)
                        
                        Spacer(minLength: 0)
                    }
                }
                .frame(width: 320)
                .frame(maxHeight: .infinity)
            }
            .fixedSize(horizontal: false, vertical: true)
            
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
                    
                    if authViewModel.currentUser?.role != .officer {
                        KYCRow(label: "Assigned Loan Officer", value: vm.assignedOfficer?.fullName ?? "Unassigned")
                    }
                }
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
                VStack(spacing: 0) {
                    // Header Row
                    HStack {
                        Text("No.")
                            .frame(width: 40, alignment: .leading)
                        Text("Due Date")
                            .frame(width: 120, alignment: .leading)
                        Text("EMI Amt")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Principal")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Interest")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Status")
                            .frame(width: 100, alignment: .leading)
                    }
                    .font(.staffCaption)
                    .foregroundColor(.staffTextSecondary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, StaffSpacing.lg)
                    
                    Divider()
                    
                    let sortedSchedule = vm.emiSchedule.sorted(by: { $0.installmentNumber < $1.installmentNumber })
                    let firstUnpaidIndex = sortedSchedule.firstIndex(where: { $0.status != .paid }) ?? sortedSchedule.count
                    
                    ForEach(Array(sortedSchedule.enumerated()), id: \.element.id) { index, emi in
                        let statusInfo = getEmiStatusAndStyle(index: index, firstUnpaidIndex: firstUnpaidIndex, emi: emi)
                        
                        HStack {
                            Text("\(emi.installmentNumber)")
                                .frame(width: 40, alignment: .leading)
                                .fontWeight(index == firstUnpaidIndex ? .bold : .regular)
                            
                            Text(emi.dueDate)
                                .frame(width: 120, alignment: .leading)
                                .fontWeight(index == firstUnpaidIndex ? .bold : .regular)
                            
                            Text(String(format: "%.2f", emi.totalEmi))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fontWeight(index == firstUnpaidIndex ? .bold : .regular)
                            
                            Text(String(format: "%.2f", emi.principalComponent))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fontWeight(index == firstUnpaidIndex ? .bold : .regular)
                            
                            Text(String(format: "%.2f", emi.interestComponent))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fontWeight(index == firstUnpaidIndex ? .bold : .regular)
                            
                            Text(statusInfo.text)
                                .frame(width: 100, alignment: .leading)
                                .fontWeight(index == firstUnpaidIndex ? .bold : .regular)
                                .foregroundColor(statusInfo.color)
                        }
                        .font(.staffCaption)
                        .foregroundColor(.staffTextPrimary)
                        .opacity(statusInfo.opacity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, StaffSpacing.lg)
                        
                        Divider()
                    }
                }
                .background(Color.staffSurface)
                .cornerRadius(StaffCorner.md)
            }
        }
    }
    
    private struct EmiStatusStyle {
        let text: String
        let color: Color
        let opacity: Double
    }
    
    private func getEmiStatusAndStyle(index: Int, firstUnpaidIndex: Int, emi: EMIScheduleItem) -> EmiStatusStyle {
        if index < firstUnpaidIndex {
            return EmiStatusStyle(text: "Paid", color: .staffGreen, opacity: 1.0)
        } else if index == firstUnpaidIndex {
            return EmiStatusStyle(text: "Upcoming", color: .orange, opacity: 1.0)
        } else {
            return EmiStatusStyle(text: "Scheduled", color: .staffTextSecondary, opacity: 0.6)
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
