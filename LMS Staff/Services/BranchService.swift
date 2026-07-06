//
//  BranchService.swift
//  LMS Staff
//
//  Service for branch CRUD, pincode management, staff roster,
//  loan metrics, and proximity-based loan assignment.
//

import Foundation
import Supabase

// MARK: - Branch Metrics Model

struct BranchMetrics {
    let totalLoans: Int
    let activeLoans: Int
    let npaLoans: Int
    let closedLoans: Int
    let totalDisbursed: Double
    let activePortfolio: Double
    let npaAmount: Double
    let npaRatio: Double
    let totalCollected: Double
    let totalDue: Double
    let collectionEfficiency: Double
}

// MARK: - Branch Service

class BranchService {

    static let shared = BranchService()
    private let supabase = SupabaseManager.shared

    private init() {}

    // MARK: - Branch CRUD

    /// Fetches all branches ordered by name
    func fetchBranches() async throws -> [Branch] {
        let branches: [Branch] = try await supabase.database
            .from("branches")
            .select()
            .order("name")
            .execute()
            .value
        return branches
    }

    /// Creates a new branch and auto-inserts its pincode into branch_pincodes
    func createBranch(
        name: String,
        code: String,
        address: String?,
        city: String?,
        state: String?,
        pincode: String?,
        ifscPrefix: String?
    ) async throws -> Branch {
        var payload: [String: AnyEncodable] = [
            "name": AnyEncodable(name),
            "code": AnyEncodable(code),
            "is_active": AnyEncodable(true)
        ]

        if let address = address, !address.isEmpty {
            payload["address"] = AnyEncodable(address)
        }
        if let city = city, !city.isEmpty {
            payload["city"] = AnyEncodable(city)
        }
        if let state = state, !state.isEmpty {
            payload["state"] = AnyEncodable(state)
        }
        if let pincode = pincode, !pincode.isEmpty {
            payload["pincode"] = AnyEncodable(pincode)
        }
        if let ifscPrefix = ifscPrefix, !ifscPrefix.isEmpty {
            payload["ifsc_prefix"] = AnyEncodable(ifscPrefix)
        }

        let branch: Branch = try await supabase.database
            .from("branches")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        // Auto-insert the branch pincode into branch_pincodes if provided
        if let pincode = pincode, !pincode.isEmpty {
            try? await addPincode(branchId: branch.id, pincode: pincode)
        }

        try await AuditService.shared.logAction(
            action: "CREATE_BRANCH",
            tableName: "branches",
            recordId: branch.id,
            summary: "Created branch \(name) (\(code))"
        )

        return branch
    }

    /// Updates branch details
    func updateBranch(
        branchId: UUID,
        name: String,
        address: String?,
        city: String?,
        state: String?,
        pincode: String?,
        ifscPrefix: String?
    ) async throws {
        let payload: [String: AnyEncodable] = [
            "name": AnyEncodable(name),
            "address": AnyEncodable(address),
            "city": AnyEncodable(city),
            "state": AnyEncodable(state),
            "pincode": AnyEncodable(pincode),
            "ifsc_prefix": AnyEncodable(ifscPrefix),
            "updated_at": AnyEncodable(ISO8601DateFormatter().string(from: Date()))
        ]

        try await supabase.database
            .from("branches")
            .update(payload)
            .eq("id", value: branchId)
            .execute()

        try await AuditService.shared.logAction(
            action: "UPDATE_BRANCH",
            tableName: "branches",
            recordId: branchId,
            summary: "Updated branch details for \(name)"
        )
    }

    /// Toggles branch active/inactive status
    func toggleBranchActive(branchId: UUID, isActive: Bool) async throws {
        try await supabase.database
            .from("branches")
            .update(["is_active": AnyEncodable(isActive)])
            .eq("id", value: branchId)
            .execute()

        try await AuditService.shared.logAction(
            action: isActive ? "ACTIVATE_BRANCH" : "DEACTIVATE_BRANCH",
            tableName: "branches",
            recordId: branchId,
            summary: "\(isActive ? "Activated" : "Deactivated") branch \(branchId)"
        )
    }

    // MARK: - Manager Assignment

