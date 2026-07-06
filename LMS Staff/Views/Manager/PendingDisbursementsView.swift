//
//  PendingDisbursementsView.swift
//  LMS Staff
//
//  View displaying the approved-but-undisbursed queue and IFSC verification check.
//

import SwiftUI

struct PendingDisbursementsView: View {
    @StateObject private var vm = DisbursementViewModel()
    @State private var selectedApp: ApplicationWithBorrower?
    
    // Bank check form fields
    @State private var inputAccountNo: String = ""
    @State private var inputIfscCode: String = ""
    
    // Amortization table review sheet
    @State private var showAmortizationReview: Bool = false
    @State private var reviewEmiItems: [EMIScheduleItem] = []
    
    var body: some View {
        HStack(spacing: 0) {
            // Left list: Approved applications
            VStack(alignment: .leading, spacing: 0) {
                Text("Pending Disbursements")
                    .font(.staffTitle)
                    .foregroundColor(.staffTextPrimary)
                    .padding(.horizontal, StaffSpacing.lg)
                    .padding(.top, StaffSpacing.lg)
                
                Divider()
                    .background(Color.staffBorder)
                    .padding(.vertical, StaffSpacing.md)
                
                if vm.isLoading {
                    Spacer()
                    ProgressView()
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else if let error = vm.errorMessage {
                    Spacer()
                    EmptyStateView(
                        icon: "exclamationmark.triangle.fill",
                        title: "Error Loading Data",
                        message: error
                    )
                    Spacer()
                } else if vm.pendingDisbursements.isEmpty {
                    Spacer()
                    EmptyStateView(
                        icon: "indianrupeesign.circle",
                        title: "No Disbursements",
                        message: "There are no approved loans awaiting final bank disbursement."
                    )
                    Spacer()
                } else {
                    List(vm.pendingDisbursements, selection: $selectedApp) { app in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(app.borrower.fullName)
                                    .font(.staffBody)
                                    .fontWeight(.bold)
                                    .foregroundColor(.staffTextPrimary)
                                Spacer()
                                Text("INR \(String(format: "%.0f", app.application.requestedAmount))")
                                    .font(.staffCaption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.staffAccent)
                            }
                            
                            HStack {
                                Text(app.application.applicationNumber ?? "APP-NEW")
                                    .font(.staffCaption)
                                    .foregroundColor(.staffTextSecondary)
                                Spacer()
                                Text("Awaiting Bank Details")
                                    .font(.system(size: 10))
                                    .foregroundColor(.staffAmber)
                            }
                        }
                        .padding(.vertical, 4)
                        .tag(app)
                        .listRowBackground(Color.staffSurface)
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden)
                    .background(Color.staffBackground)
                }
            }
            .frame(width: 360)
            .background(Color.staffBackground)
            
            Divider()
                .background(Color.staffBorder)
            
            // Right: Bank details check & proceed console
            if let app = selectedApp {
                disbursementInspectorSection(app)
            } else {
                VStack(spacing: StaffSpacing.md) {
                    Image(systemName: "indianrupeesign.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.staffTextSecondary.opacity(0.3))
                    Text("Select Approved Application to Verify Bank Details")
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
                await vm.loadPendingDisbursements()
            }
        }
        .sheet(isPresented: $showAmortizationReview) {
            amortizationReviewSheet
                .presentationBackground(Color.staffBackground)
        }
    }
    
    // MARK: - Subviews
    
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
                                error: vm.ifscError
                            )
                            
                            StaffButton(
                                title: "Verify IFSC Branch Details",
                                style: .outline,
                                icon: "checkmark.shield",
                                isLoading: vm.isVerifyingIFSC
                            ) {
                                Task {
                                    await vm.verifyIFSC(inputIfscCode)
                                }
                            }
                            
                            // Bank Details Result Display
                            if let bank = vm.verifiedBankDetails {
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
                    showAmortizationReview = true
                }
                .frame(width: 320)
                .disabled(inputAccountNo.isEmpty || vm.verifiedBankDetails == nil)
            }
            .padding(StaffSpacing.lg)
            .background(Color.staffSurface)
        }
        .onChange(of: item) { _ in
            // Clear verification state on change selection
            inputAccountNo = ""
            inputIfscCode = ""
            vm.verifiedBankDetails = nil
            vm.ifscError = nil
        }
    }
    
    private var amortizationReviewSheet: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.lg) {
            HStack {
                Text("Confirm Disbursal & Repayment Schedule")
                    .font(.staffTitle)
                    .foregroundColor(.staffTextPrimary)
                Spacer()
                Button("Cancel") { showAmortizationReview = false }
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
                    
                    ForEach(reviewEmiItems, id: \.installmentNumber) { item in
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
                if let error = vm.errorMessage {
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
                    if let app = selectedApp?.application, let product = selectedApp?.product {
                        Task {
                            let isSuccess = await vm.processDisbursement(
                                application: app,
                                bankAccount: inputAccountNo,
                                ifscCode: inputIfscCode,
                                interestRate: vm.approvedRates[app.id] ?? product.minInterestRate,
                                interestType: product.supportedInterestTypes.first ?? .reducing,
                                processingFeePct: product.processingFeePct
                            )
                            if isSuccess {
                                showAmortizationReview = false
                                selectedApp = nil
                            } else {
                                print("Disbursal failed: \(vm.errorMessage ?? "Unknown error")")
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
        let rate = vm.approvedRates[item.application.id] ?? item.product.minInterestRate
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
        
        self.reviewEmiItems = list
    }
}
