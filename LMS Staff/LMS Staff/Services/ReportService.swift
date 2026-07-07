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

struct CollectionTrendItem: Identifiable {
    let id = UUID()
    let month: String
    let efficiency: Double
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
            
        // Fetch all confirmed payments
        struct PaymentFetch: Decodable {
            let emi_id: UUID?
            let amount_paid: Double
            let status: String
        }
        
        let payments: [PaymentFetch] = (try? await supabase.database
            .from("payments")
            .select("emi_id, amount_paid, status")
            .eq("status", value: "confirmed")
            .execute()
            .value) ?? []
            
        var paidMap: [UUID: Double] = [:]
        for payment in payments {
            if let emiId = payment.emi_id {
                paidMap[emiId, default: 0.0] += payment.amount_paid
            }
        }
            
        // Filter EMIs whose due dates are in the past or today
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: Date())
        
        let historicalDueEMIs = emiItems.filter { $0.dueDate <= todayStr }
        let totalDue = historicalDueEMIs.reduce(0.0) { $0 + $1.totalEmi }
        
        // Paid components
        var totalCollected = 0.0
        for emi in emiItems {
            if let collectedAmount = paidMap[emi.id] {
                totalCollected += collectedAmount
            } else if emi.status == .paid {
                totalCollected += emi.totalEmi
            }
        }
        
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
    
    /// Compiles live historical collection efficiency trends (by month) for graphs
    func fetchCollectionTrends() async throws -> [CollectionTrendItem] {
        let emiItems: [EMIScheduleItem] = try await supabase.database
            .from("emi_schedule")
            .select()
            .execute()
            .value
            
        // Fetch all confirmed payments
        struct PaymentFetch: Decodable {
            let emi_id: UUID?
            let amount_paid: Double
            let status: String
        }
        
        let payments: [PaymentFetch] = (try? await supabase.database
            .from("payments")
            .select("emi_id, amount_paid, status")
            .eq("status", value: "confirmed")
            .execute()
            .value) ?? []
            
        var paidMap: [UUID: Double] = [:]
        for payment in payments {
            if let emiId = payment.emi_id {
                paidMap[emiId, default: 0.0] += payment.amount_paid
            }
        }
            
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: Date())
        
        // Include any EMI that is historically due OR has a payment
        let historicalEMIs = emiItems.filter { $0.dueDate <= todayStr || paidMap[$0.id] != nil }
        
        // Group by YYYY-MM
        var monthlyTotals: [String: (due: Double, collected: Double)] = [:]
        
        for emi in historicalEMIs {
            let prefix = String(emi.dueDate.prefix(7)) // "2026-06"
            var current = monthlyTotals[prefix] ?? (due: 0.0, collected: 0.0)
            
            // Only add to due if the EMI is actually due in the past or today
            if emi.dueDate <= todayStr {
                current.due += emi.totalEmi
            }
            
            if let collectedAmount = paidMap[emi.id] {
                current.collected += collectedAmount
            } else if emi.status == .paid {
                current.collected += emi.totalEmi
            }
            
            monthlyTotals[prefix] = current
        }
        
        var trends: [CollectionTrendItem] = []
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "yyyy-MM"
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM yy"
        
        let sortedKeys = monthlyTotals.keys.sorted()
        
        for key in sortedKeys {
            if let totals = monthlyTotals[key] {
                let efficiency = totals.due > 0 ? (totals.collected / totals.due) * 100.0 : 100.0
                
                if let date = monthFormatter.date(from: key) {
                    let displayMonth = displayFormatter.string(from: date)
                    trends.append(CollectionTrendItem(month: displayMonth, efficiency: efficiency))
                } else {
                    trends.append(CollectionTrendItem(month: key, efficiency: efficiency))
                }
            }
        }
        
        // Return last 12 months if there are many
        if trends.count > 12 {
            return Array(trends.suffix(12))
        }
        return trends
    }
}