    /// Assigns a manager to a branch (updates branches.manager_id and staff_profiles.branch_id)
    func assignManager(branchId: UUID, managerId: UUID) async throws {
        // Update the branch's manager_id
        try await supabase.database
            .from("branches")
            .update(["manager_id": AnyEncodable(managerId)])
            .eq("id", value: branchId)
            .execute()

        // Also update the manager's staff_profile to point to this branch
        try await supabase.database
            .from("staff_profiles")
            .update(["branch_id": AnyEncodable(branchId)])
            .eq("user_id", value: managerId)
            .execute()

        try await AuditService.shared.logAction(
            action: "ASSIGN_BRANCH_MANAGER",
            tableName: "branches",
            recordId: branchId,
            summary: "Assigned manager \(managerId) to branch \(branchId)"
        )
    }

    /// Removes the manager from a branch
    func removeManager(branchId: UUID) async throws {
        try await supabase.database
            .from("branches")
            .update(["manager_id": AnyEncodable(Optional<String>.none)])
            .eq("id", value: branchId)
            .execute()

        try await AuditService.shared.logAction(
            action: "REMOVE_BRANCH_MANAGER",
            tableName: "branches",
            recordId: branchId,
            summary: "Removed manager from branch \(branchId)"
        )
    }

    // MARK: - Officer Assignment

    /// Assigns a loan officer to a branch by updating their staff_profiles.branch_id
    func assignOfficer(branchId: UUID, officerUserId: UUID) async throws {
        try await supabase.database
            .from("staff_profiles")
            .update(["branch_id": AnyEncodable(branchId)])
            .eq("user_id", value: officerUserId)
            .execute()

        try await AuditService.shared.logAction(
            action: "ASSIGN_OFFICER_TO_BRANCH",
            tableName: "staff_profiles",
            recordId: nil,
            summary: "Assigned officer \(officerUserId) to branch \(branchId)"
        )
    }

    /// Removes an officer from a branch (sets branch_id to nil)
    func removeOfficerFromBranch(officerUserId: UUID) async throws {
        try await supabase.database
            .from("staff_profiles")
            .update(["branch_id": AnyEncodable(Optional<String>.none)])
            .eq("user_id", value: officerUserId)
            .execute()
    }

    // MARK: - Pincode Management

    /// Fetches all pincodes assigned to a branch
    func fetchBranchPincodes(branchId: UUID) async throws -> [BranchPincode] {
        let pincodes: [BranchPincode] = try await supabase.database
            .from("branch_pincodes")
            .select()
            .eq("branch_id", value: branchId)
            .order("pincode")
            .execute()
            .value
        return pincodes
    }

    /// Adds a pincode to a branch
    func addPincode(branchId: UUID, pincode: String) async throws {
        let payload: [String: AnyEncodable] = [
            "branch_id": AnyEncodable(branchId),
            "pincode": AnyEncodable(pincode)
        ]

        try await supabase.database
            .from("branch_pincodes")
            .insert(payload)
            .execute()
    }

    /// Removes a pincode mapping
    func removePincode(id: UUID) async throws {
        try await supabase.database
            .from("branch_pincodes")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Branch Staff Roster

    /// Fetches all staff members assigned to a branch (joins staff_profiles + users)
    func fetchBranchStaff(branchId: UUID) async throws -> [StaffWithUser] {
        let staffProfiles: [StaffProfile] = try await supabase.database
            .from("staff_profiles")
            .select()
            .eq("branch_id", value: branchId)
            .execute()
            .value

        if staffProfiles.isEmpty { return [] }

        let userIds = staffProfiles.map { $0.userId }
        let users: [AppUser] = try await supabase.database
            .from("users")
            .select()
            .in("id", values: userIds)
            .execute()
            .value

        let usersMap = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })

