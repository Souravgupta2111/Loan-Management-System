import SwiftUI
import Supabase
import Combine

enum AuthState: Equatable {
    case splash
    case unauthenticated
    case authenticated
    case kycRequired
}

@MainActor
class AuthViewModel: ObservableObject {
    @Published var authState: AuthState = .splash
    @Published var currentUser: User? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var signUpSucceeded = false

    private let supabase = SupabaseManager.shared

    init() {
        observeAuthState()
    }

    // MARK: - Sign Up (email + password)
    func signUp(fullName: String, email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        signUpSucceeded = false
        do {
            let response = try await supabase.auth.signUp(
                email: email,
                password: password,
                data: [
                    "full_name": .string(fullName),
                    "role": .string("borrower")
                ]
            )
            isLoading = false

            // Check if user was auto-confirmed (no email confirmation required)
            if response.session != nil {
                // User is immediately logged in
                currentUser = response.user
                authState = .authenticated
            } else {
                // Email confirmation is required — show success message
                signUpSucceeded = true
            }
        } catch {
            isLoading = false
            errorMessage = parseError(error)
        }
    }

    // MARK: - Sign In (email + password)
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            try await supabase.auth.signIn(email: email, password: password)
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = parseError(error)
        }
    }

    // MARK: - Reset Password
    func resetPassword(email: String) async {
        isLoading = true
        errorMessage = nil
        do {
            try await supabase.auth.resetPasswordForEmail(email, redirectTo: URL(string: "lmsapp://reset-password"))
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = parseError(error)
        }
    }

    // MARK: - Sign Out
    func signOut() async {
        do {
            try await supabase.auth.signOut()
            authState = .unauthenticated
            currentUser = nil
        } catch {
            errorMessage = parseError(error)
        }
    }

    // MARK: - Check Session
    func checkSession() {
        Task {
            if supabase.currentUser != nil {
                currentUser = supabase.currentUser
                await checkKYCStatus()
            } else {
                authState = .unauthenticated
            }
        }
    }

    // MARK: - Observe Auth Changes
    private func observeAuthState() {
        Task {
            for await (event, session) in supabase.auth.authStateChanges {
                self.currentUser = session?.user
                if event == .signedIn || event == .initialSession {
                    if session != nil {
                        await checkKYCStatus()
                    }
                } else if event == .signedOut {
                    self.authState = .unauthenticated
                }
            }
        }
    }

    // MARK: - KYC Check
    private func checkKYCStatus() async {
        guard let userId = currentUser?.id else {
            authState = .unauthenticated
            return
        }
        
        do {
            struct ProfileStatus: Decodable {
                let kyc_status: String
            }
            
            let profile: [ProfileStatus] = try await supabase.client
                .from("borrower_profiles")
                .select("kyc_status")
                .eq("user_id", value: userId)
                .execute()
                .value
            
            print("checkKYCStatus: Loaded profile status: \(profile.first?.kyc_status ?? "nil")")
            if let status = profile.first?.kyc_status, (status == "verified" || status == "submitted") {
                authState = .authenticated
            } else {
                authState = .kycRequired
            }
        } catch {
            print("checkKYCStatus error: \(error)")
            // Profile might not be created immediately, default to kycRequired
            authState = .kycRequired
        }
    }

    private func parseError(_ error: Error) -> String {
        let desc = error.localizedDescription
        if desc.contains("Invalid login credentials") {
            return "Invalid email or password. Please try again."
        } else if desc.contains("already registered") {
            return "An account with this email already exists."
        } else if desc.contains("Password should be") {
            return "Password must be at least 6 characters."
        } else if desc.contains("rate limit") || desc.contains("429") {
            return "Too many attempts. Please wait a moment and try again."
        } else if desc.contains("email_address_invalid") {
            return "Please enter a valid email address."
        }
        return desc
    }
}
