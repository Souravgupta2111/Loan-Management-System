//
//  PortfolioDashboardView.swift
//  LMS Staff
//
//  Branch Portfolio analytics view including multi-filters and a collection trend line chart.
//

import SwiftUI
import Charts

struct CollectionTrendItem: Identifiable {
    let id = UUID()
    let month: String
    let efficiency: Double
}

struct PortfolioDashboardView: View {
    @StateObject private var vm = PortfolioViewModel()
    @State private var selectedProductFilter: String = "All Products"
    @State private var selectedBranchFilter: String = "All Branches"
    
    // Seed collection efficiency trend data
    let trendData: [CollectionTrendItem] = [
        CollectionTrendItem(month: "Jul 25", efficiency: 98.2),
        CollectionTrendItem(month: "Aug 25", efficiency: 97.9),
        CollectionTrendItem(month: "Sep 25", efficiency: 97.4),
        CollectionTrendItem(month: "Oct 25", efficiency: 96.8),
        CollectionTrendItem(month: "Nov 25", efficiency: 97.0),
        CollectionTrendItem(month: "Dec 25", efficiency: 95.8),
        CollectionTrendItem(month: "Jan 26", efficiency: 96.1),
        CollectionTrendItem(month: "Feb 26", efficiency: 94.2),
        CollectionTrendItem(month: "Mar 26", efficiency: 94.8),
        CollectionTrendItem(month: "Apr 26", efficiency: 92.5), // declining trend highlighted
        CollectionTrendItem(month: "May 26", efficiency: 93.1),
        CollectionTrendItem(month: "Jun 26", efficiency: 91.8)  // critical attention area
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: StaffSpacing.lg) {
                // Header & Clear Filter
                HStack {
                    Text("Portfolio & Collection Trends")
                        .font(.staffTitle)
                        .foregroundColor(.staffTextPrimary)
                    
                    Spacer()
                    
                    if selectedProductFilter != "All Products" || selectedBranchFilter != "All Branches" || !vm.searchText.isEmpty {
                        Button(action: {
                            selectedProductFilter = "All Products"
                            selectedBranchFilter = "All Branches"
                            vm.searchText = ""
                        }) {
                            HStack {
                                Image(systemName: "xmark.circle")
                                Text("Clear All Filters")
                            }
                            .font(.staffCaption)
                            .foregroundColor(.staffRed)
                        }
                    }
                }
                .padding(.horizontal, StaffSpacing.lg)
                .padding(.top, StaffSpacing.lg)
                
                // Multi-filters Dropdown Bar
                HStack(spacing: StaffSpacing.md) {
                    // Product Picker
                    Menu {
                        Button("All Products") { selectedProductFilter = "All Products" }
                        Button("Personal Loan Express") { selectedProductFilter = "Personal Loan Express" }
                        Button("Home Loan Advantage") { selectedProductFilter = "Home Loan Advantage" }
                        Button("Vehicle Loan") { selectedProductFilter = "Vehicle Loan" }
                    } label: {
                        HStack {
                            Text(selectedProductFilter)
                            Image(systemName: "chevron.down")
                        }
                        .font(.staffCaption)
                        .padding(10)
                        .background(Color.staffSurface)
                        .cornerRadius(StaffCorner.sm)
                        .foregroundColor(.staffTextPrimary)
                    }
                    
                    // Branch Picker
                    Menu {
                        Button("All Branches") { selectedBranchFilter = "All Branches" }
                        Button("HQ - Main Branch") { selectedBranchFilter = "HQ - Main Branch" }
                        Button("North Zone Branch") { selectedBranchFilter = "North Zone Branch" }
                        Button("South Zone Branch") { selectedBranchFilter = "South Zone Branch" }
                    } label: {
                        HStack {
                            Text(selectedBranchFilter)
                            Image(systemName: "chevron.down")
                        }
                        .font(.staffCaption)
                        .padding(10)
                        .background(Color.staffSurface)
                        .cornerRadius(StaffCorner.sm)
                        .foregroundColor(.staffTextPrimary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, StaffSpacing.lg)
                
                // Trend Line Chart Card (US-47)
                StaffCard {
                    VStack(alignment: .leading, spacing: StaffSpacing.md) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Historical Collection Efficiency (%)")
                                    .font(.staffTitle)
                                    .foregroundColor(.staffTextPrimary)
                                Text("Alert: Efficiency has dipped below 95% threshold in Q2 2026")
                                    .font(.staffCaption)
                                    .foregroundColor(.staffRed)
                            }
                            Spacer()
                            Text("12-Month Period")
                                .font(.staffCaption)
                                .foregroundColor(.staffTextSecondary)
                        }
                        
                        // SwiftUI Line Chart
                        Chart(trendData) { item in
                            LineMark(
                                x: .value("Month", item.month),
                                y: .value("Efficiency", item.efficiency)
                            )
                            .foregroundStyle(Color.staffAccent)
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 3))
                            
                            PointMark(
                                x: .value("Month", item.month),
                                y: .value("Efficiency", item.efficiency)
                            )
                            .foregroundStyle(item.efficiency < 93.0 ? Color.staffRed : Color.staffAccent)
                        }
                        .frame(height: 220)
                        .chartYScale(domain: 85...100)
                        .chartXAxis {
                            AxisMarks(values: .automatic) { _ in
                                AxisValueLabel()
                                    .foregroundStyle(Color.staffTextSecondary)
                            }
                        }
                        .chartYAxis {
                            AxisMarks(values: .automatic) { _ in
                                AxisGridLine()
                                    .foregroundStyle(Color.staffBorder)
                                AxisValueLabel()
                                    .foregroundStyle(Color.staffTextSecondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, StaffSpacing.lg)
                
                // Active Loans Table
                StaffCard {
                    VStack(alignment: .leading, spacing: StaffSpacing.md) {
                        Text("Active Accounts Catalog")
                            .font(.staffTitle)
                            .foregroundColor(.staffTextPrimary)
                        
                        Divider()
                        
                        if vm.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            VStack(spacing: 0) {
                                // Table Header
                                HStack {
                                    Text("Account No")
                                        .font(.staffCaption)
                                        .foregroundColor(.staffTextSecondary)
                                        .frame(width: 140, alignment: .leading)
                                    
                                    Text("Borrower Name")
                                        .font(.staffCaption)
                                        .foregroundColor(.staffTextSecondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    Text("Principal")
                                        .font(.staffCaption)
                                        .foregroundColor(.staffTextSecondary)
                                        .frame(width: 120, alignment: .trailing)
                                    
                                    Text("Status")
                                        .font(.staffCaption)
                                        .foregroundColor(.staffTextSecondary)
                                        .frame(width: 100, alignment: .trailing)
                                }
                                .padding(.vertical, 8)
                                
                                Divider()
                                
                                ForEach(vm.loans) { loanWithDetails in
                                    // Local filter check
                                    let matchesProduct = selectedProductFilter == "All Products" || loanWithDetails.product.name == selectedProductFilter
                                    
                                    if matchesProduct {
                                        HStack {
                                            Text(loanWithDetails.loan.loanNumber ?? "LMS-XXXX")
                                                .font(.staffBody)
                                                .frame(width: 140, alignment: .leading)
                                                .foregroundColor(.staffTextPrimary)
                                            
                                            Text(loanWithDetails.borrower.fullName)
                                                .font(.staffBody)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .foregroundColor(.staffTextPrimary)
                                            
                                            Text(String(format: "%.2f", loanWithDetails.loan.principalAmount))
                                                .font(.staffBody)
                                                .frame(width: 120, alignment: .trailing)
                                                .foregroundColor(.staffTextPrimary)
                                            
                                            StaffStatusBadge(status: loanWithDetails.loan.status.displayName)
                                                .frame(width: 100, alignment: .trailing)
                                        }
                                        .padding(.vertical, 12)
                                        
                                        Divider()
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, StaffSpacing.lg)
            }
        }
        .background(Color.staffBackground)
        .onAppear {
            Task {
                await vm.loadPortfolio()
            }
        }
    }
}
