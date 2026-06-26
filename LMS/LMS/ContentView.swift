import SwiftUI
import Supabase

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @State private var showPasswordResetAlert = false
    @State private var newPassword = ""

    var body: some View {
        Group {
            switch authViewModel.authState {
            case .splash:
                SplashView()
                    .transition(.opacity)
            case .unauthenticated:
                LoginView()
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            case .kycRequired:
                KYCDashboardView(allowsSkip: true)
                    .transition(.opacity.combined(with: .scale))
            case .authenticated:
                MainTabView()
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .environmentObject(authViewModel)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: authViewModel.authState)
        .onOpenURL { url in
            Task {
                do {
                    // 1. Let Supabase process the reset password URL and log the user in
                    try await SupabaseManager.shared.client.auth.session(from: url)
                    
                    // 2. If it was a password reset link, show the alert to type a new password
                    if url.absoluteString.contains("reset-password") {
                        showPasswordResetAlert = true
                    }
                } catch {
                    print("Failed to handle auth URL: \(error)")
                }
            }
        }
        .alert("Set New Password", isPresented: $showPasswordResetAlert) {
            SecureField("New Password", text: $newPassword)
            Button("Save") {
                Task {
                    do {
                        // 3. Update the password for the newly logged-in user
                        try await SupabaseManager.shared.client.auth.update(user: Supabase.UserAttributes(password: newPassword))
                        newPassword = ""
                    } catch {
                        print("Error updating password: \(error)")
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                newPassword = ""
            }
        } message: {
            Text("Please enter a new password for your account.")
        }
    }
}
#Preview{
    ContentView()
}
