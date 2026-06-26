//
//  StaffManagementViewModel.swift
//  LMS Staff
//
//  ViewModel for managing internal staff accounts, branch mappings, and active statuses.
//

import Foundation
import Combine

@MainActor
class StaffManagementViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var staffList: [StaffWithUser] = []
    @Published var filteredStaff: [StaffWithUser] = []
    @Published var branches: [Branch] = []
    @Published var searchText: String = ""
    
    // For password popup after creation
    @Published var newlyCreatedCredentials: (employeeId: String, password: String)?
    @Published var showCredentialsAlert: Bool = false
    
    // For password popup after reset
    @Published var resetPasswordResult: (employeeId: String, password: String)?
    @Published var showResetAlert: Bool = false
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let staffService = StaffManagementService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] search in
                self?.applyFilters(search: search)
            }
            .store(in: &cancellables)
    }
    
    func loadStaffAndBranches() async {
        isLoading = true
        errorMessage = nil
        
        do {
            self.branches = try await staffService.fetchBranches()
            self.staffList = try await staffService.fetchStaff()
            applyFilters(search: searchText)
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func createStaffAccount(fullName: String, role: UserRole, designation: String, branchId: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            let creds = try await staffService.createStaff(
                fullName: fullName,
                role: role,
                designation: designation,
                branchId: branchId
            )
            self.newlyCreatedCredentials = creds
            self.showCredentialsAlert = true
            
            // Reload
            await loadStaffAndBranches()
            isLoading = false
            return true
        } catch {
            print("❌ CREATE STAFF ERROR: \(error)")
            // self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    func toggleStaffActiveStatus(userId: UUID, isActive: Bool) async {
        errorMessage = nil
        do {
            try await staffService.toggleStaffStatus(userId: userId, isActive: isActive)
            await loadStaffAndBranches()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func changeStaffRole(userId: UUID, profileId: UUID, employeeId: String, newRole: UserRole) async {
        errorMessage = nil
        do {
            try await staffService.updateStaffRole(
                userId: userId,
                profileId: profileId,
                oldEmployeeId: employeeId,
                newRole: newRole
            )
            await loadStaffAndBranches()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func updateStaffProfile(profileId: UUID, department: String?, designation: String?, reportsTo: UUID?, maxLoanApprovalLimit: Double?, canDisburse: Bool) async {
        isLoading = true
        errorMessage = nil
        do {
            try await staffService.updateStaffProfile(
                profileId: profileId,
                department: department,
                designation: designation,
                reportsTo: reportsTo,
                maxLoanApprovalLimit: maxLoanApprovalLimit,
                canDisburse: canDisburse
            )
            await loadStaffAndBranches()
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func resetStaffPassword(userId: UUID, employeeId: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            let password = try await staffService.resetStaffPassword(userId: userId)
            self.resetPasswordResult = (employeeId: employeeId, password: password)
            
            // Introduce a short delay to allow the confirmation alert's dismissal animation to finish
            try? await Task.sleep(nanoseconds: 600_000_000)
            
            self.showResetAlert = true
            isLoading = false
            return true
        } catch {
            print("❌ RESET PASSWORD ERROR: \(error)")
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    private func applyFilters(search: String) {
        if search.isEmpty {
            self.filteredStaff = staffList
        } else {
            let query = search.lowercased()
            self.filteredStaff = staffList.filter {
                $0.user.fullName.lowercased().contains(query) ||
                $0.staff.employeeId.lowercased().contains(query) ||
                ($0.staff.designation ?? "").lowercased().contains(query)
            }
        }
    }
}
