//
//  LoanDetailView.swift
//  LMS Staff
//
//  Detailed inspector view for an active loan account.
//

import SwiftUI

struct LoanDetailView: View {
    let loanWithDetails: LoanWithDetails
    
    @StateObject private var vm: LoanDetailViewModel
    @State private var activeTab: InspectorTab = .overview
    
    enum InspectorTab: String, CaseIterable {
        case overview = "Overview"
        case emi = "Repayments (EMI)"
        case payments = "Payments"
        case logs = "Audit Log"
    }
    
    init(loanWithDetails: LoanWithDetails) {
        self.loanWithDetails = loanWithDetails
        _vm = StateObject(wrappedValue: LoanDetailViewModel(loanWithDetails: loanWithDetails))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Info Bar
            HStack(spacing: StaffSpacing.lg) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(loanWithDetails.borrower.fullName)
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
                HStack(spacing: StaffSpacing.xl) {
                    DetailMetric(label: "Principal", value: "INR \(String(format: "%.2f", vm.loanWithDetails.loan.principalAmount))")
                    DetailMetric(label: "Outstanding", value: "INR \(String(format: "%.2f", vm.loanWithDetails.loan.outstandingPrincipal))")
                    DetailMetric(label: "Interest Rate", value: vm.loanWithDetails.loan.formattedRate)
                }
            }
            .padding(StaffSpacing.lg)
            .background(Color.staffSurface)
            
