//
//  AuthService.swift
//  LMS Staff
//
//  Service for managing user authentication and role parsing.
//

import Foundation
import Supabase
import Combine

@MainActor
class AuthService: ObservableObject {
    
    static let shared = AuthService()
    
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    /// Resolves the email address associated with an employee ID.
    nonisolated func resolveEmail(from employeeId: String) -> String {
        let cleanedId = employeeId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleanedId == "ADM-0001" {
            return "guptajaihind786@gmail.com"
        }
        return "\(cleanedId.lowercased())@lms.internal"
    }
    
    /// Signs in a staff member using their Employee ID and password.
    /// Under the hood, this resolves the ID to its registered email address and uses Supabase Auth.
    func signIn(employeeId: String, password: String) async throws -> (AppUser, StaffProfile) {
        let cleanedId = employeeId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard isValidEmployeeId(cleanedId) else {
            throw NSError(domain: "AuthService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Employee ID format. Must start with ADM-, MGR-, or OFF-."])
        }
        
        let email = resolveEmail(from: cleanedId)
        
        // Sign in using email auth
        let response = try await supabase.auth.signIn(email: email, password: password)
        let userId = response.user.id
        
        // Fetch user from public.users
        let appUser: AppUser = try await supabase.database
            .from("users")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value
            
        // Fetch staff profile from public.staff_profiles
        let staffProfile: StaffProfile = try await supabase.database
            .from("staff_profiles")
            .select()
            .eq("user_id", value: userId)
            .single()
            .execute()
            .value
            
        return (appUser, staffProfile)
    }
    
    /// Signs out the current user session
    func signOut() async throws {
        try await supabase.auth.signOut()
    }
    
    /// Helper to parse role from employee ID prefix
    func parseRole(from employeeId: String) -> UserRole? {
        let cleanId = employeeId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleanId.hasPrefix("ADM-") {
            return .admin
        } else if cleanId.hasPrefix("MGR-") {
            return .manager
        } else if cleanId.hasPrefix("OFF-") {
            return .officer
        }
        return nil
    }
    
    /// Validates employee ID format (e.g. ADM-0001, MGR-1234)
    func isValidEmployeeId(_ employeeId: String) -> Bool {
        let cleanId = employeeId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let regex = "^(ADM|MGR|OFF)-\\d{4}$"
        return cleanId.range(of: regex, options: .regularExpression) != nil
    }
}
