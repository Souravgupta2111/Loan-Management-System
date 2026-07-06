//
//  LoanProductsCatalogView.swift
//  LMS
//
//  Shows all active loan products to the borrower.
//

import SwiftUI

struct LoanProductsCatalogView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var products: [LoanProduct] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
                Color.appBackground.ignoresSafeArea()
                
                if isLoading {
                    ProgressView("Loading Products...")
                } else if let error = errorMessage {
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.accentRed)
                        Text("Failed to load products")
                            .font(.cardTitle)
                        Text(error)
                            .font(.bodyRegular)
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Retry") {
                            Task {
                                await fetchProducts()
                            }
                        }
                        .padding(.top, Spacing.sm)
                    }
                    .padding()
                } else if products.isEmpty {
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.textSecondary)
                        Text("No Products Available")
                            .font(.cardTitle)
                        Text("There are no active loan products available at the moment.")
                            .font(.bodyRegular)
                            .foregroundColor(.textSecondary)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: Spacing.lg) {
                            ForEach(products) { product in
                                NavigationLink(destination: ProductDetailView(product: product)) {
                                    ProductCatalogRow(product: product)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(Spacing.lg)
                    }
                    .refreshable {
                        await fetchProducts()
                    }
                }

            }
            .navigationBarBackButtonHidden(true)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    GlassBackButton { dismiss() }
                }
            }
            .navigationTitle("Apply Loan")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await fetchProducts()
            }
    }
    
    private func fetchProducts() async {
        isLoading = true
        errorMessage = nil
        do {
            products = try await LoanService.shared.fetchActiveProducts()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct ProductCatalogRow: View {
    let product: LoanProduct
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.cardTitle)
                        .foregroundColor(.textPrimary)
                    Text("Starts from \(product.formattedStartingRate)")
                        .font(.caption)
                        .foregroundColor(.accentGreen)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentGreenBg)
                        .clipShape(Capsule())
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.textSecondary)
            }
            
            Text(product.description ?? "")
                .font(.bodyRegular)
                .foregroundColor(.textSecondary)
                .lineLimit(2)
            
            Divider()
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Amount Range")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    Text(product.formattedAmountRange)
                        .font(.bodyLarge)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Tenure Range")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    Text("\(product.minTenureMonths)-\(product.maxTenureMonths) Months")
                        .font(.bodyLarge)
                }
            }
        }
        .padding(Spacing.lg)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Corner.lg))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

struct ProductDetailView: View {
    let product: LoanProduct
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                // Header
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(product.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.textPrimary)
                    
                    Text(product.description ?? "")
                        .font(.bodyRegular)
                        .foregroundColor(.textSecondary)
                }
                
                // Key Metrics
                HStack(spacing: Spacing.md) {
                    MetricCard(title: "Interest Rate", value: product.formattedStartingRate, subtitle: product.formattedInterestTypes)
                    MetricCard(title: "Max Tenure", value: "\(product.maxTenureMonths) Mos", subtitle: "")
                }
                
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Loan Amount")
                        .font(.cardTitle)
                    Text(product.formattedAmountRange)
                        .font(.bodyLarge)
                        .foregroundColor(.accentGreen)
                }
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: Corner.md))
                
                // Required Documents
                if let docs = product.requiredDocuments, !docs.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Required Documents")
                            .font(.cardTitle)
                        
                        VStack(spacing: 0) {
                            ForEach(docs.indices, id: \.self) { index in
                                let doc = docs[index]
                                HStack {
                                    Image(systemName: "doc.text")
                                        .foregroundColor(.accentDark)
                                    Text(doc.name)
                                        .font(.bodyRegular)
                                    Spacer()
                                    if doc.isMandatory {
                                        Text("Required")
                                            .font(.caption)
                                            .foregroundColor(.accentRed)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.accentRed.opacity(0.1))
                                            .clipShape(Capsule())
                                    } else {
                                        Text("Optional")
                                            .font(.caption)
                                            .foregroundColor(.textSecondary)
                                    }
                                }
                                .padding(.vertical, Spacing.sm)
                                
                                if index < docs.count - 1 {
                                    Divider()
                                }
                            }
                        }
                        .padding(Spacing.lg)
                        .background(Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Corner.md))
                    }
                }
                
                NavigationLink(destination: LoanApplicationFlowView()) {
                    Text("Apply Now")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentGreen)
                        .cornerRadius(Corner.lg)
                }
                .padding(.top, Spacing.md)
                
            }
            .padding(Spacing.xl)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar { ToolbarItem(placement: .topBarLeading) { GlassBackButton { dismiss() } } }
        .navigationTitle("Product Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.textSecondary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Corner.md))
    }
}
