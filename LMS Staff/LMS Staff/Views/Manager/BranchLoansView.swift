//
//  BranchLoansView.swift
//  LMS Staff
//
//  Unified view for managers to browse all branch loans categorised by status:
//  Active, Pending Disbursement, NPA, Restructured, and Closed.
//

import SwiftUI

enum BranchLoanSegment: String, CaseIterable {
    case active = "Active"
    case pendingDisbursement = "Pending Disbursement"
    case npa = "NPA"
    case restructured = "Restructured"
    case closed = "Closed"
}

struct BranchLoansView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var vm = PortfolioViewModel()
    @StateObject private var disbursementVM = DisbursementViewModel()
    
    @State private var selectedSegment: BranchLoanSegment = .active
    @State private var selectedLoan: LoanWithDetails?
    @State private var selectedDisbursementApp: ApplicationWithBorrower?
    @State private var searchText: String = ""
    
    // For the pending disbursement detail section (reuses PendingDisbursementsView logic)
    @State private var inputAccountNo: String = ""
    @State private var inputIfscCode: String = ""
    
    struct DisbursementReviewPayload: Identifiable {
        let id = UUID()
        let items: [EMIScheduleItem]
    }
    @State private var reviewPayload: DisbursementReviewPayload?
    
    /// All loans filtered by selected segment and search text
    var filteredItems: [LoanWithDetails] {
        var result = vm.loans
        
        // Filter by segment (loan status)
        switch selectedSegment {
        case .active:
            result = result.filter { $0.loan.status == .active }
        case .npa:
            result = result.filter { $0.loan.status == .npa }
        case .restructured:
            result = result.filter { $0.loan.status == .restructured }
        case .closed:
            result = result.filter { $0.loan.status == .closed || $0.loan.status == .writtenOff }
        case .pendingDisbursement:
            return [] // handled separately via disbursementVM
        }
        
        // Search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.borrower.fullName.lowercased().contains(query) ||
                ($0.loan.loanNumber ?? "").lowercased().contains(query) ||
                $0.product.name.lowercased().contains(query)
            }
        }
        
        return result
    }
    
    var filteredDisbursements: [ApplicationWithBorrower] {
        if searchText.isEmpty {
            return disbursementVM.pendingDisbursements
        }
        let query = searchText.lowercased()
        return disbursementVM.pendingDisbursements.filter {
            $0.borrower.fullName.lowercased().contains(query) ||
            ($0.application.applicationNumber ?? "").lowercased().contains(query)
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // MARK: - Left Column: Loan List
            VStack(alignment: .leading, spacing: 0) {
                Text("Active Loans")
                    .font(.staffTitle)
                    .foregroundColor(.staffTextPrimary)
                    .padding(.horizontal, StaffSpacing.lg)
                    .padding(.top, StaffSpacing.lg)
                
                // Mini stat summary
                HStack(spacing: StaffSpacing.md) {
                    MiniStatCard(title: "Active", value: "\(countFor(.active))", icon: "checkmark.circle", color: .staffGreen)
                    MiniStatCard(title: "Pending", value: "\(countFor(.pendingDisbursement))", icon: "hourglass", color: .staffAmber)
                    MiniStatCard(title: "NPA", value: "\(countFor(.npa))", icon: "exclamationmark.triangle", color: .staffRed)
                }
                .padding(StaffSpacing.lg)
                
                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: StaffSpacing.sm) {
                        ForEach(BranchLoanSegment.allCases, id: \.self) { seg in
                            OfficerFilterChip(
                                title: seg.rawValue,
                                isSelected: selectedSegment == seg
                            ) {
                                selectedSegment = seg
                                selectedLoan = nil
                                selectedDisbursementApp = nil
                            }
                        }
                    }
                    .padding(.horizontal, StaffSpacing.lg)
                }
                .padding(.bottom, StaffSpacing.md)
                
                // Search field
                TextField("Search loan or borrower...", text: $searchText)
                    .padding(12)
                    .background(Color.staffSurface)
                    .cornerRadius(StaffCorner.md)
                    .foregroundColor(.staffTextPrimary)
                    .padding(.horizontal, StaffSpacing.lg)
                    .padding(.bottom, StaffSpacing.md)
                
                Divider()
                    .background(Color.staffBorder)
                
                // List content
                if vm.isLoading || disbursementVM.isLoading {
                    Spacer()
                    ProgressView("Loading loans...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .staffAccent))
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else if selectedSegment == .pendingDisbursement {
                    // Show pending disbursement applications
                    if filteredDisbursements.isEmpty {
                        Spacer()
                        EmptyStateView(
                            icon: "indianrupeesign.circle",
                            title: "No Pending Disbursements",
                            message: "There are no approved loans awaiting disbursement."
                        )
                        Spacer()
                    } else {
                        List(filteredDisbursements, id: \.application.id) { app in
                            Button(action: {
                                selectedDisbursementApp = app
                                selectedLoan = nil
                            }) {
                                VStack(alignment: .leading, spacing: StaffSpacing.xs) {
                                    HStack {
                                        Text(app.borrower.fullName)
                                            .font(.staffBody)
                                            .fontWeight(.bold)
                                            .foregroundColor(.staffTextPrimary)
                                        Spacer()
                                        StaffStatusBadge(status: "Pending Disbursal")
                                    }
                                    
                                    HStack {
                                        Text(app.application.applicationNumber ?? "APP-NEW")
                                            .font(.staffCaption)
                                            .foregroundColor(.staffTextSecondary)
                                        Spacer()
                                        Text("INR \(String(format: "%.2f", app.application.requestedAmount))")
                                            .font(.staffCaption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.staffAccent)
                                    }
                                }
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .listRowBackground(
                                selectedDisbursementApp?.application.id == app.application.id
                                ? Color.staffAccent.opacity(0.15)
                                : Color.staffSurface
                            )
                        }
                        .listStyle(PlainListStyle())
                        .scrollContentBackground(.hidden)
                        .background(Color.staffBackground)
                    }
                } else {
                    // Show loans
                    if filteredItems.isEmpty {
                        Spacer()
                        EmptyStateView(
                            icon: "briefcase",
                            title: "No Loans Found",
                            message: "No loans match the current filter."
                        )
                        Spacer()
                    } else {
                        List(filteredItems, id: \.id) { item in
                            Button(action: {
                                selectedLoan = item
                                selectedDisbursementApp = nil
                            }) {
                                VStack(alignment: .leading, spacing: StaffSpacing.xs) {
                                    HStack {
                                        Text(item.borrower.fullName)
                                            .font(.staffBody)
                                            .fontWeight(.bold)
                                            .foregroundColor(.staffTextPrimary)
                                        Spacer()
                                        StaffStatusBadge(status: item.loan.status.displayName)
                                    }
                                    
                                    HStack {
                                        Text(item.loan.loanNumber ?? "LMS-XXXXXX")
                                            .font(.staffCaption)
                                            .foregroundColor(.staffTextSecondary)
                                        Spacer()
                                        Text("INR \(String(format: "%.2f", item.loan.outstandingPrincipal))")
                                            .font(.staffCaption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.staffAccent)
                                    }
                                }
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .listRowBackground(
                                selectedLoan?.id == item.id
                                ? Color.staffAccent.opacity(0.15)
                                : Color.staffSurface
                            )
                        }
                        .listStyle(PlainListStyle())
                        .scrollContentBackground(.hidden)
                        .background(Color.staffBackground)
                    }
                }
            }
            .frame(width: 360)
            .background(Color.staffBackground)
            
            Divider()
                .background(Color.staffBorder)
            
            // MARK: - Right Column: Detail Inspector
            if let loan = selectedLoan {
                LoanInspectorView(
                    loanWithDetails: loan,
                    onActionTriggered: {
                        Task {
                            await vm.loadPortfolio()
                            if let selected = selectedLoan {
                                selectedLoan = vm.loans.first(where: { $0.id == selected.id })
                            }
                        }
                    }
                )
                .id(loan.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let app = selectedDisbursementApp {
                disbursementInspectorSection(app)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: StaffSpacing.md) {
                    Image(systemName: "briefcase.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.staffTextSecondary.opacity(0.3))
                    Text("Select a Loan to Inspect")
                        .font(.staffTitle)
                        .foregroundColor(.staffTextSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.staffSurface.opacity(0.1))
            }
        }
        .background(Color.staffBackground)
        .onAppear {
            Task {
                await vm.loadPortfolio()
                await disbursementVM.loadPendingDisbursements()
            }
        }
        .sheet(item: $reviewPayload) { payload in
            amortizationReviewSheet(payload: payload)
                .presentationBackground(Color.staffBackground)
        }
    }
    
    // MARK: - Helpers
    
    private func countFor(_ segment: BranchLoanSegment) -> Int {
        switch segment {
        case .active: return vm.loans.filter { $0.loan.status == .active }.count
        case .pendingDisbursement: return disbursementVM.pendingDisbursements.count
        case .npa: return vm.loans.filter { $0.loan.status == .npa }.count
        case .restructured: return vm.loans.filter { $0.loan.status == .restructured }.count
        case .closed: return vm.loans.filter { $0.loan.status == .closed || $0.loan.status == .writtenOff }.count
        }
    }
    
    // MARK: - Disbursement Inspector (reused from PendingDisbursementsView)
    
    @ViewBuilder
    private func disbursementInspectorSection(_ item: ApplicationWithBorrower) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.borrower.fullName)
                        .font(.staffTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.staffTextPrimary)
                    Text("App ID: \(item.application.id.uuidString.prefix(8)) | Product: \(item.product.name)")
                        .font(.staffCaption)
                        .foregroundColor(.staffTextSecondary)
                }
                Spacer()
            }
            .padding(StaffSpacing.lg)
            .background(Color.staffSurface)
            
            ScrollView {
                VStack(alignment: .leading, spacing: StaffSpacing.lg) {
                    // Sanction terms summary card
                    StaffCard {
                        VStack(alignment: .leading, spacing: StaffSpacing.md) {
                            Text("Approved Sanction Details")
                                .font(.staffTitle)
                                .foregroundColor(.staffTextPrimary)
                            
                            Divider()
                            
                            KYCRow(label: "Approved Principal Amount", value: "INR \(String(format: "%.2f", item.application.requestedAmount))")
                            KYCRow(label: "Approved Tenure Months", value: "\(item.application.requestedTenureMonths) Months")
                            KYCRow(label: "Processing Fee Pct", value: "\(item.product.processingFeePct)%")
                        }
                    }
                    
                    // Bank info form
                    StaffCard {
                        VStack(alignment: .leading, spacing: StaffSpacing.md) {
                            Text("ECS Bank Mandate Verification")
                                .font(.staffTitle)
                                .foregroundColor(.staffTextPrimary)
                            
                            Divider()
                            
                            StaffFormField(
                                label: "Borrower Bank Account Number",
                                placeholder: "Enter account number",
                                text: $inputAccountNo,
                                error: nil
                            )
                            
                            StaffFormField(
                                label: "Branch IFSC Code",
                                placeholder: "Enter IFSC e.g. SBIN0001234",
                                text: $inputIfscCode,
                                error: disbursementVM.ifscError
                            )
                            
                            StaffButton(
                                title: "Verify IFSC Branch Details",
                                style: .outline,
                                icon: "checkmark.shield",
                                isLoading: disbursementVM.isVerifyingIFSC
                            ) {
                                Task {
                                    await disbursementVM.verifyIFSC(inputIfscCode)
                                }
                            }
                            
                            // Bank Details Result Display
                            if let bank = disbursementVM.verifiedBankDetails {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.staffGreen)
                                        Text("Bank Verified Successfully")
                                            .font(.staffBody)
                                            .fontWeight(.bold)
                                            .foregroundColor(.staffGreen)
                                    }
                                    
                                    Text("Bank Name: \(bank.bank)")
                                        .font(.staffCaption)
                                        .foregroundColor(.staffTextPrimary)
                                    Text("Branch Location: \(bank.branch) (\(bank.city), \(bank.state))")
                                        .font(.staffCaption)
                                        .foregroundColor(.staffTextSecondary)
                                }
                                .padding()
                                .background(Color.staffGreen.opacity(0.1))
                                .cornerRadius(StaffCorner.md)
                            }
                        }
                    }
                }
                .padding(StaffSpacing.lg)
            }
            
            Divider()
                .background(Color.staffBorder)
            
            // Bottom disbursement button
            HStack {
                Spacer()
                
                StaffButton(
                    title: "Review Schedule & Disburse",
                    style: .primary,
                    icon: "indianrupeesign.circle.fill"
                ) {
                    calculateReviewSchedule(item)
                }
                .frame(width: 320)
                .disabled(inputAccountNo.isEmpty || disbursementVM.verifiedBankDetails == nil)
            }
            .padding(StaffSpacing.lg)
            .background(Color.staffSurface)
        }
        .onChange(of: item) { _ in
            inputAccountNo = ""
            inputIfscCode = ""
            disbursementVM.verifiedBankDetails = nil
            disbursementVM.ifscError = nil
        }
    }
    
    // MARK: - Amortization Review Sheet
    
    private func amortizationReviewSheet(payload: DisbursementReviewPayload) -> some View {
        VStack(alignment: .leading, spacing: StaffSpacing.lg) {
            HStack {
                Text("Confirm Disbursal & Repayment Schedule")
                    .font(.staffTitle)
                    .foregroundColor(.staffTextPrimary)
                Spacer()
                Button("Cancel") { reviewPayload = nil }
                    .foregroundColor(.staffTextSecondary)
            }
            
            Text("Review the calculated repayment schedule amortization before initiating disbursal. This cannot be updated once created.")
                .font(.staffCaption)
                .foregroundColor(.staffTextSecondary)
            
            ScrollView {
                VStack(spacing: 0) {
                    // Header row
                    HStack {
                        Text("No.")
                            .frame(width: 40, alignment: .leading)
                        Text("Principal")
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        Text("Interest")
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        Text("EMI Amount")
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        Text("Closing Bal")
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .font(.staffCaption)
                    .foregroundColor(.staffTextSecondary)
                    .padding(.vertical, 8)
                    
                    Divider()
                    
                    ForEach(payload.items, id: \.installmentNumber) { item in
                        HStack {
                            Text("\(item.installmentNumber)")
                                .frame(width: 40, alignment: .leading)
                            Text(String(format: "%.2f", item.principalComponent))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            Text(String(format: "%.2f", item.interestComponent))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            Text(String(format: "%.2f", item.totalEmi))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            Text(String(format: "%.2f", item.closingBalance))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .font(.staffCaption)
                        .foregroundColor(.staffTextPrimary)
                        .padding(.vertical, 8)
                        
                        Divider()
                    }
                }
            }
            
            HStack {
                if let error = disbursementVM.errorMessage {
                    Text(error)
                        .font(.staffCaption)
                        .foregroundColor(.staffRed)
                }
                
                Spacer()
                
                StaffButton(
                    title: "Confirm Disbursal Transact",
                    style: .success,
                    icon: "checkmark.seal.fill"
                ) {
                    if let app = selectedDisbursementApp?.application, let product = selectedDisbursementApp?.product {
                        Task {
                            let isSuccess = await disbursementVM.processDisbursement(
                                application: app,
                                bankAccount: inputAccountNo,
                                ifscCode: inputIfscCode,
                                interestRate: disbursementVM.approvedRates[app.id] ?? product.minInterestRate,
                                interestType: product.supportedInterestTypes.first ?? .reducing,
                                processingFeePct: product.processingFeePct
                            )
                            if isSuccess {
                                reviewPayload = nil
                                selectedDisbursementApp = nil
                                // Reload loans to reflect new disbursement
                                await vm.loadPortfolio()
                                await disbursementVM.loadPendingDisbursements()
                            }
                        }
                    }
                }
                .frame(width: 300)
            }
            .padding(.top, StaffSpacing.md)
        }
        .padding(30)
        .background(Color.staffBackground.ignoresSafeArea())
    }
    
    // MARK: - Local Calculations for review schedule
    
    private func calculateReviewSchedule(_ item: ApplicationWithBorrower) {
        let principal = item.application.requestedAmount
        let tenure = item.application.requestedTenureMonths
        let rate = disbursementVM.approvedRates[item.application.id] ?? item.product.minInterestRate
        let type = item.product.supportedInterestTypes.first ?? .reducing
        
        let monthlyRate = (rate / 12.0) / 100.0
        var emiAmount: Double = 0.0
        
        if type == .fixed {
            let totalInterest = principal * (rate / 100.0) * (Double(tenure) / 12.0)
            emiAmount = (principal + totalInterest) / Double(tenure)
        } else {
            let x = pow(1.0 + monthlyRate, Double(tenure))
            emiAmount = principal * (monthlyRate * x) / (x - 1.0)
        }
        
        var list: [EMIScheduleItem] = []
        var balance = principal
        
        for i in 1...tenure {
            var interestComp = 0.0
            var principalComp = 0.0
            
            if type == .fixed {
                interestComp = (principal * (rate / 100.0) * (Double(tenure) / 12.0)) / Double(tenure)
                principalComp = emiAmount - interestComp
            } else {
                interestComp = balance * monthlyRate
                principalComp = emiAmount - interestComp
            }
            
            let openBal = balance
            balance -= principalComp
            if balance < 0 || i == tenure {
                balance = 0.0
            }
            
            list.append(EMIScheduleItem(
                id: UUID(),
                loanId: UUID(),
                installmentNumber: i,
                dueDate: "",
                openingBalance: openBal,
                principalComponent: principalComp,
                interestComponent: interestComp,
                totalEmi: emiAmount,
                penaltyAmount: 0,
                penaltyDays: 0,
                closingBalance: balance,
                status: .upcoming,
                paidDate: nil,
                createdAt: nil,
                updatedAt: nil
            ))
        }
        
        self.reviewPayload = DisbursementReviewPayload(items: list)
    }
}
