import SwiftUI
import Supabase

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showPasswordResetAlert = false
    @State private var newPassword = ""
    
    private static var lastInteraction: Date = .distantPast
    
    static func notifyInteraction() {
        let now = Date()
        if now.timeIntervalSince(lastInteraction) > 2.0 {
            lastInteraction = now
            NotificationCenter.default.post(name: NSNotification.Name("UserDidInteract"), object: nil)
        }
    }
    
    var body: some View {
        Group {
            switch authViewModel.authState {
            case .splash:
                SplashView()
            case .unauthenticated:
                StaffLoginView()
            case .authenticated(let role):
                StaffTabRouter(role: role)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { _ in
                    ContentView.notifyInteraction()
                }
        )
        .onOpenURL { url in
            // Widget / Siri deep links (lmsstaffapp://...)
            if url.scheme == "lmsstaffapp" {
                switch url.host {
                case "applications":
                    StaffIntentRouter.shared.request(.applications); return
                case "portfolio":
                    StaffIntentRouter.shared.request(.portfolio); return
                case "npa":
                    StaffIntentRouter.shared.request(.npa); return
                case "disbursements":
                    StaffIntentRouter.shared.request(.disbursements); return
                case "assistant", "chat":
                    let q = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "q" })?.value
                    StaffIntentRouter.shared.request(.aiChat, prefill: q); return
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthViewModel())
    }
}
