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
        
        let maxEmiCapacity = (monthlyIncome * maxFoir) - existingEMIs
        
        if maxEmiCapacity <= 0 {
            reasons.append("Existing obligations exceed FOIR limit (max EMI capacity: ₹0).")
        }
        
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
        
        
        let maxTenure = product.maxTenureMonths
        let monthlyRate = (suggestedRate / 100.0) / 12.0
        
        var maxEligibleAmount: Double = 0
        if monthlyRate > 0 && maxEmiCapacity > 0 {
            let x = pow(1.0 + monthlyRate, Double(maxTenure))
            maxEligibleAmount = (maxEmiCapacity * (x - 1.0)) / (monthlyRate * x)
        } else if maxEmiCapacity > 0 {
            maxEligibleAmount = maxEmiCapacity * Double(maxTenure)
        }
        
        maxEligibleAmount = min(maxEligibleAmount, product.maxAmount)
        
        if maxEligibleAmount < product.minAmount {
            reasons.append("Eligible amount (₹\(String(format: "%.0f", maxEligibleAmount))) is less than product minimum (₹\(String(format: "%.0f", product.minAmount))).")
        }
        
        let suggestedAmount = min(requestedAmount, maxEligibleAmount)
        
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
                
                if tenure == product.maxTenureMonths {
                    suggestedTenure = tenure
                    finalEmi = emi
                }
            }
        }
        
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
