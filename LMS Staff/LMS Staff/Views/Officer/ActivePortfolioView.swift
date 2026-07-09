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
                    List(vm.filteredLoans, id: \.id) { item in
                        Button(action: {
                            selectedLoan = item
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
            .frame(width: 360)
            .background(Color.staffBackground)
            
            Divider()
                .background(Color.staffBorder)
            
            // Right Column: Active Loan details & actions
            if let loanWithDetails = selectedLoan {
                LoanInspectorView(
                    loanWithDetails: loanWithDetails,
                    onActionTriggered: {
                        Task {
                            if let staff = authViewModel.currentStaff {
                                await vm.loadPortfolio(forOfficerId: staff.id)
                            }
                            if let selected = selectedLoan {
                                selectedLoan = vm.loans.first(where: { $0.id == selected.id })
                            }
                        }
                    }
                )
                .id(loanWithDetails.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
}
