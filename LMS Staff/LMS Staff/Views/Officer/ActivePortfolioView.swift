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
    
    @State private var selectedTab: Int = 0
    @State private var amortizationSchedule: [EMIScheduleItem] = []
    @State private var isLoadingAmortization: Bool = false
    
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
                    await vm.loadPortfolio(forOfficerId: staff.id)
                }
            }
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
            }
            .padding(StaffSpacing.lg)
            .background(Color.staffBackground)
            
            Picker("Tabs", selection: $selectedTab) {
                Text("Overview").tag(0)
                Text("Amortization Schedule").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, StaffSpacing.lg)
            .padding(.top, StaffSpacing.lg)
            
            ScrollView {
                if selectedTab == 0 {
                    VStack(spacing: StaffSpacing.lg) {
                        HStack(spacing: StaffSpacing.lg) {
                            StaffCard {
                                VStack(alignment: .leading, spacing: StaffSpacing.md) {
                                    Text("Outstanding Summary")
                                        .font(.system(.headline, design: .rounded).weight(.bold))
                                        .foregroundColor(.staffTextPrimary)
                                    
                                    Divider()
                                        .padding(.bottom, 4)
                                    
                                    InfoRow(label: "Principal Disbursed", value: "₹\(String(format: "%.2f", item.loan.principalAmount))")
                                    InfoRow(label: "Outstanding Principal", value: "₹\(String(format: "%.2f", item.loan.outstandingPrincipal))")
                                    InfoRow(label: "Outstanding Interest", value: "₹\(String(format: "%.2f", item.loan.outstandingInterest))")
                                    InfoRow(label: "Interest Rate Config", value: "\(String(format: "%.2f", item.loan.interestRate))% (\(item.loan.interestType.displayName))")
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            }
                            
                            StaffCard {
                                VStack(alignment: .leading, spacing: StaffSpacing.md) {
                                    Text("Repayment Tracking")
                                        .font(.system(.headline, design: .rounded).weight(.bold))
                                        .foregroundColor(.staffTextPrimary)
                                    
                                    Divider()
                                        .padding(.bottom, 4)
                                    
                                    InfoRow(label: "Overdue Days", value: "\(item.loan.overdueDays) Days", isUrgent: item.loan.overdueDays > 0)
                                    InfoRow(label: "Total Overdue Amount", value: "₹\(String(format: "%.2f", item.loan.totalOverdue))", isUrgent: item.loan.totalOverdue > 0)
                                    InfoRow(label: "Disbursement Ref", value: item.loan.disbursementReference ?? "N/A")
                                    InfoRow(label: "ECS Repayment", value: item.loan.repaymentMode.displayName)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, StaffSpacing.lg)
                    .padding(.top, StaffSpacing.lg)
                } else {
                    if isLoadingAmortization {
                        ProgressView().padding(.top, 50)
                    } else if amortizationSchedule.isEmpty {
                        EmptyStateView(icon: "tablecells", title: "No Schedule", message: "Amortization schedule not found.")
                            .padding(.top, 50)
                    } else {
                        VStack(spacing: 0) {
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
                            .padding(.horizontal, StaffSpacing.lg)
                            
                            Divider()
                            
                            let sortedSchedule = amortizationSchedule.sorted(by: { $0.installmentNumber < $1.installmentNumber })
                            let firstUnpaidIndex = sortedSchedule.firstIndex(where: { $0.status != .paid }) ?? sortedSchedule.count
                            
                            ForEach(Array(sortedSchedule.enumerated()), id: \.element.id) { index, emi in
                                let statusInfo = getEmiStatusAndStyle(index: index, firstUnpaidIndex: firstUnpaidIndex, emi: emi)
                                HStack {
                                    Text("\(emi.installmentNumber)")
                                        .frame(width: 40, alignment: .leading)
                                    Text(emi.dueDate)
                                        .frame(width: 120, alignment: .leading)
                                    Text(String(format: "%.2f", emi.totalEmi))
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                    Text(String(format: "%.2f", emi.principalComponent))
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                    Text(String(format: "%.2f", emi.interestComponent))
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                    
                                    Text(statusInfo.text)
                                        .frame(width: 100, alignment: .trailing)
                                        .font(.caption.weight(.bold))
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
                        .padding(StaffSpacing.lg)
                    }
                }
            }
        }
        .task(id: item.loan.id) {
            isLoadingAmortization = true
            if let fetched = try? await LoanPortfolioService.shared.fetchEMISchedule(forLoanId: item.loan.id) {
                self.amortizationSchedule = fetched
            } else {
                self.amortizationSchedule = []
            }
            isLoadingAmortization = false
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
    
    private func emiStatusColor(_ status: EMIStatus) -> Color {
        switch status {
        case .paid: return .staffGreen
        case .overdue: return .staffRed
        case .due: return .staffAmber
        case .upcoming: return .staffAccent
        case .partiallyPaid: return .staffAccent
        case .writtenOff: return .staffTextSecondary
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var isUrgent: Bool = false
    
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.subheadline.weight(.regular))
                .foregroundColor(.staffTextSecondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(.body, design: .rounded).weight(.bold))
                .foregroundColor(isUrgent ? .staffRed : .staffTextPrimary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }
}
