//
//  StaffManagementService.swift
//  LMS Staff
//
//  Service for managing staff profiles, credentials, role assignments, and branch lists.
//

import Foundation
import Supabase

struct StaffWithUser: Identifiable, Hashable {
    var id: UUID { staff.id }
    let staff: StaffProfile
    let user: AppUser
}

class StaffManagementService {
    
    static let shared = StaffManagementService()
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    /// Fetches all branches
    func fetchBranches() async throws -> [Branch] {
        let branches: [Branch] = try await supabase.database
            .from("branches")
            .select()
            .execute()
            .value
        return branches
    }
    
    /// Fetches all staff members by joining staff_profiles and users tables in-memory.
    func fetchStaff() async throws -> [StaffWithUser] {
        let staffProfiles: [StaffProfile] = try await supabase.database
            .from("staff_profiles")
            .select()
            .execute()
            .value
            
        if staffProfiles.isEmpty { return [] }
        
        let users: [AppUser] = try await supabase.database
            .from("users")
            .select()
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
    
    /// Fetches the branch manager for a given branch
    func fetchBranchManager(branchId: UUID) async throws -> AppUser? {
        // Find staff profiles in the branch
        let profiles: [StaffProfile] = try await supabase.database
            .from("staff_profiles")
            .select()
            .eq("branch_id", value: branchId)
            .execute()
            .value
            
        // Fetch the corresponding users to see who has the manager role
        let userIds = profiles.map { $0.userId }
        if userIds.isEmpty { return nil }
        
        let users: [AppUser] = try await supabase.database
            .from("users")
            .select()
            .in("id", values: userIds)
            .eq("role", value: "manager")
            .execute()
            .value
            
        return users.first
    }
    
    /// Auto-generates a unique employee ID based on role prefix (ADM-, MGR-, OFF-)
    func generateEmployeeId(for role: UserRole) async -> String {
        let prefix: String
        switch role {
        case .admin: prefix = "ADM-"
        case .manager: prefix = "MGR-"
        case .officer: prefix = "OFF-"
        case .borrower: prefix = "BOR-"
        }
        
        // Loop until unique
        while true {
            let num = String(format: "%04d", Int.random(in: 1...9999))
            let candidateId = "\(prefix)\(num)"
            
            // Check uniqueness in database
            do {
                let existing: [StaffProfile] = try await supabase.database
                    .from("staff_profiles")
                    .select()
                    .eq("employee_id", value: candidateId)
                    .execute()
                    .value
                
                if existing.isEmpty {
                    return candidateId
                }
            } catch {
                // If query fails, fall back to random
                return candidateId
            }
        }
    }
    
    /// Generates a random alphanumeric password of specified length
    func generateRandomPassword(length: Int = 10) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
        return String((0..<length).map{ _ in letters.randomElement()! })
    }
    
    /// Creates a new staff member account via database RPC
    func createStaff(
        fullName: String,
        role: UserRole,
        designation: String,
        branchId: UUID
    ) async throws -> (employeeId: String, password: String) {
        
        let employeeId = await generateEmployeeId(for: role)
        let password = generateRandomPassword()
        let email = AuthService.shared.resolveEmail(from: employeeId)
        
        struct CreateParams: Encodable {
            let p_email: String
            let p_password: String
            let p_full_name: String
            let p_role: String
            let p_employee_id: String
            let p_designation: String
            let p_branch_id: String
        }
        
        let params = CreateParams(
            p_email: email,
            p_password: password,
            p_full_name: fullName,
            p_role: role.rawValue,
            p_employee_id: employeeId,
            p_designation: designation,
            p_branch_id: branchId.uuidString
        )
        
        // Execute the SECURITY DEFINER Postgres RPC function to create Auth user without logging out
        let _: UUID = try await supabase.database
            .rpc("create_staff_user", params: params)
            .execute()
            .value
            
        // Log action in audit trail
        try await AuditService.shared.logAction(
            action: "CREATE_STAFF",
            tableName: "staff_profiles",
            recordId: nil,
            summary: "Created staff user \(fullName) (\(employeeId)) as \(designation)"
        )
        
        return (employeeId, password)
    }
    
