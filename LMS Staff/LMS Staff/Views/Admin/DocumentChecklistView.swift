//
//  DocumentChecklistView.swift
//  LMS Staff
//
//  Document Checklist editor to manage required files checklist per loan type.
//

import SwiftUI

struct DocumentChecklistView: View {
    @StateObject private var vm = LoanProductViewModel()
    @State private var selectedProduct: LoanProduct?
    
    // Checklist editing state
    @State private var checklistItems: [DocumentRequirement] = []
    @State private var newItemText: String = ""
    
    var body: some View {
        HStack(spacing: 0) {
            // Left list of products
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("File Checklists")
                        .font(.staffTitle)
                        .foregroundColor(.staffTextPrimary)
                        .padding(.horizontal, StaffSpacing.lg)
                        .padding(.top, StaffSpacing.lg)
                        .padding(.bottom, StaffSpacing.md)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                
                Divider()
                    .background(Color.staffBorder)
                
                if vm.isLoading {
                    Spacer()
                    ProgressView()
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    List(vm.products, selection: $selectedProduct) { product in
                        HStack(spacing: StaffSpacing.md) {
                            Image(systemName: productIcon(for: product.type))
                                .font(.system(size: 20))
                                .foregroundColor(.staffAccent)
                                .frame(width: 36, height: 36)
                                .background(Color.staffAccentBg)
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(product.name)
                                    .font(.staffBody)
                                    .fontWeight(.bold)
                                    .foregroundColor(.staffTextPrimary)
                                Text("\(product.requiredDocuments?.count ?? 0) Requirements")
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
                        .listRowBackground(
                            selectedProduct?.id == product.id
                            ? Color.staffAccent.opacity(0.15)
                            : Color.white
                        )
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden)
                    .background(Color.staffBackground)
                }
            }
            .frame(width: 340)
            .background(Color.staffBackground)
            
            Divider()
                .background(Color.staffBorder)
            
            // Right: Checklist items console
            if let product = selectedProduct {
                checklistConsole(product)
            } else {
                VStack(spacing: StaffSpacing.md) {
                    Image(systemName: "checkmark.square.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.staffTextSecondary.opacity(0.3))
                    Text("Select a Loan Product to Edit Document Checklists")
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
    private func checklistConsole(_ item: LoanProduct) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Checklist Requirements - \(item.name)")
                        .font(.staffTitle)
                        .foregroundColor(.staffTextPrimary)
                    Text("Product category: \(item.type.displayName)")
                        .font(.staffCaption)
                        .foregroundColor(.staffTextSecondary)
                }
                Spacer()
            }
            .padding(StaffSpacing.lg)
            .background(Color.staffBackground)
            
            ScrollView {
                VStack(alignment: .leading, spacing: StaffSpacing.lg) {
                    // Quick add bar
                    StaffCard {
                        VStack(alignment: .leading, spacing: StaffSpacing.md) {
                            Text("Register New Document Requirement")
                                .font(.staffTitle)
                                .foregroundColor(.staffTextPrimary)
                            
                            Divider()
                            
                            HStack {
                                TextField("e.g. Salary Slips, Tax returns copy...", text: $newItemText)
                                    .padding(10)
                                    .background(Color.staffBackground)
                                    .cornerRadius(StaffCorner.sm)
                                    .foregroundColor(.staffTextPrimary)
                                
                                Button(action: {
                                    guard !newItemText.isEmpty else { return }
                                    checklistItems.append(DocumentRequirement(name: newItemText, isMandatory: true))
                                    newItemText = ""
                                }) {
                                    Text("Add Requirement")
                                        .font(.staffCaption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(Color.staffAccent)
                                        .cornerRadius(StaffCorner.sm)
                                }
                                .disabled(newItemText.isEmpty)
                            }
                        }
                    }
                    
                    // Checklist Table
                    StaffCard {
                        VStack(alignment: .leading, spacing: StaffSpacing.md) {
                            Text("Current Required Documents Checklist")
                                .font(.staffTitle)
                                .foregroundColor(.staffTextPrimary)
                            
                            Divider()
                            
                            if checklistItems.isEmpty {
                                Text("No documents checklist registered. Any application under this product will require no documents upload.")
                                    .font(.staffCaption)
                                    .foregroundColor(.staffTextSecondary)
                            } else {
                                ForEach(checklistItems, id: \.id) { doc in
                                    HStack {
                                        Image(systemName: "circle.fill")
                                            .resizable()
                                            .frame(width: 6, height: 6)
                                            .foregroundColor(.staffAccent)
                                        
                                        Text(doc.name)
                                            .font(.staffBody)
                                            .foregroundColor(.staffTextPrimary)
                                        
                                        Spacer()
                                        
                                        Toggle("Mandatory", isOn: Binding(
                                            get: { doc.isMandatory },
                                            set: { newValue in
                                                if let idx = checklistItems.firstIndex(where: { $0.id == doc.id }) {
                                                    checklistItems[idx].isMandatory = newValue
                                                }
                                            }
                                        ))
                                        .labelsHidden()
                                        .tint(.staffRed)
                                        
                                        Text(doc.isMandatory ? "Required" : "Optional")
                                            .font(.staffCaption)
                                            .foregroundColor(doc.isMandatory ? .staffRed : .staffTextSecondary)
                                            .frame(width: 60, alignment: .leading)
                                        
                                        Button(action: {
                                            checklistItems.removeAll { $0.id == doc.id }
                                        }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(.staffRed)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    
                                    Divider()
                                }
                            }
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
                    title: "Apply Checklist Changes",
                    style: .primary,
                    icon: "checkmark.circle.fill"
                ) {
                    var updated = item
                    updated.requiredDocuments = checklistItems
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
            checklistItems = item.requiredDocuments ?? []
        }
        .onChange(of: item) { newItem in
            checklistItems = newItem.requiredDocuments ?? []
        }
    }
    
    private func productIcon(for type: LoanType) -> String {
        switch type {
        case .personal: return "person.fill"
        case .home: return "house.fill"
        case .vehicle: return "car.fill"
        case .education: return "graduationcap.fill"
        case .business: return "building.2.fill"
        case .gold: return "sparkles"
        case .agriculture: return "leaf.fill"
        case .other: return "doc.fill"
        }
    }
}
