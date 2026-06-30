//
//  DisbursementViewModel.swift
//  LMS Staff
//
//  ViewModel for managing the queue of approved applications waiting for bank detail verification and disbursement.
//

import Foundation
import Combine
import Supabase

@MainActor
class DisbursementViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var pendingDisbursements: [ApplicationWithBorrower] = []
    @Published var approvedRates: [UUID: Double] = [:]
    @Published var verifiedBankDetails: IFSCResponse?
    @Published var isVerifyingIFSC: Bool = false
    @Published var ifscError: String?
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let appService = ApplicationService.shared
    private let disbursementService = DisbursementService.shared
    
    init() {}
    
    func loadPendingDisbursements() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetched = try await appService.fetchAllApplications()
            // Pending disbursement = status is approved
            self.pendingDisbursements = fetched.filter { $0.application.status == .approved }
            
            struct ApprovalHistoryRate: Decodable {
                let application_id: UUID
                let approved_interest_rate: Double?
            }
            let rateResults: [ApprovalHistoryRate] = try await SupabaseManager.shared.database
                .from("approval_history")
                .select("application_id, approved_interest_rate")
                .eq("action", value: "approve")
                .execute()
                .value
            
            var newRates: [UUID: Double] = [:]
            for row in rateResults {
                if let rate = row.approved_interest_rate {
                    newRates[row.application_id] = rate
                }
            }
            self.approvedRates = newRates
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func verifyIFSC(_ ifsc: String) async {
        isVerifyingIFSC = true
        ifscError = nil
        verifiedBankDetails = nil
        
        do {
            let response = try await disbursementService.validateIFSC(ifsc)
            self.verifiedBankDetails = response
        } catch {
            self.ifscError = error.localizedDescription
        }
        
        isVerifyingIFSC = false
    }
    
    func processDisbursement(
        application: LoanApplication,
        bankAccount: String,
        ifscCode: String,
        interestRate: Double,
        interestType: InterestType,
        processingFeePct: Double
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await disbursementService.disburseLoan(
                application: application,
                bankAccount: bankAccount,
                ifscCode: ifscCode,
                approvedAmount: application.requestedAmount,
                approvedTenure: application.requestedTenureMonths,
                interestRate: interestRate,
                interestType: interestType,
                processingFeePct: processingFeePct
            )
            
            // Reload list
            await loadPendingDisbursements()
            isLoading = false
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
}
