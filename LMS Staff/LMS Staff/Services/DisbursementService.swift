//
//  DisbursementService.swift
//  LMS Staff
//
//  Service for bank IFSC verification, loan creation, and EMI amortization generation.
//

import Foundation
import Supabase

struct IFSCResponse: Decodable {
    let branch: String
    let bank: String
    let city: String
    let state: String
    let center: String
    
    enum CodingKeys: String, CodingKey {
        case branch = "BRANCH"
        case bank = "BANK"
        case city = "CITY"
        case state = "STATE"
        case center = "CENTRE"
    }
}

class DisbursementService {
    
    static let shared = DisbursementService()
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    /// Validates IFSC code using the Razorpay IFSC API.
    /// Returns bank and branch name if valid.
    func validateIFSC(_ ifsc: String) async throws -> IFSCResponse {
        let cleanIfsc = ifsc.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard cleanIfsc.count == 11 else {
            throw NSError(domain: "DisbursementService", code: 400, userInfo: [NSLocalizedDescriptionKey: "IFSC must be exactly 11 characters long."])
        }
        
        guard let url = URL(string: "https://ifsc.razorpay.com/\(cleanIfsc)") else {
            throw NSError(domain: "DisbursementService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid IFSC format URL."])
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "DisbursementService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to connect to verification server."])
        }
        
        if httpResponse.statusCode == 404 {
            throw NSError(domain: "DisbursementService", code: 404, userInfo: [NSLocalizedDescriptionKey: "IFSC code not found / invalid."])
        } else if httpResponse.statusCode != 200 {
            throw NSError(domain: "DisbursementService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error during bank verification (\(httpResponse.statusCode))."])
        }
        
        let bankDetails = try JSONDecoder().decode(IFSCResponse.self, from: data)
        return bankDetails
    }
    
    /// Processes disbursement: creates loan record, generates EMI schedule, updates application status
    func disburseLoan(
        application: LoanApplication,
        bankAccount: String,
        ifscCode: String,
        approvedAmount: Double,
        approvedTenure: Int,
        interestRate: Double,
        interestType: InterestType,
        processingFeePct: Double
    ) async throws -> Loan {
        guard let userId = supabase.currentUserId else {
            throw NSError(domain: "DisbursementService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unauthorized"])
        }
        
        // Fetch the staff profile ID because `loans.disbursed_by` references `staff_profiles.id`, not `users.id`
        struct StaffIdResult: Decodable { let id: UUID }
        let staffResult: StaffIdResult = try await supabase.database
            .from("staff_profiles")
            .select("id")
            .eq("user_id", value: userId)
            .single()
            .execute()
            .value
            
        let staffId = staffResult.id
        
        // 1. Calculate values
        let processingFee = approvedAmount * (processingFeePct / 100.0)
        let monthlyRate = (interestRate / 12.0) / 100.0
        
        var totalPayable: Double = 0.0
        var emiAmount: Double = 0.0
        
        if interestType == .fixed {
            let totalInterest = approvedAmount * (interestRate / 100.0) * (Double(approvedTenure) / 12.0)
            totalPayable = approvedAmount + totalInterest
            emiAmount = totalPayable / Double(approvedTenure)
        } else { // reducing
            if monthlyRate == 0 {
                emiAmount = approvedAmount / Double(approvedTenure)
                totalPayable = approvedAmount
            } else {
                let x = pow(1.0 + monthlyRate, Double(approvedTenure))
                emiAmount = approvedAmount * (monthlyRate * x) / (x - 1.0)
                totalPayable = emiAmount * Double(approvedTenure)
            }
        }
        
        let loanId = UUID()
        // Derive human-readable identifiers from the (globally unique) loan UUID
        // instead of Int.random, which had a real collision risk. The UUID hex
        // guarantees uniqueness; a date prefix keeps it readable/sortable.
        let idHex = loanId.uuidString.replacingOccurrences(of: "-", with: "").uppercased()
        let disbursementDate = Date()
        let ymFormatter = DateFormatter()
        ymFormatter.dateFormat = "yyyyMM"
        let loanNumber = "LMS-\(ymFormatter.string(from: disbursementDate))-\(idHex.prefix(8))"
        let disbursementReference = "TXN-\(idHex.prefix(12))"
        let calendar = Calendar.current
        
        // First EMI is due next month
        guard let firstEmiDate = calendar.date(byAdding: .month, value: 1, to: disbursementDate) else {
            throw NSError(domain: "DisbursementService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Date calculation error"])
        }
        
        // Maturity Date
        guard let maturityDate = calendar.date(byAdding: .month, value: approvedTenure, to: disbursementDate) else {
            throw NSError(domain: "DisbursementService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Date calculation error"])
        }
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        
        let disbursementDateStr = dateFormatter.string(from: disbursementDate)
        let firstEmiDateStr = dateFormatter.string(from: firstEmiDate)
        let maturityDateStr = dateFormatter.string(from: maturityDate)
        
        // 2. Insert Loan Record
        var loanPayload: [String: AnyEncodable] = [
            "id": AnyEncodable(loanId),
            "application_id": AnyEncodable(application.id),
            "borrower_id": AnyEncodable(application.borrowerId),
            "loan_product_id": AnyEncodable(application.loanProductId),
            "disbursed_by": AnyEncodable(staffId),
            "loan_number": AnyEncodable(loanNumber),
            "principal_amount": AnyEncodable(approvedAmount),
            "interest_rate": AnyEncodable(interestRate),
            "interest_type": AnyEncodable(interestType.rawValue),
            "spread": AnyEncodable(2.0), // constant bank markup snapshot
            "base_rate_at_disbursement": AnyEncodable(interestRate - 2.0),
            "current_base_rate": AnyEncodable(interestRate - 2.0),
            "tenure_months": AnyEncodable(approvedTenure),
            "processing_fee": AnyEncodable(processingFee),
            "total_payable": AnyEncodable(totalPayable),
            "disbursement_date": AnyEncodable(disbursementDateStr),
            "first_emi_date": AnyEncodable(firstEmiDateStr),
            "maturity_date": AnyEncodable(maturityDateStr),
            "status": AnyEncodable(LoanStatus.active.rawValue),
            "outstanding_principal": AnyEncodable(approvedAmount),
            "outstanding_interest": AnyEncodable(totalPayable - approvedAmount),
            "total_overdue": AnyEncodable(0.0),
            "overdue_days": AnyEncodable(0),
            "bank_account_number": AnyEncodable(bankAccount),
            "ifsc_code": AnyEncodable(ifscCode),
            "disbursement_reference": AnyEncodable(disbursementReference),
            "repayment_mode": AnyEncodable(RepaymentMode.autoDebit.rawValue)
        ]
        
        if let branchId = application.branchId {
            loanPayload["branch_id"] = AnyEncodable(branchId)
        }
        
        let newLoan: Loan = try await supabase.database
            .from("loans")
            .insert(loanPayload)
            .select()
            .single()
            .execute()
            .value
            
        // 3. Generate and Insert EMI Schedule Items
        var balance = approvedAmount
        var emiPayloads: [[String: AnyEncodable]] = []
        
        for i in 1...approvedTenure {
            var interestComp = 0.0
            var principalComp = 0.0
            
            if interestType == .fixed {
                interestComp = (approvedAmount * (interestRate / 100.0) * (Double(approvedTenure) / 12.0)) / Double(approvedTenure)
                principalComp = emiAmount - interestComp
            } else { // reducing
                interestComp = balance * monthlyRate
                principalComp = emiAmount - interestComp
            }
            
            let currentOpeningBalance = balance
            balance -= principalComp
            if balance < 0 || i == approvedTenure {
                balance = 0.0
            }
            
            guard let dueDate = calendar.date(byAdding: .month, value: i, to: disbursementDate) else { continue }
            
            let emiPayload: [String: AnyEncodable] = [
                "id": AnyEncodable(UUID()),
                "loan_id": AnyEncodable(loanId),
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
            
            emiPayloads.append(emiPayload)
        }
        
        if !emiPayloads.isEmpty {
            try await supabase.database
                .from("emi_schedule")
                .insert(emiPayloads)
                .execute()
        }
        
        // 4. Update Application Status to disbursed
        try await ApplicationService.shared.updateStatus(applicationId: application.id, status: .disbursed)
        
        // 5. Notify Borrower
        try await NotificationService.shared.createNotification(
            userId: application.borrowerId,
            title: "Loan Disbursed",
            message: "Your loan funds have been successfully disbursed to your bank account.",
            type: .loanUpdate,
            referenceId: application.id,
            referenceType: "loan_applications"
        )
        
        return newLoan
    }
}
