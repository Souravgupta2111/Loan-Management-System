//
//  BranchManagementViewModel.swift
//  LMS Staff
//
//  ViewModel for admin branch management — CRUD, staff assignments,
//  pincode coverage, and per-branch loan metrics.
//

import Foundation
import Combine
import Supabase

@MainActor
class BranchManagementViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var branches: [Branch] = []
    @Published var filteredBranches: [Branch] = []
    @Published var selectedBranch: Branch?
    @Published var searchText: String = ""

    // Branch Detail Data
    @Published var branchStaff: [StaffWithUser] = []
    @Published var branchPincodes: [BranchPincode] = []
    @Published var branchMetrics: BranchMetrics?
    @Published var branchLoans: [Loan] = []
    @Published var managerUser: AppUser?

    // Assignment Pickers
    @Published var availableManagers: [StaffWithUser] = []
    @Published var availableOfficers: [StaffWithUser] = []

    // State
    @Published var isLoading: Bool = false
    @Published var isLoadingDetail: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var autoAssignCount: Int?

    private let branchService = BranchService.shared
    private let staffService = StaffManagementService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] search in
                self?.applyFilter(search: search)
            }
            .store(in: &cancellables)
    }

    // MARK: - Load Branches

    func loadBranches() async {
        isLoading = true
        errorMessage = nil

        // Repair any stale branch tags so per-branch metrics match the officer's
        // current branch (best-effort; never blocks the branch list).
        try? await branchService.syncLoanBranchesToOfficers()

        do {
            self.branches = try await branchService.fetchBranches()
            applyFilter(search: searchText)
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Load Branch Detail

    func loadBranchDetail(branch: Branch) async {
        self.selectedBranch = branch
        isLoadingDetail = true
        errorMessage = nil

        do {
            // Load staff, pincodes, metrics, and loans in parallel
            async let staffResult = branchService.fetchBranchStaff(branchId: branch.id)
            async let pincodesResult = branchService.fetchBranchPincodes(branchId: branch.id)
            async let metricsResult = branchService.fetchBranchMetrics(branchId: branch.id)
            async let loansResult = branchService.fetchBranchLoans(branchId: branch.id)

            self.branchStaff = try await staffResult
            self.branchPincodes = try await pincodesResult
            self.branchMetrics = try await metricsResult
            self.branchLoans = try await loansResult

            // Resolve manager name
            if let managerId = branch.managerId {
                self.managerUser = try? await fetchUser(userId: managerId)
            } else {
                self.managerUser = nil
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoadingDetail = false
    }

    // MARK: - Create Branch

    func createBranch(
        name: String,
        code: String,
        address: String?,
        city: String?,
        state: String?,
        pincode: String?,
        ifscPrefix: String?
    ) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let branch = try await branchService.createBranch(
                name: name,
                code: code,
                address: address,
                city: city,
                state: state,
                pincode: pincode,
                ifscPrefix: ifscPrefix
            )

            await loadBranches()
            self.selectedBranch = branch
            await loadBranchDetail(branch: branch)
            isLoading = false
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    // MARK: - Update Branch

    func updateBranch(
        name: String,
        address: String?,
        city: String?,
        state: String?,
        pincode: String?,
        ifscPrefix: String?
    ) async -> Bool {
        guard let branch = selectedBranch else { return false }
        errorMessage = nil

        do {
            try await branchService.updateBranch(
                branchId: branch.id,
                name: name,
                address: address,
                city: city,
                state: state,
                pincode: pincode,
                ifscPrefix: ifscPrefix
            )

            await loadBranches()
            // Re-select the updated branch
            if let updated = branches.first(where: { $0.id == branch.id }) {
                await loadBranchDetail(branch: updated)
            }
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Toggle Branch Status

    func toggleBranchStatus() async {
        guard let branch = selectedBranch else { return }
        errorMessage = nil

        do {
            try await branchService.toggleBranchActive(branchId: branch.id, isActive: !branch.isActive)
            await loadBranches()
            if let updated = branches.first(where: { $0.id == branch.id }) {
                await loadBranchDetail(branch: updated)
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Manager Assignment

    func loadAvailableManagers() async {
        do {
            self.availableManagers = try await branchService.fetchAvailableManagers()
            // Also include the current manager so admin can see them in the list
            if let managerId = selectedBranch?.managerId {
                let allStaff = try await staffService.fetchStaff()
                if let current = allStaff.first(where: { $0.user.id == managerId }),
                   !availableManagers.contains(where: { $0.user.id == managerId }) {
                    availableManagers.insert(current, at: 0)
                }
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func assignManager(managerId: UUID) async {
        guard let branch = selectedBranch else { return }
        errorMessage = nil

        do {
            try await branchService.assignManager(branchId: branch.id, managerId: managerId)
            await loadBranches()
            if let updated = branches.first(where: { $0.id == branch.id }) {
                await loadBranchDetail(branch: updated)
            }
            successMessage = "Manager assigned successfully"
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func removeManager() async {
        guard let branch = selectedBranch else { return }
        errorMessage = nil

        do {
            try await branchService.removeManager(branchId: branch.id)
            await loadBranches()
            if let updated = branches.first(where: { $0.id == branch.id }) {
                await loadBranchDetail(branch: updated)
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Officer Assignment

    func loadAvailableOfficers() async {
        guard let branch = selectedBranch else { return }
        do {
            self.availableOfficers = try await branchService.fetchAvailableOfficers(excludingBranchId: branch.id)
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func assignOfficer(officerUserId: UUID) async {
        guard let branch = selectedBranch else { return }
        errorMessage = nil

        do {
            try await branchService.assignOfficer(branchId: branch.id, officerUserId: officerUserId)
            await loadBranchDetail(branch: branch)
            successMessage = "Officer assigned to branch"
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func removeOfficer(officerUserId: UUID) async {
        guard let branch = selectedBranch else { return }
        errorMessage = nil

        do {
            try await branchService.removeOfficerFromBranch(officerUserId: officerUserId)
            await loadBranchDetail(branch: branch)
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Pincode Management

    func addPincode(pincode: String) async -> Bool {
        guard let branch = selectedBranch else { return false }
        errorMessage = nil

        do {
            try await branchService.addPincode(branchId: branch.id, pincode: pincode)
            self.branchPincodes = try await branchService.fetchBranchPincodes(branchId: branch.id)
            return true
        } catch {
            self.errorMessage = "Failed to add pincode. It may already be assigned to another branch."
            return false
        }
    }

    func removePincode(id: UUID) async {
        guard let branch = selectedBranch else { return }
        errorMessage = nil

        do {
            try await branchService.removePincode(id: id)
            self.branchPincodes = try await branchService.fetchBranchPincodes(branchId: branch.id)
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Proximity Auto-Assignment

    func autoAssignLoansByProximity() async {
        isLoading = true
        errorMessage = nil
        autoAssignCount = nil

        do {
            let count = try await branchService.autoAssignUnassignedApplications()
            self.autoAssignCount = count
            if count > 0 {
                successMessage = "\(count) application(s) assigned to branches by pincode"
            } else {
                successMessage = "No unassigned applications found"
            }

            // Reload detail if a branch is selected
            if let branch = selectedBranch {
                await loadBranchDetail(branch: branch)
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Helpers

    private func applyFilter(search: String) {
        if search.isEmpty {
            filteredBranches = branches
        } else {
            let query = search.lowercased()
            filteredBranches = branches.filter {
                $0.name.lowercased().contains(query) ||
                $0.code.lowercased().contains(query) ||
                ($0.city ?? "").lowercased().contains(query) ||
                ($0.pincode ?? "").contains(query)
            }
        }
    }

    private func fetchUser(userId: UUID) async throws -> AppUser {
        let user: AppUser = try await SupabaseManager.shared.database
            .from("users")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        return user
    }
}
