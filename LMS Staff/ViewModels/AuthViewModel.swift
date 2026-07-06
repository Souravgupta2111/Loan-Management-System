//
//  AuthViewModel.swift
//  LMS Staff
//
//  ViewModel managing authentication state, current user, and inactivity timeouts.
//

import Foundation
import Combine
import SwiftUI
import Supabase

enum StaffAuthState: Equatable {
    case splash
    case unauthenticated
    case authenticated(UserRole)
}

@MainActor
class AuthViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var authState: StaffAuthState = .splash
    @Published var currentUser: AppUser?
    @Published var currentStaff: StaffProfile?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    

    
    private let authService = AuthService.shared
    private let supabase = SupabaseManager.shared
    
    init() {
        // Observe auth session state on init
        Task {
            await checkCurrentSession()
        }
    }
    
    // MARK: - Session Management
    
    func checkCurrentSession() async {
        do {
            if let user = try? await supabase.auth.session.user {
                // Fetch details
                let userId = user.id
                let appUser: AppUser = try await supabase.database
                    .from("users")
                    .select()
                    .eq("id", value: userId)
                    .single()
                    .execute()
                    .value
                
                let staffProfile: StaffProfile = try await supabase.database
                    .from("staff_profiles")
                    .select()
                    .eq("user_id", value: userId)
                    .single()
                    .execute()
                    .value
                
                self.currentUser = appUser
                self.currentStaff = staffProfile
                self.authState = .authenticated(appUser.role)
            } else {
                self.authState = .unauthenticated
            }
        } catch {
            self.authState = .unauthenticated
        }
    }
    
    func login(employeeId: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let (appUser, staffProfile) = try await authService.signIn(employeeId: employeeId, password: password)
            self.currentUser = appUser
            self.currentStaff = staffProfile
            self.authState = .authenticated(appUser.role)
        } catch {
            print("❌ LOGIN ERROR: \(error)")
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func resetPassword(employeeId: String) async {
        isLoading = true
        errorMessage = nil
        
        let cleanedId = employeeId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard authService.isValidEmployeeId(cleanedId) else {
            self.errorMessage = "Invalid Employee ID format. Must start with ADM-, MGR-, or OFF-."
            isLoading = false
            return
        }
        
        let email = authService.resolveEmail(from: cleanedId)
        
        do {
            try await supabase.auth.resetPasswordForEmail(email, redirectTo: URL(string: "lmsstaffapp://reset-password"))
            isLoading = false
        } catch {
            isLoading = false
            self.errorMessage = error.localizedDescription
        }
    }
    
    func logout() async {
        do {
            try await authService.signOut()
        } catch {
            print("Error signing out: \(error)")
        }
        self.currentUser = nil
        self.currentStaff = nil
        self.authState = .unauthenticated
    }
    
}
