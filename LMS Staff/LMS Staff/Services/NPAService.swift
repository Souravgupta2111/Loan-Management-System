import Foundation
import Supabase

class NPAService {
    
    static let shared = NPAService()
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    func restructureLoan(
        loan: Loan,
        revisedRate: Double,
        revisedTenure: Int,
        waivedPenalty: Double,
        reason: String
    ) async throws {
        guard let currentUserId = supabase.currentUserId else {
            throw NSError(domain: "NPAService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unauthorized"])
        }
        
        let restructureId = UUID()
        
        let restructurePayload: [String: AnyEncodable] = [
            "id": AnyEncodable(restructureId),
            "original_loan_id": AnyEncodable(loan.id),
            "approved_by": AnyEncodable(currentUserId),
            "reason": AnyEncodable(reason),
            "waived_penalty": AnyEncodable(waivedPenalty),
            "revised_interest_rate": AnyEncodable(revisedRate),
            "revised_tenure_months": AnyEncodable(revisedTenure),
            "revised_first_emi_date": AnyEncodable(ISO8601DateFormatter().string(from: Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date())),
            "status": AnyEncodable(RestructureStatus.applied.rawValue)
        ]
        
        try await supabase.database
            .from("loan_restructures")
            .insert(restructurePayload)
            .execute()
            
        try await supabase.database
            .from("emi_schedule")
            .delete()
            .eq("loan_id", value: loan.id)
            .eq("status", value: EMIStatus.upcoming.rawValue) // Or unpaid
            .execute()
            
        let newPrincipal = loan.outstandingPrincipal
        let monthlyRate = (revisedRate / 12.0) / 100.0
        
        let emiAmount: Double
        if monthlyRate == 0 {
            emiAmount = newPrincipal / Double(revisedTenure)
        } else {
            let x = pow(1.0 + monthlyRate, Double(revisedTenure))
            emiAmount = newPrincipal * (monthlyRate * x) / (x - 1.0)
        }
        
        let totalPayable = emiAmount * Double(revisedTenure)
        
        try await supabase.database
            .from("loans")
            .update([
                "status": AnyEncodable(LoanStatus.restructured.rawValue),
                "interest_rate": AnyEncodable(revisedRate),
                "tenure_months": AnyEncodable(revisedTenure),
                "total_payable": AnyEncodable(totalPayable),
                "outstanding_interest": AnyEncodable(totalPayable - newPrincipal),
                "total_overdue": AnyEncodable(0.0),
                "overdue_days": AnyEncodable(0)
            ])
            .eq("id", value: loan.id)
            .execute()
            
        let calendar = Calendar.current
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        
        var balance = newPrincipal
        for i in 1...revisedTenure {
            let interestComp = balance * monthlyRate
            var principalComp = emiAmount - interestComp
            
            let currentOpeningBalance = balance
            balance -= principalComp
            if balance < 0 || i == revisedTenure {
                balance = 0.0
                principalComp = currentOpeningBalance // match exactly
            }
            
            guard let dueDate = calendar.date(byAdding: .month, value: i, to: Date()) else { continue }
            
            let emiPayload: [String: AnyEncodable] = [
                "id": AnyEncodable(UUID()),
                "loan_id": AnyEncodable(loan.id),
                "installment_number": AnyEncodable(i),
                "due_date": AnyEncodable(dateFormatter.string(from: dueDate)),
                "opening_balance": AnyEncodable(currentOpeningBalance),
                "principal_component": AnyEncodable(principalComp),
                "interest_component": AnyEncodable(interestComp),
                "total_emi": AnyEncodable(emiAmount),
                "penalty_amount": AnyEncodable(0.0),
                "penalty_days": AnyEncodable(0),
                "closing_balance": AnyEncodable(balance),
                "status": AnyEncodable(EMIStatus.upcoming.rawValue)
            ]
            
            try await supabase.database
                .from("emi_schedule")
                .insert(emiPayload)
                .execute()
        }
        
        try await NotificationService.shared.createNotification(
            userId: loan.borrowerId,
            title: "Loan Restructured Successfully",
            message: "Your loan terms have been revised: Tenure: \(revisedTenure) months, Interest Rate: \(revisedRate)%. Your new monthly EMI is INR \(String(format: "%.2f", emiAmount))."
        )
        
