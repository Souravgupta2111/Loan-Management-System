//
//  UnderwritingService.swift
//  LMS Staff
//
//  Underwriting Engine for calculating loan eligibility, risk grades,
//  and suggesting interest rates and tenures based on borrower data.
//

import Foundation

struct UnderwritingSuggestion {
    let maxEligibleAmount: Double
    let suggestedAmount: Double      // min(requested, maxEligible)
    let suggestedInterestRate: Double
    let suggestedTenureMonths: Int
    let monthlyEMI: Double
    let foirRatio: Double
    let riskGrade: String            // "A", "B", "C", "D", "E"
    let isEligible: Bool
    let rejectionReasons: [String]   // empty if eligible
    let incomeVerified: Bool
}

class UnderwritingService {
    
    static let shared = UnderwritingService()
    private init() {}
    
    /// Calculate loan eligibility and suggestions
    func calculateSuggestion(
        monthlyIncome: Double,
        creditScore: Int,
        employmentType: EmploymentType,
        requestedAmount: Double,
        product: LoanProduct,
        existingEMIs: Double = 0, // In reality, this comes from the AA data
        isIncomeVerified: Bool
    ) -> UnderwritingSuggestion {
        
        var reasons: [String] = []
        
        // 1. Determine FOIR (Fixed Obligation to Income Ratio)
        // This is the maximum % of income that can go towards EMIs
        let maxFoir: Double
        switch employmentType {
        case .salaried:
            maxFoir = 0.50 // 50%
        case .selfEmployed, .business:
            maxFoir = 0.40 // 40%
        case .retired:
            maxFoir = 0.35 // 35%
        default:
            maxFoir = 0.30 // 30% for others
        }
        
        // 2. Max EMI Capacity
        let maxEmiCapacity = (monthlyIncome * maxFoir) - existingEMIs
        
        if maxEmiCapacity <= 0 {
            reasons.append("Existing obligations exceed FOIR limit (max EMI capacity: ₹0).")
        }
        
        // 3. Risk Grade & Interest Rate
        // Grade A: >= 750, Grade B: 700-749, Grade C: 650-699, Grade D: 600-649, Grade E: < 600
        let riskGrade: String
        let suggestedRate: Double
        
        let rateRange = max(product.maxInterestRate - product.minInterestRate, 0)
        
        if creditScore >= 750 {
            riskGrade = "A"
            suggestedRate = product.minInterestRate
        } else if creditScore >= 700 {
            riskGrade = "B"
            suggestedRate = product.minInterestRate + (rateRange * 0.25)
        } else if creditScore >= 650 {
            riskGrade = "C"
            suggestedRate = product.minInterestRate + (rateRange * 0.50)
        } else if creditScore >= 600 {
            riskGrade = "D"
            suggestedRate = product.minInterestRate + (rateRange * 0.75)
        } else {
            riskGrade = "E"
            suggestedRate = product.maxInterestRate
            reasons.append("Credit score (\(creditScore)) is too low.")
        }
        
        // 4. Calculate Max Eligible Amount
        // Reverse EMI formula: P = (E * ( (1+R)^N - 1 )) / (R * (1+R)^N)
        // R = monthly interest rate, E = EMI, N = max tenure
        
        let maxTenure = product.maxTenureMonths
        let monthlyRate = (suggestedRate / 100.0) / 12.0
        
        var maxEligibleAmount: Double = 0
        if monthlyRate > 0 && maxEmiCapacity > 0 {
            let x = pow(1.0 + monthlyRate, Double(maxTenure))
            maxEligibleAmount = (maxEmiCapacity * (x - 1.0)) / (monthlyRate * x)
        } else if maxEmiCapacity > 0 {
            maxEligibleAmount = maxEmiCapacity * Double(maxTenure)
        }
        
        // Cap by product max amount
        maxEligibleAmount = min(maxEligibleAmount, product.maxAmount)
        
        if maxEligibleAmount < product.minAmount {
            reasons.append("Eligible amount (₹\(String(format: "%.0f", maxEligibleAmount))) is less than product minimum (₹\(String(format: "%.0f", product.minAmount))).")
        }
        
        // 5. Suggested Amount
        let suggestedAmount = min(requestedAmount, maxEligibleAmount)
        
        // 6. Suggested Tenure
        // Find shortest tenure where EMI <= maxEmiCapacity
        var suggestedTenure = product.minTenureMonths
        var finalEmi: Double = 0
        
        if suggestedAmount > 0 {
            for tenure in product.minTenureMonths...product.maxTenureMonths {
                let x = pow(1.0 + monthlyRate, Double(tenure))
                let emi = (monthlyRate > 0) ? (suggestedAmount * (monthlyRate * x) / (x - 1.0)) : (suggestedAmount / Double(tenure))
                
                if emi <= maxEmiCapacity {
                    suggestedTenure = tenure
                    finalEmi = emi
                    break
                }
                
                // If we hit the max tenure, just use it (EMI might be > capacity if requestedAmount > maxEligibleAmount, but we capped it)
                if tenure == product.maxTenureMonths {
                    suggestedTenure = tenure
                    finalEmi = emi
                }
            }
        }
        
        // 7. Calculate Actual FOIR
        let totalObligations = finalEmi + existingEMIs
        let actualFoir = monthlyIncome > 0 ? (totalObligations / monthlyIncome) : 1.0
        
        let isEligible = reasons.isEmpty && suggestedAmount >= product.minAmount && riskGrade != "E"
        
        return UnderwritingSuggestion(
            maxEligibleAmount: maxEligibleAmount,
            suggestedAmount: suggestedAmount,
            suggestedInterestRate: suggestedRate,
            suggestedTenureMonths: suggestedTenure,
            monthlyEMI: finalEmi,
            foirRatio: actualFoir,
            riskGrade: riskGrade,
            isEligible: isEligible,
            rejectionReasons: reasons,
            incomeVerified: isIncomeVerified
        )
    }
}