    /// Deactivates or Activates a staff member
    func toggleStaffStatus(userId: UUID, isActive: Bool) async throws {
        try await supabase.database
            .from("users")
            .update(["is_active": AnyEncodable(isActive)])
            .eq("id", value: userId)
            .execute()
            
        // Log action in audit trail
        try await AuditService.shared.logAction(
            action: isActive ? "ACTIVATE_STAFF" : "DEACTIVATE_STAFF",
            tableName: "users",
            recordId: userId,
            summary: "\(isActive ? "Activated" : "Deactivated") staff account with User ID \(userId)"
        )
    }
    
    /// Updates role of a staff member
    func updateStaffRole(userId: UUID, profileId: UUID, oldEmployeeId: String, newRole: UserRole) async throws {
        // Parse new Employee ID with prefix
        let parts = oldEmployeeId.components(separatedBy: "-")
        let suffix = parts.count > 1 ? parts[1] : String(format: "%04d", Int.random(in: 1...9999))
        let prefix: String
        switch newRole {
        case .admin: prefix = "ADM-"
        case .manager: prefix = "MGR-"
        case .officer: prefix = "OFF-"
        case .borrower: prefix = "BOR-"
        }
        let newEmployeeId = "\(prefix)\(suffix)"
        let newEmail = AuthService.shared.resolveEmail(from: newEmployeeId)
        
        // Update users table
        try await supabase.database
            .from("users")
            .update([
                "role": AnyEncodable(newRole.rawValue),
                "email": AnyEncodable(newEmail)
            ])
            .eq("id", value: userId)
            .execute()
            
        // Update staff_profiles table
        try await supabase.database
            .from("staff_profiles")
            .update([
                "employee_id": AnyEncodable(newEmployeeId),
                "designation": AnyEncodable(newRole.displayName)
            ])
            .eq("id", value: profileId)
            .execute()
            
        // Log action in audit trail
        try await AuditService.shared.logAction(
            action: "CHANGE_ROLE",
            tableName: "users",
            recordId: userId,
            summary: "Changed role of user \(userId) to \(newRole.rawValue) (New ID: \(newEmployeeId))"
        )
    }
    
    /// Updates staff profile permissions
    func updateStaffProfile(
        profileId: UUID,
        department: String?,
        designation: String?,
        reportsTo: UUID?,
        maxLoanApprovalLimit: Double?,
        canDisburse: Bool
    ) async throws {
        var updates: [String: AnyEncodable] = [
            "can_disburse": AnyEncodable(canDisburse)
        ]
        
        if let dept = department, !dept.isEmpty {
            updates["department"] = AnyEncodable(dept)
        } else {
            updates["department"] = AnyEncodable(Optional<String>.none)
        }
        
        if let desig = designation, !desig.isEmpty {
            updates["designation"] = AnyEncodable(desig)
        } else {
            updates["designation"] = AnyEncodable(Optional<String>.none)
        }
        
        if let rTo = reportsTo {
            updates["reports_to"] = AnyEncodable(rTo.uuidString)
        } else {
            updates["reports_to"] = AnyEncodable(Optional<String>.none)
        }
        
        if let limit = maxLoanApprovalLimit {
            updates["max_loan_approval_limit"] = AnyEncodable(limit)
        } else {
            updates["max_loan_approval_limit"] = AnyEncodable(Optional<Double>.none)
        }
        
        try await supabase.database
            .from("staff_profiles")
            .update(updates)
            .eq("id", value: profileId)
            .execute()
            
        // Log action
        try await AuditService.shared.logAction(
            action: "UPDATE_STAFF_PROFILE",
            tableName: "staff_profiles",
            recordId: profileId,
            summary: "Updated staff profile permissions and limits"
        )
    }
    
    /// Resets staff member's password and returns the new temporary password
    func resetStaffPassword(userId: UUID) async throws -> String {
        let newPassword = generateRandomPassword()
        
        struct ResetParams: Encodable {
            let p_user_id: String
            let p_new_password: String
        }
        
        let params = ResetParams(
            p_user_id: userId.uuidString,
            p_new_password: newPassword
        )
        
        // Execute the SECURITY DEFINER Postgres RPC function to update Auth user's password
        let _: Bool = try await supabase.database
            .rpc("reset_staff_password", params: params)
            .execute()
            .value
            
        // Log action in audit trail
        try await AuditService.shared.logAction(
            action: "RESET_STAFF_PASSWORD",
            tableName: "users",
            recordId: userId,
            summary: "Reset password for staff user ID \(userId)"
        )
        
        return newPassword
    }
}