            // Tab Selector bar
            HStack(spacing: 0) {
                ForEach(InspectorTab.allCases, id: \.self) { tab in
                    Button(action: { activeTab = tab }) {
                        VStack(spacing: 8) {
                            Text(tab.rawValue)
                                .font(.staffBody)
                                .fontWeight(activeTab == tab ? .bold : .regular)
                                .foregroundColor(activeTab == tab ? .staffAccent : .staffTextSecondary)
                            
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
            if vm.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: StaffSpacing.xl) {
                        switch activeTab {
                        case .overview:
                            overviewSection
                        case .emi:
                            emiSection
                        case .payments:
                            paymentsSection
                        case .logs:
                            logsSection
                        }
                    }
                    .padding(StaffSpacing.lg)
                }
                .background(Color.staffBackground)
            }
        }
        .task {
            await vm.loadAllDetails()
        }
    }
    
    // MARK: - Subviews
    
    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.lg) {
            StaffCard {
                VStack(alignment: .leading, spacing: StaffSpacing.md) {
                    Text("Loan Metadata")
                        .font(.staffTitle)
                        .foregroundColor(.staffTextPrimary)
                    
                    Divider()
                    
                    KYCRow(label: "Disbursement Date", value: vm.loanWithDetails.loan.disbursementDate ?? "N/A")
                    KYCRow(label: "First EMI Date", value: vm.loanWithDetails.loan.firstEmiDate ?? "N/A")
                    KYCRow(label: "Maturity Date", value: vm.loanWithDetails.loan.maturityDate ?? "N/A")
                    KYCRow(label: "Tenure", value: "\(vm.loanWithDetails.loan.tenureMonths) Months")
                    KYCRow(label: "Processing Fee", value: "INR \(String(format: "%.2f", vm.loanWithDetails.loan.processingFee))")
                    KYCRow(label: "Repayment Mode", value: vm.loanWithDetails.loan.repaymentMode.displayName)
                }
            }
            
            StaffCard {
                VStack(alignment: .leading, spacing: StaffSpacing.md) {
                    Text("Financial Summary")
                        .font(.staffTitle)
                        .foregroundColor(.staffTextPrimary)
                    
                    Divider()
                    
                    KYCRow(label: "Total Payable", value: "INR \(String(format: "%.2f", vm.loanWithDetails.loan.totalPayable))")
                    KYCRow(label: "Outstanding Interest", value: "INR \(String(format: "%.2f", vm.loanWithDetails.loan.outstandingInterest))")
                    KYCRow(label: "Total Overdue", value: "INR \(String(format: "%.2f", vm.loanWithDetails.loan.totalOverdue))")
                    KYCRow(label: "Overdue Days", value: "\(vm.loanWithDetails.loan.overdueDays)")
                    if let rateBreakdown = vm.loanWithDetails.loan.rateBreakdown {
                        KYCRow(label: "Rate Breakdown", value: rateBreakdown)
                    }
                }
            }
        }
    }
    
    private var emiSection: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.md) {
            Text("EMI Schedule")
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
            
            if vm.emiSchedule.isEmpty {
                Text("No EMI schedule found.")
                    .font(.staffBody)
                    .foregroundColor(.staffTextSecondary)
            } else {
                ForEach(vm.emiSchedule) { emi in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Installment \(emi.installmentNumber)")
                                .font(.staffBody)
                                .fontWeight(.bold)
                            Text("Due: \(emi.dueDate)")
                                .font(.staffCaption)
                                .foregroundColor(.staffTextSecondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("INR \(String(format: "%.2f", emi.totalEmi))")
                                .font(.staffBody)
                                .fontWeight(.medium)
                            Text("P: \(String(format: "%.2f", emi.principalComponent)) | I: \(String(format: "%.2f", emi.interestComponent))")
                                .font(.staffCaption)
                                .foregroundColor(.staffTextSecondary)
                        }
                        
                        StaffStatusBadge(status: emi.status.rawValue.capitalized)
                    }
                    .padding(StaffSpacing.md)
                    .background(Color.staffSurface)
                    .cornerRadius(StaffCorner.md)
                }
            }
        }
    }
    
    private var paymentsSection: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.md) {
            Text("Transaction History")
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
            
            if vm.payments.isEmpty {
                Text("No payments found.")
                    .font(.staffBody)
                    .foregroundColor(.staffTextSecondary)
            } else {
                ForEach(vm.payments) { payment in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("INR \(String(format: "%.2f", payment.amount))")
                                .font(.staffBody)
                                .fontWeight(.bold)
                            if let ref = payment.transactionReference {
                                Text("Ref: \(ref)")
                                    .font(.staffCaption)
                                    .foregroundColor(.staffTextSecondary)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(payment.initiatedAt?.formatted() ?? "Unknown Date")
                                .font(.staffCaption)
                                .foregroundColor(.staffTextSecondary)
                            StaffStatusBadge(status: payment.status.rawValue.capitalized)
                        }
                    }
                    .padding(StaffSpacing.md)
                    .background(Color.staffSurface)
                    .cornerRadius(StaffCorner.md)
                }
            }
        }
    }
    
    private var logsSection: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.md) {
            Text("Audit Trail Logs")
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
            
            if vm.auditLogs.isEmpty {
                Text("No audit logs found for this loan.")
                    .font(.staffBody)
                    .foregroundColor(.staffTextSecondary)
            } else {
                ForEach(vm.auditLogs) { log in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(log.action)
                                .font(.staffBody)
                                .fontWeight(.bold)
                                .foregroundColor(.staffAccent)
                            Spacer()
                            Text(log.createdAt?.formatted() ?? "")
                                .font(.staffCaption)
                                .foregroundColor(.staffTextSecondary)
                        }
                        if let summary = log.changeSummary {
                            Text(summary)
                                .font(.staffBody)
                                .foregroundColor(.staffTextPrimary)
                                .padding(.top, 4)
                        }
                        Text("Actor Role: \(log.actorRole?.displayName ?? "Unknown")")
                            .font(.staffCaption)
                            .foregroundColor(.staffTextSecondary)
                            .padding(.top, 2)
                    }
                    .padding(StaffSpacing.md)
                    .background(Color.staffSurface)
                    .cornerRadius(StaffCorner.md)
                }
            }
        }
    }
}
