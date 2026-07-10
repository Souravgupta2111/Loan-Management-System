import Foundation
import Supabase

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

class BranchService {

    static let shared = BranchService()
    private let supabase = SupabaseManager.shared

    private init() {}

    func fetchBranches() async throws -> [Branch] {
        let branches: [Branch] = try await supabase.database
            .from("branches")
            .select()
            .order("name")
            .execute()
            .value
        return branches
    }

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

    func assignManager(branchId: UUID, managerId: UUID) async throws {
        try await supabase.database
            .from("branches")
            .update(["manager_id": AnyEncodable(managerId)])
            .eq("id", value: branchId)
            .execute()

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

    func assignOfficer(branchId: UUID, officerUserId: UUID) async throws {
        try await supabase.database
            .from("staff_profiles")
            .update(["branch_id": AnyEncodable(branchId)])
            .eq("user_id", value: officerUserId)
            .execute()

        struct ProfileIdRow: Decodable { let id: UUID }
        if let profile: ProfileIdRow = try? await supabase.database
            .from("staff_profiles")
            .select("id")
            .eq("user_id", value: officerUserId)
            .single()
            .execute()
            .value {
            try await reassignBranchForOfficer(profileId: profile.id, branchId: branchId)
        }

        try await AuditService.shared.logAction(
            action: "ASSIGN_OFFICER_TO_BRANCH",
            tableName: "staff_profiles",
            recordId: nil,
            summary: "Assigned officer \(officerUserId) to branch \(branchId)"
        )
    }

    /// Moves every application (and its loans) handled by this officer to the
    /// given branch, so branch-level loan metrics reflect the officer's branch.
    private func reassignBranchForOfficer(profileId: UUID, branchId: UUID) async throws {
        struct AppIdRow: Decodable { let id: UUID }
        let apps: [AppIdRow] = try await supabase.database
            .from("loan_applications")
            .select("id")
            .eq("assigned_officer_id", value: profileId)
            .execute()
            .value

        let appIds = apps.map { $0.id }
        guard !appIds.isEmpty else { return }

        try await supabase.database
            .from("loan_applications")
            .update(["branch_id": AnyEncodable(branchId)])
            .in("id", values: appIds)
            .execute()

        try await supabase.database
            .from("loans")
            .update(["branch_id": AnyEncodable(branchId)])
            .in("application_id", values: appIds)
            .execute()
    }

    /// Repairs stale branch assignments: re-tags every application and loan to
    /// the branch of its assigned officer. Idempotent — only rows that differ
    /// are written, so repeat runs are no-ops. Runs automatically when the admin
    /// opens Branch Management.
    func syncLoanBranchesToOfficers() async throws {
        struct ProfileRow: Decodable { let id: UUID; let branch_id: UUID? }
        let profiles: [ProfileRow] = try await supabase.database
            .from("staff_profiles")
            .select("id, branch_id")
            .execute()
            .value

        var officerBranch: [UUID: UUID] = [:]
        for p in profiles {
            if let b = p.branch_id { officerBranch[p.id] = b }
        }
        guard !officerBranch.isEmpty else { return }

        struct AppRow: Decodable { let id: UUID; let assigned_officer_id: UUID?; let branch_id: UUID? }
        let apps: [AppRow] = try await supabase.database
            .from("loan_applications")
            .select("id, assigned_officer_id, branch_id")
            .execute()
            .value

        var appTargetBranch: [UUID: UUID] = [:]
        var appsByBranch: [UUID: [UUID]] = [:]
        for app in apps {
            guard let officer = app.assigned_officer_id,
                  let target = officerBranch[officer] else { continue }
            appTargetBranch[app.id] = target
            if app.branch_id != target {
                appsByBranch[target, default: []].append(app.id)
            }
        }

        for (branch, ids) in appsByBranch {
            try await supabase.database
                .from("loan_applications")
                .update(["branch_id": AnyEncodable(branch)])
                .in("id", values: ids)
                .execute()
        }

        struct LoanRow: Decodable { let id: UUID; let application_id: UUID; let branch_id: UUID? }
        let loans: [LoanRow] = try await supabase.database
            .from("loans")
            .select("id, application_id, branch_id")
            .execute()
            .value

        var loansByBranch: [UUID: [UUID]] = [:]
        for loan in loans {
            guard let target = appTargetBranch[loan.application_id] else { continue }
            if loan.branch_id != target {
                loansByBranch[target, default: []].append(loan.id)
            }
        }

        for (branch, ids) in loansByBranch {
            try await supabase.database
                .from("loans")
                .update(["branch_id": AnyEncodable(branch)])
                .in("id", values: ids)
                .execute()
        }
    }

    func removeOfficerFromBranch(officerUserId: UUID) async throws {
        try await supabase.database
            .from("staff_profiles")
            .update(["branch_id": AnyEncodable(Optional<String>.none)])
            .eq("user_id", value: officerUserId)
            .execute()
    }

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

    func removePincode(id: UUID) async throws {
        try await supabase.database
            .from("branch_pincodes")
            .delete()
            .eq("id", value: id)
            .execute()
    }

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

    func fetchBranchLoans(branchId: UUID) async throws -> [Loan] {
        let loans: [Loan] = try await supabase.database
            .from("loans")
            .select()
            .eq("branch_id", value: branchId)
            .execute()
            .value
        return loans
    }

    func fetchBranchMetrics(branchId: UUID) async throws -> BranchMetrics {
        let loans = try await fetchBranchLoans(branchId: branchId)

        let activeLoans = loans.filter { $0.status == .active || $0.status == .restructured }
        let npaLoans = loans.filter { $0.status == .npa }
        let closedLoans = loans.filter { $0.status == .closed }

        let totalDisbursed = loans.reduce(0.0) { $0 + $1.principalAmount }
        let activePortfolio = activeLoans.reduce(0.0) { $0 + $1.outstandingPrincipal + $1.outstandingInterest }
        let npaAmount = npaLoans.reduce(0.0) { $0 + $1.outstandingPrincipal + $1.outstandingInterest }
        let npaRatio = (activePortfolio + npaAmount) > 0 ? (npaAmount / (activePortfolio + npaAmount)) * 100.0 : 0.0

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

    func autoAssignUnassignedApplications() async throws -> Int {
        let applications: [LoanApplication] = try await supabase.database
            .from("loan_applications")
            .select()
            .is("branch_id", value: nil)
            .execute()
            .value

        if applications.isEmpty { return 0 }

        var assignedCount = 0

        for app in applications {
            let profile: BorrowerProfile? = try? await supabase.database
                .from("borrower_profiles")
                .select()
                .eq("user_id", value: app.borrowerId)
                .single()
                .execute()
                .value

            guard let borrowerPincode = profile?.pincode, !borrowerPincode.isEmpty else { continue }

            let branchId = try await findBranchForPincode(pincode: borrowerPincode)

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

    func fetchAvailableManagers() async throws -> [StaffWithUser] {
        let allStaff = try await StaffManagementService.shared.fetchStaff()
        let branches = try await fetchBranches()
        let assignedManagerIds = Set(branches.compactMap { $0.managerId })

        return allStaff.filter { $0.user.role == .manager && !assignedManagerIds.contains($0.user.id) }
    }

    func fetchAvailableOfficers(excludingBranchId: UUID) async throws -> [StaffWithUser] {
        let allStaff = try await StaffManagementService.shared.fetchStaff()

        return allStaff.filter { staffWithUser in
            staffWithUser.user.role == .officer &&
            staffWithUser.staff.branchId != excludingBranchId
        }
    }
}
