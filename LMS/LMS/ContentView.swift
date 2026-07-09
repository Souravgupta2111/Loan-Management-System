import SwiftUI
import Supabase

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @EnvironmentObject private var themeManager: AppThemeManager
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
                NavigationStack {
                    KYCDashboardView(allowsSkip: true)
                }
                .transition(.opacity.combined(with: .scale))
            case .authenticated:
                MainTabView()
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .environmentObject(authViewModel)
        .environment(\.appColorPalette, themeManager.selectedPalette)
        .tint(.accentGreen)
        .accessibleAnimation(.spring(response: 0.6, dampingFraction: 0.8), value: authViewModel.authState)
        .onOpenURL { url in
            // Widget / Siri deep links: lmsapp://emi, lmsapp://loans, lmsapp://advisor
            if url.scheme == "lmsapp" {
                switch url.host {
                case "emi", "schedule":
                    IntentRouter.shared.switchTab(.schedule)
                    return
                case "loans":
                    IntentRouter.shared.switchTab(.loans)
                    return
                case "advisor", "chat":
                    let q = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "q" })?.value
                    IntentRouter.shared.openAdvisor(prefill: q)
                    return
                case "pay":
                    if let loanIdStr = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "loanId" })?.value,
                       let loanId = UUID(uuidString: loanIdStr) {
                        IntentRouter.shared.openPayment(loanId: loanId)
                    } else {
                        IntentRouter.shared.switchTab(.schedule)
                    }
                    return
                default:
                    break
                }
            }

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
        .environmentObject(AppThemeManager())
}
