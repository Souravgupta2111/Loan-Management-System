//
//  LoanDetailViewModel.swift
//  LMS Staff
//
//  ViewModel for fetching details, installments, payments, and logs for a specific loan account.
//

import Foundation
import Combine

@MainActor
class LoanDetailViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var emiSchedule: [EMIScheduleItem] = []
    @Published var payments: [Payment] = []
    @Published var auditLogs: [AuditLog] = []
    
    let loanWithDetails: LoanWithDetails
    
    init(loanWithDetails: LoanWithDetails) {
        self.loanWithDetails = loanWithDetails
    }
    
    func loadAllDetails() async {
        isLoading = true
        defer { isLoading = false }
        
        async let scheduleTask = try? LoanPortfolioService.shared.fetchEMISchedule(forLoanId: loanWithDetails.loan.id)
        async let paymentsTask = try? LoanPortfolioService.shared.fetchPayments(forLoanId: loanWithDetails.loan.id)
        async let logsTask = try? AuditService.shared.fetchAuditLogs(forRecordId: loanWithDetails.loan.id)
        
        let (fetchedSchedule, fetchedPayments, fetchedLogs) = await (scheduleTask, paymentsTask, logsTask)
        
        if let schedule = fetchedSchedule {
            self.emiSchedule = schedule
        }
        
        if let payments = fetchedPayments {
            self.payments = payments
        }
        
        if let logs = fetchedLogs {
            self.auditLogs = logs
        }
    }
}
