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
    @Published var messages: [Message] = []
    
    let loanWithDetails: LoanWithDetails
    
    init(loanWithDetails: LoanWithDetails) {
        self.loanWithDetails = loanWithDetails
    }
    
    func loadAllDetails() async {
        isLoading = true
        defer { isLoading = false }
        
        async let scheduleTask = try? LoanPortfolioService.shared.fetchEMISchedule(forLoanId: loanWithDetails.loan.id)
        async let paymentsTask = try? LoanPortfolioService.shared.fetchPayments(forLoanId: loanWithDetails.loan.id)
        async let loanLogsTask = try? AuditService.shared.fetchAuditLogs(forRecordId: loanWithDetails.loan.id)
        async let appLogsTask = try? AuditService.shared.fetchAuditLogs(forRecordId: loanWithDetails.loan.applicationId)
        async let messagesTask = try? MessageService.shared.fetchMessages(forApplicationId: loanWithDetails.loan.applicationId)
        
        let (fetchedSchedule, fetchedPayments, fetchedLoanLogs, fetchedAppLogs, fetchedMessages) = await (scheduleTask, paymentsTask, loanLogsTask, appLogsTask, messagesTask)
        
        if let schedule = fetchedSchedule {
            self.emiSchedule = schedule
        }
        
        if let payments = fetchedPayments {
            self.payments = payments
        }
        
        var combinedLogs: [AuditLog] = []
        if let loanLogs = fetchedLoanLogs {
            combinedLogs.append(contentsOf: loanLogs)
        }
        if let appLogs = fetchedAppLogs {
            combinedLogs.append(contentsOf: appLogs)
        }
        
        // Remove duplicates and sort by date (latest first)
        var uniqueLogs: [AuditLog] = []
        var seenIds = Set<UUID>()
        for log in combinedLogs {
            if !seenIds.contains(log.id) {
                seenIds.insert(log.id)
                uniqueLogs.append(log)
            }
        }
        self.auditLogs = uniqueLogs.sorted(by: { ($0.createdAt ?? Date()) > ($1.createdAt ?? Date()) })
        
        if let msgs = fetchedMessages {
            self.messages = msgs
        }
    }
}
