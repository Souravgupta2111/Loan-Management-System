//
//  LoanProduct.swift
//  LMS
//
//  Data model for the `loan_products` table.
//  Fully configurable: rate range, multiple interest types, fees, penalties,
//  tenure & amount ranges, spread over RBI base rate.
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

    var shortDescription: String {
        switch self {
        case .fixed:    return "Rate stays constant throughout the loan tenure"
        case .floating: return "Rate changes with RBI repo rate. Spread stays fixed"
        case .reducing: return "Interest calculated on reducing principal balance"
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

    // Interest rate RANGE (not a single value)
    // e.g., 8.50% - 12.50% depending on borrower profile
    var minInterestRate: Double
    var maxInterestRate: Double

    // Supported interest types — a product can offer multiple
    // e.g., Home Loan available in both Fixed and Floating
    var supportedInterestTypes: [InterestType]

    // Spread over RBI base rate (for floating-rate calculation)
    // Customer Rate = RBI Repo Rate + Spread
    // e.g., 6.50% (repo) + 2.00% (spread) = 8.50%
    var spreadOverBase: Double

    // Fees & penalties
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
        case minInterestRate = "min_interest_rate"
        case maxInterestRate = "max_interest_rate"
        case supportedInterestTypes = "supported_interest_types"
        case spreadOverBase = "spread_over_base"
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

    /// Formatted interest rate range (e.g., "8.50% - 12.50%")
    var formattedRateRange: String {
        if minInterestRate == maxInterestRate {
            return String(format: "%.2f%%", minInterestRate)
        }
        return String(format: "%.2f%% - %.2f%%", minInterestRate, maxInterestRate)
    }

    /// Short rate display for cards (e.g., "From 8.50%")
    var formattedStartingRate: String {
        String(format: "From %.2f%%", minInterestRate)
    }

    /// Supported types as readable string (e.g., "Fixed, Floating, Reducing")
    var formattedInterestTypes: String {
        supportedInterestTypes.map(\.displayName).joined(separator: ", ")
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

    /// Whether this product supports floating rates
    var supportsFloating: Bool {
        supportedInterestTypes.contains(.floating)
    }
}
