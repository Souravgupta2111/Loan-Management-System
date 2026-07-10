import Foundation
import Supabase

class LoanProductService {
    
    static let shared = LoanProductService()
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    func fetchProducts() async throws -> [LoanProduct] {
        let products: [LoanProduct] = try await supabase.database
            .from("loan_products")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
        return products
    }
    
    func toggleProductActive(productId: UUID, isActive: Bool) async throws {
        try await supabase.database
            .from("loan_products")
            .update(["is_active": AnyEncodable(isActive)])
            .eq("id", value: productId)
            .execute()
            
        try await AuditService.shared.logAction(
            action: isActive ? "ACTIVATE_PRODUCT" : "DEACTIVATE_PRODUCT",
            tableName: "loan_products",
            recordId: productId,
            summary: "\(isActive ? "Activated" : "Deactivated") loan product \(productId)"
        )
    }
    
    func createProduct(_ product: LoanProduct) async throws -> LoanProduct {
        let payload: [String: AnyEncodable] = [
            "id": AnyEncodable(product.id),
            "name": AnyEncodable(product.name),
            "type": AnyEncodable(product.type.rawValue),
            "description": AnyEncodable(product.description ?? ""),
            "min_amount": AnyEncodable(product.minAmount),
            "max_amount": AnyEncodable(product.maxAmount),
            "min_tenure_months": AnyEncodable(product.minTenureMonths),
            "max_tenure_months": AnyEncodable(product.maxTenureMonths),
            "min_interest_rate": AnyEncodable(product.minInterestRate),
            "max_interest_rate": AnyEncodable(product.maxInterestRate),
            "supported_interest_types": AnyEncodable(product.supportedInterestTypes.map(\.rawValue)),
            "spread_over_base": AnyEncodable(product.spreadOverBase),
            "processing_fee_pct": AnyEncodable(product.processingFeePct),
            "prepayment_penalty_pct": AnyEncodable(product.prepaymentPenaltyPct),
            "late_penalty_pct_per_month": AnyEncodable(product.latePenaltyPctPerMonth),
            "requires_collateral": AnyEncodable(product.requiresCollateral),
            "is_active": AnyEncodable(product.isActive),
            "eligibility_criteria": AnyEncodable(product.eligibilityCriteria ?? [:]),
            "required_documents": AnyEncodable(product.requiredDocuments ?? [])
        ]
        
        let newProduct: LoanProduct = try await supabase.database
            .from("loan_products")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
            
        try await AuditService.shared.logAction(
            action: "CREATE_PRODUCT",
            tableName: "loan_products",
            recordId: newProduct.id,
            summary: "Created new loan product: \(product.name)"
        )
        
        return newProduct
    }
    
    func updateProduct(_ product: LoanProduct) async throws -> LoanProduct {
        let payload: [String: AnyEncodable] = [
            "name": AnyEncodable(product.name),
            "type": AnyEncodable(product.type.rawValue),
            "description": AnyEncodable(product.description ?? ""),
            "min_amount": AnyEncodable(product.minAmount),
            "max_amount": AnyEncodable(product.maxAmount),
            "min_tenure_months": AnyEncodable(product.minTenureMonths),
            "max_tenure_months": AnyEncodable(product.maxTenureMonths),
            "min_interest_rate": AnyEncodable(product.minInterestRate),
            "max_interest_rate": AnyEncodable(product.maxInterestRate),
            "supported_interest_types": AnyEncodable(product.supportedInterestTypes.map(\.rawValue)),
            "spread_over_base": AnyEncodable(product.spreadOverBase),
            "processing_fee_pct": AnyEncodable(product.processingFeePct),
            "prepayment_penalty_pct": AnyEncodable(product.prepaymentPenaltyPct),
            "late_penalty_pct_per_month": AnyEncodable(product.latePenaltyPctPerMonth),
            "requires_collateral": AnyEncodable(product.requiresCollateral),
            "is_active": AnyEncodable(product.isActive),
            "eligibility_criteria": AnyEncodable(product.eligibilityCriteria ?? [:]),
            "required_documents": AnyEncodable(product.requiredDocuments ?? [])
        ]
        
        let updatedProduct: LoanProduct = try await supabase.database
            .from("loan_products")
            .update(payload)
            .eq("id", value: product.id)
            .select()
            .single()
            .execute()
            .value
            
        try await AuditService.shared.logAction(
            action: "UPDATE_PRODUCT",
            tableName: "loan_products",
            recordId: product.id,
            summary: "Updated loan product configuration: \(product.name)"
        )
        
        return updatedProduct
    }
}