        try await AuditService.shared.logAction(
            action: "RESTRUCTURE_LOAN",
            tableName: "loans",
            recordId: loan.id,
            summary: "Restructured loan \(loan.id). Penalty waived: \(waivedPenalty). Revised rate: \(revisedRate)%"
        )
    }
    
    func writeOffLoan(loan: Loan, reason: String) async throws {
        try await supabase.database
            .from("loans")
            .update([
                "status": AnyEncodable(LoanStatus.writtenOff.rawValue),
                "outstanding_principal": AnyEncodable(0.0),
                "outstanding_interest": AnyEncodable(0.0),
                "total_overdue": AnyEncodable(0.0),
                "overdue_days": AnyEncodable(0)
            ])
            .eq("id", value: loan.id)
            .execute()
            
        try await supabase.database
            .from("emi_schedule")
            .update(["status": AnyEncodable(EMIStatus.writtenOff.rawValue)])
            .eq("loan_id", value: loan.id)
            .neq("status", value: EMIStatus.paid.rawValue)
            .execute()
            
        try await NotificationService.shared.createNotification(
            userId: loan.borrowerId,
            title: "Loan Account Written Off",
            message: "Your loan account \(loan.loanNumber ?? "") has been written off by the institution. Status: Written Off."
        )
        
        try await AuditService.shared.logAction(
            action: "WRITE_OFF_LOAN",
            tableName: "loans",
            recordId: loan.id,
            summary: "Wrote off loan \(loan.id). Reason: \(reason)"
        )
    }
    
    func escalateToAdmin(loan: Loan, reason: String) async throws {
        let admins: [AppUser] = try await supabase.database
            .from("users")
            .select()
            .eq("role", value: "admin")
            .execute()
            .value
            
        for admin in admins {
            try await NotificationService.shared.createNotification(
                userId: admin.id,
                title: "CRITICAL NPA ESCALATION",
                message: "Loan \(loan.loanNumber ?? "") has been escalated. Reason: \(reason)",
                type: .system,
                referenceId: loan.id,
                referenceType: "loans"
            )
        }
        
        try await AuditService.shared.logAction(
            action: "ESCALATE_NPA_TO_ADMIN",
            tableName: "loans",
            recordId: loan.id,
            summary: "Escalated loan \(loan.id) to Admin dashboard. Reason: \(reason)"
        )
    }
    
    func triggerNPASync() async throws {
        struct EmptyParams: Encodable {}
        try await supabase.database.rpc("update_npa_status", params: EmptyParams()).execute()
        
        try await sendDueDateReminders()
    }
    
    private func sendDueDateReminders() async throws {
        struct EMIReminder: Decodable {
            let due_date: String
            let total_emi: Double
            let loan_id: UUID
        }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        
        let today = Date()
        guard let in3Days = Calendar.current.date(byAdding: .day, value: 3, to: today) else { return }
        
        let targetDate = formatter.string(from: in3Days)
        
        let upcoming: [EMIReminder] = try await supabase.database
            .from("emi_schedule")
            .select("due_date, total_emi, loan_id")
            .eq("status", value: EMIStatus.upcoming.rawValue)
            .like("due_date", pattern: "\(targetDate)%")
            .execute()
            .value
            
        for emi in upcoming {
            struct LoanData: Decodable { let borrower_id: UUID; let loan_number: String? }
            if let loanData: LoanData = try? await supabase.database
                .from("loans")
                .select("borrower_id, loan_number")
                .eq("id", value: emi.loan_id)
                .single()
                .execute()
                .value {
                
                try? await NotificationService.shared.createNotification(
                    userId: loanData.borrower_id,
                    title: "EMI Due Reminder",
                    message: "Your EMI of INR \(emi.total_emi) for loan \(loanData.loan_number ?? "") is due on \(emi.due_date.prefix(10)). Please ensure sufficient balance.",
                    type: .paymentReminder,
                    referenceId: emi.loan_id,
                    referenceType: "loans"
                )
            }
        }
    }
}
