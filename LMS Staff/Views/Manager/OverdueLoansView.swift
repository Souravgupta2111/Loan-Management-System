//
//  OverdueLoansView.swift
//  LMS Staff
//
//  Overdue Loan collection center for tracking buckets, log attempts, restructuring, and write-offs.
//

import SwiftUI
import Charts

struct OverdueLoansView: View {
    @StateObject private var vm = NPAViewModel()
    @State private var selectedLoan: LoanWithDetails?
    
    // Tab bucket selection
    @State private var activeBucket: OverdueBucket = .tier30
    
    enum OverdueBucket: String, CaseIterable {
        case tier30 = "30-59 Days"
        case tier60 = "60-89 Days"
        case tier90 = "90+ Days (NPA)"
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left list of bucket items & Trends
            VStack(alignment: .leading, spacing: 0) {
                Text("NPA Recovery Hub")
                    .font(.staffTitle)
                    .foregroundColor(.staffTextPrimary)
                    .padding(.horizontal, StaffSpacing.lg)
                    .padding(.top, StaffSpacing.lg)
                
                // Live Collection Trends
                if !vm.collectionTrends.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Collection Efficiency")
                            .font(.staffCaption)
                            .foregroundColor(.staffTextSecondary)
                        
                        Chart(vm.collectionTrends) { item in
                            LineMark(
                                x: .value("Month", item.month),
                                y: .value("Efficiency", item.efficiency)
                            )
                            .foregroundStyle(Color.staffAccent)
                            .interpolationMethod(.catmullRom)
                            
                            PointMark(
                                x: .value("Month", item.month),
                                y: .value("Efficiency", item.efficiency)
                            )
                            .foregroundStyle(item.efficiency < 93.0 ? Color.staffRed : Color.staffAccent)
                        }
                        .frame(height: 100)
                        .chartYScale(domain: 0...100)
                        .chartXAxis {
                            AxisMarks(values: .automatic) { _ in
                                AxisValueLabel()
                                    .font(.system(size: 8))
                                    .foregroundStyle(Color.staffTextSecondary)
                            }
                        }
                    }
                    .padding(StaffSpacing.md)
                    .background(Color.staffSurface)
                    .cornerRadius(StaffCorner.md)
                    .padding(.horizontal, StaffSpacing.md)
                    .padding(.top, StaffSpacing.md)
                }
                
                // Bucket selectors
                HStack(spacing: 0) {
                    ForEach(OverdueBucket.allCases, id: \.self) { bucket in
                        Button(action: { activeBucket = bucket }) {
                            VStack(spacing: 6) {
                                Text(bucket.rawValue)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(activeBucket == bucket ? .staffAccent : .staffTextSecondary)
                                Rectangle()
                                    .fill(activeBucket == bucket ? Color.staffAccent : Color.clear)
                                    .frame(height: 2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, StaffSpacing.md)
                
                Divider()
                    .background(Color.staffBorder)
                
                // Render selected bucket list
                let list = bucketList(activeBucket)
                
                if vm.isLoading {
                    Spacer()
                    ProgressView()
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else if list.isEmpty {
                    Spacer()
                    EmptyStateView(
                        icon: "checkmark.shield.fill",
                        title: "Bucket Clean",
                        message: "No delinquent loans fall in this overdue duration bucket."
                    )
                    Spacer()
                } else {
                    List(list, selection: $selectedLoan) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.loan.loanNumber ?? "LMS-XXXX")
                                    .font(.staffBody)
                                    .fontWeight(.bold)
                                    .foregroundColor(.staffTextPrimary)
                                Spacer()
                                Text("\(item.loan.overdueDays) Days")
                                    .font(.staffCaption)
                                    .foregroundColor(.staffRed)
                            }
                            
                            HStack {
                                Text(item.borrower.fullName)
                                    .font(.staffCaption)
                                    .foregroundColor(.staffTextSecondary)
                                Spacer()
                                Text("O/S: INR \(String(format: "%.0f", item.loan.outstandingPrincipal))")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.staffTextPrimary)
                            }
                        }
                        .padding(.vertical, 4)
                        .tag(item)
                        .listRowBackground(selectedLoan == item ? Color.staffAccent.opacity(0.1) : Color.staffSurface)
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden)
                    .background(Color.staffBackground)
                }
            }
            .frame(width: 320)
            .background(Color.staffBackground)
            
            Divider()
                .background(Color.staffBorder)
            
            // Right detailed recovery panel
            if let loanWithDetails = selectedLoan {
                LoanInspectorView(
                    loanWithDetails: loanWithDetails,
                    onActionTriggered: {
                        Task {
                            await vm.loadOverdueAccounts()
                            selectedLoan = nil
                        }
                    }
                )
                .id(loanWithDetails.loan.id) // Force reload if selection changes
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: StaffSpacing.md) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.staffTextSecondary.opacity(0.3))
                    Text("Select Delinquent Account to Inspect Recovery Actions")
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
                await vm.loadOverdueAccounts()
            }
        }
    }
    
    // MARK: - Helpers
    
    private func bucketList(_ bucket: OverdueBucket) -> [LoanWithDetails] {
        switch bucket {
        case .tier30:
            return vm.tier30To59
        case .tier60:
            return vm.tier60To89
        case .tier90:
            return vm.tier90PlusNPA
        }
    }
}
