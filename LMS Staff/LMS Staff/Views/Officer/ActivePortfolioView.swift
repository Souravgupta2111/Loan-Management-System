//
//  ActivePortfolioView.swift
//  LMS Staff
//
//  Active Portfolio list for Loan Officers to track repayments and flag NPA overdue loans.
//

import SwiftUI

struct ActivePortfolioView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var vm = PortfolioViewModel()
    @State private var selectedLoan: LoanWithDetails?
    
    // Flag Overdue Sheet state
    @State private var showFlagSheet: Bool = false
    @State private var flagReason: String = ""
    
    // Amortization sheet state
    @State private var showAmortizationSheet: Bool = false
    @State private var amortizationSchedule: [EMIScheduleItem] = []
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Column: Loan Portfolio List
            VStack(alignment: .leading, spacing: 0) {
                Text("Active Portfolios")
                    .font(.staffTitle)
                    .foregroundColor(.staffTextPrimary)
                    .padding(.horizontal, StaffSpacing.lg)
                    .padding(.top, StaffSpacing.lg)
                
                TextField("Search loan number or borrower...", text: $vm.searchText)
                    .padding(12)
                    .background(Color.staffSurface)
                    .cornerRadius(StaffCorner.md)
                    .foregroundColor(.staffTextPrimary)
                    .padding(StaffSpacing.lg)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: StaffSpacing.sm) {
                        OfficerFilterChip(title: "All", isSelected: vm.selectedStatusFilter == "All") { vm.selectedStatusFilter = "All" }
                        OfficerFilterChip(title: "Active", isSelected: vm.selectedStatusFilter == "Active") { vm.selectedStatusFilter = "Active" }
                        OfficerFilterChip(title: "Restructured", isSelected: vm.selectedStatusFilter == "Restructured") { vm.selectedStatusFilter = "Restructured" }
                        OfficerFilterChip(title: "NPA", isSelected: vm.selectedStatusFilter == "NPA") { vm.selectedStatusFilter = "NPA" }
                    }
                    .padding(.horizontal, StaffSpacing.lg)
                }
                .padding(.bottom, StaffSpacing.md)
                
                Divider()
                    .background(Color.staffBorder)
                
                if vm.isLoading {
                    Spacer()
                    ProgressView("Loading active loans...")
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else if vm.filteredLoans.isEmpty {
                    Spacer()
                    EmptyStateView(icon: "briefcase", title: "No Portfolios", message: "No active loans match the selection filter.")
                    Spacer()
                } else {
                    List(vm.filteredLoans, selection: $selectedLoan) { item in
                        VStack(alignment: .leading, spacing: StaffSpacing.xs) {
                            HStack {
                                Text(item.loan.loanNumber ?? "LMS-XXXXXX")
                                    .font(.staffBody)
                                    .fontWeight(.bold)
                                    .foregroundColor(.staffTextPrimary)
                                Spacer()
                                StaffStatusBadge(status: item.loan.status.displayName)
                            }
                            
                            HStack {
                                Text(item.borrower.fullName)
                                    .font(.staffCaption)
                                    .foregroundColor(.staffTextSecondary)
                                Spacer()
                                Text("Bal: INR \(String(format: "%.2f", item.loan.outstandingPrincipal))")
                                    .font(.staffCaption)
                                    .foregroundColor(.staffAccent)
                            }
                        }
                        .padding(.vertical, 4)
                        .tag(item)
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
            
            // Right Column: Active Loan details & actions
            if let loanWithDetails = selectedLoan {
                loanInspectorSection(loanWithDetails)
            } else {
                VStack(spacing: StaffSpacing.md) {
                    Image(systemName: "briefcase.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.staffTextSecondary.opacity(0.3))
                    Text("Select a Loan to Inspect Payments")
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
                if let staff = authViewModel.currentStaff {
                    await vm.loadPortfolio(forOfficerId: staff.userId)
                }
            }
        }
        .sheet(isPresented: $showFlagSheet) {
            flagNpaSheet
        }
        .sheet(isPresented: $showAmortizationSheet) {
            amortizationScheduleSheet
        }
    }
    
    // MARK: - Inspector Helper Views
    
    @ViewBuilder
    private func loanInspectorSection(_ item: LoanWithDetails) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header panel
            HStack(spacing: StaffSpacing.lg) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.loan.loanNumber ?? "LMS-XXXX")
                            .font(.staffTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.staffTextPrimary)
                        
                        StaffStatusBadge(status: item.loan.status.displayName)
                    }
                    
                    Text("Borrower: \(item.borrower.fullName) | Product: \(item.product.name)")
                        .font(.staffCaption)
                        .foregroundColor(.staffTextSecondary)
                }
                
                Spacer()
                
                if item.loan.status != .npa {
                    StaffButton(title: "Flag NPA Delinquency", style: .destructive, icon: "exclamationmark.triangle") {
                        showFlagSheet = true
                    }
                    .frame(width: 220)
                }
            }
            .padding(StaffSpacing.lg)
            .background(Color.staffSurface)
            
            // Detailed info tiles
            ScrollView {
                VStack(spacing: StaffSpacing.lg) {
                    HStack(spacing: StaffSpacing.lg) {
                        StaffCard {
                            VStack(alignment: .leading, spacing: StaffSpacing.md) {
                                Text("Outstanding Summary")
                                    .font(.staffTitle)
                                    .foregroundColor(.staffTextPrimary)
                                
                                Divider()
                                
                                InfoRow(label: "Principal Disbursed", value: "INR \(String(format: "%.2f", item.loan.principalAmount))")
                                InfoRow(label: "Outstanding Principal", value: "INR \(String(format: "%.2f", item.loan.outstandingPrincipal))")
                                InfoRow(label: "Outstanding Interest", value: "INR \(String(format: "%.2f", item.loan.outstandingInterest))")
                                InfoRow(label: "Interest Rate Config", value: "\(String(format: "%.2f", item.loan.interestRate))% (\(item.loan.interestType.displayName))")
                            }
                        }
                        
                        StaffCard {
                            VStack(alignment: .leading, spacing: StaffSpacing.md) {
                                Text("Repayment Tracking")
                                    .font(.staffTitle)
                                    .foregroundColor(.staffTextPrimary)
                                
                                Divider()
                                
                                InfoRow(label: "Overdue Days", value: "\(item.loan.overdueDays) Days", isUrgent: item.loan.overdueDays > 0)
                                InfoRow(label: "Total Overdue Amount", value: "INR \(String(format: "%.2f", item.loan.totalOverdue))", isUrgent: item.loan.totalOverdue > 0)
                                InfoRow(label: "Disbursement Reference", value: item.loan.disbursementReference ?? "N/A")
                                InfoRow(label: "ECS Repayment Mode", value: item.loan.repaymentMode.displayName)
                            }
                        }
                    }
                    .padding(.horizontal, StaffSpacing.lg)
                    .padding(.top, StaffSpacing.lg)
                    
                    // Amortization trigger button
                    Button(action: {
                        Task {
                            if let fetched = try? await LoanPortfolioService.shared.fetchEMISchedule(forLoanId: item.loan.id) {
                                self.amortizationSchedule = fetched
                                self.showAmortizationSheet = true
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "tablecells.fill")
                            Text("View Full Amortization Schedule")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .font(.staffBody)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(StaffSpacing.lg)
                        .background(Color.staffAccent)
                        .cornerRadius(StaffCorner.md)
                    }
                    .padding(.horizontal, StaffSpacing.lg)
                }
            }
        }
    }
    
    // MARK: - Sheets
    
    private var flagNpaSheet: some View {
        VStack(spacing: StaffSpacing.lg) {
            Text("Flag Loan as NPA")
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
            
            Text("This will mark the loan account as Non-Performing Asset and trigger recovery monitoring alerts.")
                .font(.staffCaption)
                .foregroundColor(.staffTextSecondary)
            
            TextEditor(text: $flagReason)
                .frame(height: 120)
                .padding(8)
                .background(Color.staffSurface)
                .cornerRadius(StaffCorner.md)
                .foregroundColor(.staffTextPrimary)
            
            HStack {
                Button("Cancel") { showFlagSheet = false }
                    .foregroundColor(.staffTextSecondary)
                Spacer()
                Button("Flag NPA") {
                    if let loan = selectedLoan?.loan {
                        Task {
                            if await vm.flagLoanAsOverdue(loanId: loan.id, reason: flagReason, officerId: authViewModel.currentStaff?.userId) {
                                showFlagSheet = false
                                flagReason = ""
                            }
                        }
                    }
                }
                .foregroundColor(.staffRed)
                .fontWeight(.bold)
                .disabled(flagReason.isEmpty)
            }
        }
        .padding(30)
        .background(Color.staffBackground.ignoresSafeArea())
    }
    
    private var amortizationScheduleSheet: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.lg) {
            HStack {
                Text("Amortization Schedule")
                    .font(.staffTitle)
                    .foregroundColor(.staffTextPrimary)
                Spacer()
                Button("Close") { showAmortizationSheet = false }
                    .foregroundColor(.staffAccent)
            }
            
            ScrollView {
                VStack(spacing: 0) {
                    // Header row
                    HStack {
                        Text("No.")
                            .frame(width: 40, alignment: .leading)
                        Text("Due Date")
                            .frame(width: 120, alignment: .leading)
                        Text("EMI Amt")
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        Text("Principal")
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        Text("Interest")
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        Text("Status")
                            .frame(width: 100, alignment: .trailing)
                    }
                    .font(.staffCaption)
                    .foregroundColor(.staffTextSecondary)
                    .padding(.vertical, 8)
                    
                    Divider()
                    
                    ForEach(amortizationSchedule) { item in
                        HStack {
                            Text("\(item.installmentNumber)")
                                .frame(width: 40, alignment: .leading)
                            Text(item.dueDate)
                                .frame(width: 120, alignment: .leading)
                            Text(String(format: "%.2f", item.totalEmi))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            Text(String(format: "%.2f", item.principalComponent))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            Text(String(format: "%.2f", item.interestComponent))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            
                            // Simple label status display
                            Text(item.status.displayName)
                                .frame(width: 100, alignment: .trailing)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(emiStatusColor(item.status))
                        }
                        .font(.staffCaption)
                        .foregroundColor(.staffTextPrimary)
                        .padding(.vertical, 10)
                        
                        Divider()
                    }
                }
            }
        }
        .padding(30)
        .background(Color.staffBackground.ignoresSafeArea())
    }
    
    private func emiStatusColor(_ status: EMIStatus) -> Color {
        switch status {
        case .paid: return .staffGreen
        case .overdue: return .staffRed
        case .due: return .staffAmber
        case .upcoming: return .staffAccent
        case .partiallyPaid: return .staffAccent
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var isUrgent: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .font(.staffBody)
                .foregroundColor(.staffTextSecondary)
            Spacer()
            Text(value)
                .font(.staffBody)
                .fontWeight(.bold)
                .foregroundColor(isUrgent ? .staffRed : .staffTextPrimary)
        }
    }
}
