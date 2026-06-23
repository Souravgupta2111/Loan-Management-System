//
//  LoanProduct.swift
//  LMS
//
//  Data model for the `loan_products` table.
//  Fully configurable: base rate, fees, penalties, tenure & amount ranges.
//

import Foundation

// MARK: - Enums

enum LoanType: String, Codable, CaseIterable, Identifiable {
    case personal
    case home
    case vehicle
    case education
    case business
    case gold
    case agriculture
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .personal:    return "Personal Loan"
        case .home:        return "Home Loan"
        case .vehicle:     return "Vehicle Loan"
        case .education:   return "Education Loan"
        case .business:    return "Business Loan"
        case .gold:        return "Gold Loan"
        case .agriculture: return "Agriculture Loan"
        case .other:       return "Other"
        }
    }

    var icon: String {
        switch self {
        case .personal:    return "person.fill"
        case .home:        return "house.fill"
        case .vehicle:     return "car.fill"
        case .education:   return "graduationcap.fill"
        case .business:    return "briefcase.fill"
        case .gold:        return "gift.fill"
        case .agriculture: return "leaf.fill"
        case .other:       return "doc.fill"
        }
    }
}

enum InterestType: String, Codable, CaseIterable, Identifiable {
    case fixed
    case floating
    case reducing

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fixed:    return "Fixed"
        case .floating: return "Floating"
        case .reducing: return "Reducing Balance"
        }
    }
}

// MARK: - Loan Product Model

struct LoanProduct: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var type: LoanType
    var description: String?

    // Amount range
    var minAmount: Double
    var maxAmount: Double

    // Tenure range
    var minTenureMonths: Int
    var maxTenureMonths: Int

    // Interest & fees — fully configurable
    var baseInterestRate: Double
    var interestType: InterestType
    var processingFeePct: Double
    var prepaymentPenaltyPct: Double
    var latePenaltyPctPerMonth: Double

    // Configuration
    var requiresCollateral: Bool
    var isActive: Bool
    var eligibilityCriteria: [String: String]?
    var requiredDocuments: [String]?

    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case description
        case minAmount = "min_amount"
        case maxAmount = "max_amount"
        case minTenureMonths = "min_tenure_months"
        case maxTenureMonths = "max_tenure_months"
        case baseInterestRate = "base_interest_rate"
        case interestType = "interest_type"
        case processingFeePct = "processing_fee_pct"
        case prepaymentPenaltyPct = "prepayment_penalty_pct"
        case latePenaltyPctPerMonth = "late_penalty_pct_per_month"
        case requiresCollateral = "requires_collateral"
        case isActive = "is_active"
        case eligibilityCriteria = "eligibility_criteria"
        case requiredDocuments = "required_documents"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - Computed Properties

    /// Formatted interest rate string (e.g., "10.50% Reducing")
    var formattedRate: String {
        String(format: "%.2f%% %@", baseInterestRate, interestType.displayName)
    }

    /// Formatted amount range string (e.g., "₹10,000 - ₹1,00,00,000")
    var formattedAmountRange: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.locale = Locale(identifier: "en_IN")
        let min = formatter.string(from: NSNumber(value: minAmount)) ?? "\(minAmount)"
        let max = formatter.string(from: NSNumber(value: maxAmount)) ?? "\(maxAmount)"
        return "\(min) - \(max)"
    }

    /// Formatted tenure range string (e.g., "3 - 360 months")
    var formattedTenureRange: String {
        "\(minTenureMonths) - \(maxTenureMonths) months"
    }
}
