//
//  LoanProductViewModel.swift
//  LMS Staff
//
//  ViewModel for managing the catalog of loan products, rates, fees, and rules.
//

import Foundation
import Combine

@MainActor
class LoanProductViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var products: [LoanProduct] = []
    @Published var searchText: String = ""
    
    var filteredProducts: [LoanProduct] {
        if searchText.isEmpty {
            return products
        }
        return products.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.type.displayName.localizedCaseInsensitiveContains(searchText) }
    }
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let productService = LoanProductService.shared
    
    init() {}
    
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            self.products = try await productService.fetchProducts()
        } catch {
            print("❌ LOAN PRODUCT DECODING ERROR: \(error)")
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func createProduct(_ product: LoanProduct) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await productService.createProduct(product)
            await loadProducts()
            isLoading = false
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    func updateProduct(_ product: LoanProduct) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await productService.updateProduct(product)
            await loadProducts()
            isLoading = false
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    func toggleProductActiveStatus(productId: UUID, isActive: Bool) async {
        errorMessage = nil
        do {
            try await productService.toggleProductActive(productId: productId, isActive: isActive)
            await loadProducts()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
