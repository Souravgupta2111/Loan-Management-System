//
//  LoanProductSettingsView.swift
//  LMS Staff
//
//  Manager Settings view to adjust active interest rates and fees.
//

import SwiftUI

struct LoanProductSettingsView: View {
    @StateObject private var vm = LoanProductViewModel()
    @State private var selectedProduct: LoanProduct?
    
    // Sliders state
    @State private var minRate: Double = 8.5
    @State private var maxRate: Double = 12.5
    @State private var processingFee: Double = 1.0
    
    var body: some View {
        HStack(spacing: 0) {
            // Left list of products
            VStack(alignment: .leading, spacing: 0) {
                Text("Product Guidelines")
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
                } else {
                    List(vm.products, selection: $selectedProduct) { product in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(product.name)
                                    .font(.staffBody)
                                    .fontWeight(.bold)
                                    .foregroundColor(.staffTextPrimary)
                                Text(product.type.displayName)
                                    .font(.staffCaption)
                                    .foregroundColor(.staffTextSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.staffTextSecondary)
                        }
                        .padding(.vertical, 4)
                        .tag(product)
                        .listRowBackground(Color.staffSurface)
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
            
            // Right: Adjustment form panel
            if let product = selectedProduct {
                adjustmentConsole(product)
            } else {
                VStack(spacing: StaffSpacing.md) {
                    Image(systemName: "slider.horizontal.3")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.staffTextSecondary.opacity(0.3))
                    Text("Select a Loan Product to Adjust Parameters")
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
                await vm.loadProducts()
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func adjustmentConsole(_ item: LoanProduct) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.staffTitle)
                        .foregroundColor(.staffTextPrimary)
                    Text("Current Rates Range: \(item.formattedRateRange)")
                        .font(.staffCaption)
                        .foregroundColor(.staffTextSecondary)
                }
                Spacer()
            }
            .padding(StaffSpacing.lg)
            .background(Color.staffSurface)
            
            ScrollView {
                VStack(alignment: .leading, spacing: StaffSpacing.xl) {
                    StaffCard {
                        VStack(alignment: .leading, spacing: StaffSpacing.md) {
                            Text("Configure Interest Rates Boundary")
                                .font(.staffTitle)
                                .foregroundColor(.staffTextPrimary)
                            
                            Divider()
                            
                            Text("Minimum Interest Rate: \(String(format: "%.2f", minRate))%")
                                .font(.staffBody)
                            Slider(value: $minRate, in: 1.0...min(maxRate, 30.0), step: 0.25)
                            
                            Text("Maximum Interest Rate: \(String(format: "%.2f", maxRate))%")
                                .font(.staffBody)
                            Slider(value: $maxRate, in: max(minRate, 1.0)...30.0, step: 0.25)
                        }
                    }
                    
                    StaffCard {
                        VStack(alignment: .leading, spacing: StaffSpacing.md) {
                            Text("Fees & Charges Adjustments")
                                .font(.staffTitle)
                                .foregroundColor(.staffTextPrimary)
                            
                            Divider()
                            
                            Text("Processing Fee Pct: \(String(format: "%.2f", processingFee))%")
                                .font(.staffBody)
                            Slider(value: $processingFee, in: 0.0...10.0, step: 0.1)
                        }
                    }
                }
                .padding(StaffSpacing.lg)
            }
            
            Divider()
                .background(Color.staffBorder)
            
            // Footer: Save Button
            HStack {
                Spacer()
                StaffButton(
                    title: "Apply Parameter Changes",
                    style: .primary,
                    icon: "checkmark.circle.fill"
                ) {
                    var updated = item
                    updated.minInterestRate = minRate
                    updated.maxInterestRate = maxRate
                    updated.processingFeePct = processingFee
                    
                    Task {
                        if await vm.updateProduct(updated) {
                            selectedProduct = updated
                        }
                    }
                }
                .frame(width: 280)
            }
            .padding(StaffSpacing.lg)
            .background(Color.staffSurface)
        }
        .onAppear {
            // Seed sliders state from selected product
            minRate = item.minInterestRate
            maxRate = item.maxInterestRate
            processingFee = item.processingFeePct
        }
        .onChange(of: item) { newItem in
            minRate = newItem.minInterestRate
            maxRate = newItem.maxInterestRate
            processingFee = newItem.processingFeePct
        }
    }
}
