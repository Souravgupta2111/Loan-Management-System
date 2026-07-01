//
//  ManagerDashboardViewModel.swift
//  LMS Staff
//
//  ViewModel for branch managers, managing approvals and key performance indicators.
//

import Foundation
import Combine
import Supabase

@MainActor
class ManagerDashboardViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var recommendedApplications: [ApplicationWithBorrower] = []
    @Published var activeLoansList: [LoanWithDetails] = []
    @Published var activeLoansCount: Int = 0
    @Published var totalDisbursed: Double = 0.0
    @Published var npaRatio: Double = 0.0
    @Published var collectionEfficiency: Double = 100.0
    
    @Published var availableOfficers: [StaffWithUser] = []
    
    @Published var isLoading: Bool = false
    @Published var isActionLoading: Bool = false
    @Published var errorMessage: String?
    
    private let appService = ApplicationService.shared
    private let reportService = ReportService.shared
    
    init() {}
    
    /// Loads portfolio aggregation dashboard numbers and recommendation queues
    func loadDashboard() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 1. Fetch consolidated reports metrics
            let report = try await reportService.compileConsolidatedReport()
            self.totalDisbursed = report.totalDisbursed
            self.npaRatio = report.npaRatio
            self.collectionEfficiency = report.collectionEfficiency
            
            // Fetch total active loans
            let activeLoans = try await LoanPortfolioService.shared.fetchLoans()
            self.activeLoansList = activeLoans.filter { $0.loan.status == .active || $0.loan.status == .restructured || $0.loan.status == .npa }
            self.activeLoansCount = self.activeLoansList.count
            
            // 2. Fetch applications that are recommended (under_review status)
            let allApplications = try await appService.fetchAllApplications()
            self.recommendedApplications = allApplications.filter { $0.application.status == .underReview }
            
            // 3. Fetch officers
            let allStaff = try await StaffManagementService.shared.fetchStaff()
            self.availableOfficers = allStaff.filter { $0.user.role == .officer }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func approveApplication(applicationId: UUID, approvedAmount: Double, tenureMonths: Int, interestRate: Double) async -> Bool {
        guard !isActionLoading else { return false }
        isActionLoading = true
        defer { isActionLoading = false }
        
        do {
            // Under the hood, updates the status to approved, changes rates in DB or saves snapshot
            // In the DB flow: Manager approves and sets terms. The terms are saved back to the loan application record.
            // Let's see: we update the requested amount/tenure to the APPROVED values, and set status = approved.
            try await SupabaseManager.shared.database
                .from("loan_applications")
                .update([
                    "requested_amount": AnyEncodable(approvedAmount),
                    "requested_tenure_months": AnyEncodable(tenureMonths),
                    "status": AnyEncodable(ApplicationStatus.approved.rawValue),
                    "decided_at": AnyEncodable(ISO8601DateFormatter().string(from: Date()))
                ])
                .eq("id", value: applicationId)
                .execute()
                
            // Record history
            try await appService.addApprovalHistory(
                applicationId: applicationId,
                action: "approve",
                toStatus: "approved",
                remarks: "Approved terms: INR \(approvedAmount), Rate: \(interestRate)%, Tenure: \(tenureMonths) months.",
                approvedAmount: approvedAmount,
                approvedTenure: tenureMonths,
                approvedRate: interestRate
            )
            
            await loadDashboard()
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
    
    func rejectApplication(applicationId: UUID, reason: String) async -> Bool {
        guard !isActionLoading else { return false }
        isActionLoading = true
        defer { isActionLoading = false }
        
        do {
            try await appService.updateStatus(applicationId: applicationId, status: .rejected, reason: reason)
            await loadDashboard()
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
    
    func sendBackApplication(applicationId: UUID, remarks: String) async -> Bool {
        do {
            try await appService.updateStatus(applicationId: applicationId, status: .sentBack, reason: remarks)
            await loadDashboard()
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
    
    func reassignOfficer(applicationId: UUID, newOfficerId: UUID) async -> Bool {
        do {
            try await SupabaseManager.shared.database
                .from("loan_applications")
                .update(["assigned_officer_id": AnyEncodable(newOfficerId)])
                .eq("id", value: applicationId)
                .execute()
            
            try await AuditService.shared.logAction(
                action: "REASSIGN",
                tableName: "loan_applications",
                recordId: applicationId,
                summary: "Reassigned to officer \(newOfficerId.uuidString)"
            )
            
            await loadDashboard()
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
}
