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
    
    // MARK: - Inactivity Timer Properties
    
    private var lastActivityTime: Date = Date()
    private var inactivityTimer: Timer?
    private let timeoutInterval: TimeInterval = 900 // 15 minutes in seconds
    
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
                startInactivityTimer()
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
            resetActivity()
            startInactivityTimer()
        } catch {
            print("❌ LOGIN ERROR: \(error)")
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func logout() async {
        stopInactivityTimer()
        do {
            try await authService.signOut()
        } catch {
            print("Error signing out: \(error)")
        }
        self.currentUser = nil
        self.currentStaff = nil
        self.authState = .unauthenticated
    }
    
    // MARK: - Inactivity Monitoring
    
    func resetActivity() {
        lastActivityTime = Date()
    }
    
    private func startInactivityTimer() {
        stopInactivityTimer()
        // Check every 30 seconds for inactivity
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if self.authState != .unauthenticated {
                    let elapsed = Date().timeIntervalSince(self.lastActivityTime)
                    if elapsed >= self.timeoutInterval {
                        print("Session timed out due to inactivity")
                        await self.logout()
                        self.errorMessage = "You have been logged out due to inactivity."
                    }
                }
            }
        }
    }
    
    private func stopInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = nil
    }
    
    deinit {
        inactivityTimer?.invalidate()
    }
}
