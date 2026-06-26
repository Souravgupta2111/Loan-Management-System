//
//  ReportService.swift
//  LMS Staff
//
//  Service for compiling portfolio report metrics, collection efficiency, and exports.
//

import Foundation
import Supabase

struct PortfolioReport: Hashable {
    let totalDisbursed: Double
    let activePortfolio: Double
    let npaRatio: Double
    let collectionEfficiency: Double
    let totalCollected: Double
    let totalDue: Double
}

class ReportService {
    
    static let shared = ReportService()
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    /// Compiles consolidated portfolio metrics
    func compileConsolidatedReport() async throws -> PortfolioReport {
        // Fetch all loans
        let loans: [Loan] = try await supabase.database
            .from("loans")
            .select()
            .execute()
            .value
            
        // Calculate principal total disbursed
        let totalDisbursed = loans.reduce(0.0) { $0 + $1.principalAmount }
        
        // Active Portfolio (outstanding principal + outstanding interest for non-written-off/non-closed loans)
        let activeLoans = loans.filter { $0.status == .active || $0.status == .npa || $0.status == .restructured }
        let activePortfolio = activeLoans.reduce(0.0) { $0 + $1.outstandingPrincipal + $1.outstandingInterest }
        
        // NPA Loans
        let npaLoans = loans.filter { $0.status == .npa }
        let npaPortfolio = npaLoans.reduce(0.0) { $0 + $1.outstandingPrincipal + $1.outstandingInterest }
        
        let npaRatio = activePortfolio > 0 ? (npaPortfolio / activePortfolio) * 100.0 : 0.0
        
        // Fetch EMI schedules to calculate collection efficiency
        let emiItems: [EMIScheduleItem] = try await supabase.database
            .from("emi_schedule")
            .select()
            .execute()
            .value
            
        // Filter EMIs whose due dates are in the past or today
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: Date())
        
        let historicalDueEMIs = emiItems.filter { $0.dueDate <= todayStr }
        let totalDue = historicalDueEMIs.reduce(0.0) { $0 + $1.totalEmi }
        
        // Paid components
        let paidEMIs = emiItems.filter { $0.status == .paid }
        let totalCollected = paidEMIs.reduce(0.0) { $0 + $1.totalEmi }
        
        let collectionEfficiency = totalDue > 0 ? (totalCollected / totalDue) * 100.0 : 100.0
        
        return PortfolioReport(
            totalDisbursed: totalDisbursed,
            activePortfolio: activePortfolio,
            npaRatio: npaRatio,
            collectionEfficiency: collectionEfficiency,
            totalCollected: totalCollected,
            totalDue: totalDue
        )
    }
    
    /// Generates standard CSV export data for report downloads
    func generateCSVReport(loansList: [Loan]) -> String {
        var csvString = "Loan Number,Borrower ID,Principal Amount,Interest Rate,Status,Disbursed Date,Outstanding Principal,Overdue Days\n"
        
        for loan in loansList {
            let row = "\"\(loan.loanNumber ?? "")\",\"\(loan.borrowerId.uuidString)\",\(loan.principalAmount),\(loan.interestRate),\"\(loan.status.displayName)\",\"\(loan.disbursementDate ?? "")\",\(loan.outstandingPrincipal),\(loan.overdueDays)\n"
            csvString.append(row)
        }
        
        return csvString
    }
}