        return staffProfiles.compactMap { profile in
            if let user = usersMap[profile.userId] {
                return StaffWithUser(staff: profile, user: user)
            }
            return nil
        }
    }

    // MARK: - Branch Loan Metrics

    /// Fetches all loans belonging to a branch
    func fetchBranchLoans(branchId: UUID) async throws -> [Loan] {
        let loans: [Loan] = try await supabase.database
            .from("loans")
            .select()
            .eq("branch_id", value: branchId)
            .execute()
            .value
        return loans
    }

    /// Computes loan metrics for a specific branch
    func fetchBranchMetrics(branchId: UUID) async throws -> BranchMetrics {
        let loans = try await fetchBranchLoans(branchId: branchId)

        let activeLoans = loans.filter { $0.status == .active || $0.status == .restructured }
        let npaLoans = loans.filter { $0.status == .npa }
        let closedLoans = loans.filter { $0.status == .closed }

        let totalDisbursed = loans.reduce(0.0) { $0 + $1.principalAmount }
        let activePortfolio = activeLoans.reduce(0.0) { $0 + $1.outstandingPrincipal + $1.outstandingInterest }
        let npaAmount = npaLoans.reduce(0.0) { $0 + $1.outstandingPrincipal + $1.outstandingInterest }
        let npaRatio = (activePortfolio + npaAmount) > 0 ? (npaAmount / (activePortfolio + npaAmount)) * 100.0 : 0.0

        // Fetch EMI schedules for branch loans to calculate collection efficiency
        let loanIds = loans.map { $0.id }
        var totalCollected = 0.0
        var totalDue = 0.0

        if !loanIds.isEmpty {
            let emiItems: [EMIScheduleItem] = try await supabase.database
                .from("emi_schedule")
                .select()
                .in("loan_id", values: loanIds)
                .execute()
                .value

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let todayStr = formatter.string(from: Date())

            let historicalDue = emiItems.filter { $0.dueDate <= todayStr }
            totalDue = historicalDue.reduce(0.0) { $0 + $1.totalEmi }

            let paidEMIs = emiItems.filter { $0.status == .paid }
            totalCollected = paidEMIs.reduce(0.0) { $0 + $1.totalEmi }
        }

        let collectionEfficiency = totalDue > 0 ? (totalCollected / totalDue) * 100.0 : 100.0

        return BranchMetrics(
            totalLoans: loans.count,
            activeLoans: activeLoans.count,
            npaLoans: npaLoans.count,
            closedLoans: closedLoans.count,
            totalDisbursed: totalDisbursed,
            activePortfolio: activePortfolio,
            npaAmount: npaAmount,
            npaRatio: npaRatio,
            totalCollected: totalCollected,
            totalDue: totalDue,
            collectionEfficiency: collectionEfficiency
        )
    }

    // MARK: - Proximity-Based Loan Assignment

    /// Finds the matching branch for a borrower's pincode using the DB RPC
    func findBranchForPincode(pincode: String) async throws -> UUID {
        struct PincodeParam: Encodable {
            let p_pincode: String
        }

        let branchId: UUID = try await supabase.database
            .rpc("find_branch_for_pincode", params: PincodeParam(p_pincode: pincode))
            .execute()
            .value

        return branchId
    }

    /// Auto-assigns unassigned loan applications to branches based on borrower pincode
    func autoAssignUnassignedApplications() async throws -> Int {
        // Fetch applications without a branch
        let applications: [LoanApplication] = try await supabase.database
            .from("loan_applications")
            .select()
            .is("branch_id", value: nil)
            .execute()
            .value

        if applications.isEmpty { return 0 }

        var assignedCount = 0

        for app in applications {
            // Get borrower's pincode from profile
            let profile: BorrowerProfile? = try? await supabase.database
                .from("borrower_profiles")
                .select()
                .eq("user_id", value: app.borrowerId)
                .single()
                .execute()
                .value

            guard let borrowerPincode = profile?.pincode, !borrowerPincode.isEmpty else { continue }

            // Find matching branch
            let branchId = try await findBranchForPincode(pincode: borrowerPincode)

            // Update the application
            try await supabase.database
                .from("loan_applications")
                .update(["branch_id": AnyEncodable(branchId)])
                .eq("id", value: app.id)
                .execute()

            assignedCount += 1
        }

        if assignedCount > 0 {
            try await AuditService.shared.logAction(
                action: "AUTO_ASSIGN_BRANCHES",
                tableName: "loan_applications",
                recordId: nil,
                summary: "Auto-assigned \(assignedCount) application(s) to branches by pincode proximity"
            )
        }

        return assignedCount
    }

    // MARK: - Fetch Unassigned Staff

    /// Fetches all managers not currently assigned as manager of any branch
    func fetchAvailableManagers() async throws -> [StaffWithUser] {
        let allStaff = try await StaffManagementService.shared.fetchStaff()
        let branches = try await fetchBranches()
        let assignedManagerIds = Set(branches.compactMap { $0.managerId })

        return allStaff.filter { $0.user.role == .manager && !assignedManagerIds.contains($0.user.id) }
    }

    /// Fetches all officers (can be assigned to any branch via staff_profiles.branch_id)
    func fetchAvailableOfficers(excludingBranchId: UUID) async throws -> [StaffWithUser] {
        let allStaff = try await StaffManagementService.shared.fetchStaff()

        // Officers not assigned to this branch (or unassigned)
        return allStaff.filter { staffWithUser in
            staffWithUser.user.role == .officer &&
            staffWithUser.staff.branchId != excludingBranchId
        }
    }
}
