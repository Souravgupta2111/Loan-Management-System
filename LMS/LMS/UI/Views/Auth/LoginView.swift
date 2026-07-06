import SwiftUI

/// Login View (design.md §8.2)
/// Email + Password authentication with gradient background.
struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var showSignUp = false
    @State private var showForgotPassword = false

    var body: some View {
        ZStack {
            // Gradient background (gradientMint)
            LinearGradient(
                colors: [Color.gradientMintStart, Color.surface, Color.gradientLavenderStart],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.xxl) {
                    Spacer().frame(height: 60)

                    // Logo
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "building.columns.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 56, height: 56)
                            .foregroundColor(.accentGreen)
                        Text("Loan Management")
                            .font(.sectionTitle)
                            .foregroundColor(.textPrimary)
                    }

                    // Form card
                    VStack(spacing: Spacing.xl) {
                        FormField(
                            label: "Email Address",
                            placeholder: "you@example.com",
                            text: $email,
                            keyboardType: .emailAddress
                        )

                        // Password with toggle
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Password")
                                .font(.label)
                                .foregroundColor(.textSecondary)
                            HStack {
                                Group {
                                    if showPassword {
                                        TextField("Enter password", text: $password)
                                            .textInputAutocapitalization(.never)
                                    } else {
                                        SecureField("Enter password", text: $password)
                                    }
                                }
                                .font(.bodyLarge)
                                .autocorrectionDisabled()

                                Button { showPassword.toggle() } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundColor(.textTertiary)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.surfaceMuted)
                            .clipShape(RoundedRectangle(cornerRadius: Corner.md))
                        }

                        // Error message
                        if let error = authViewModel.errorMessage {
                            Text(error)
                                .font(.caption2)
                                .foregroundColor(.accentRed)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Sign In / Face ID Row
                        HStack(spacing: Spacing.md) {
                            PillButton(title: "Sign In", style: .primary) {
                                HapticManager.shared.impact(style: .medium)
                                Task {
                                    await authViewModel.signIn(email: email, password: password)
                                    if authViewModel.errorMessage == nil {
                                        HapticManager.shared.notification(type: .success)
                                    } else {
                                        HapticManager.shared.notification(type: .error)
                                    }
                                }
                            }
                            .disabled(email.isEmpty || password.isEmpty || authViewModel.isLoading)
                            .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1)
                            
                            if BiometricAuthService.shared.canEvaluatePolicy() {
                                Button {
                                    HapticManager.shared.impact(style: .medium)
                                    Task {
                                        if await BiometricAuthService.shared.authenticate() {
                                            HapticManager.shared.notification(type: .success)
                                            await authViewModel.restoreSession()
                                        } else {
                                            HapticManager.shared.notification(type: .error)
                                        }
                                    }
                                } label: {
                                    Image(systemName: "faceid")
                                        .font(.title3)
                                        .foregroundColor(.accentGreen)
                                        .frame(width: 48, height: 48)
                                        .background(Color.accentGreen.opacity(0.15))
                                        .clipShape(Circle())
                                }
                            }
                        }

                        if authViewModel.isLoading {
                            ProgressView()
                                .tint(.accentGreen)
                        }

                        // Forgot Password
                        Button {
                            showForgotPassword = true
                        } label: {
                            Text("Forgot Password?")
                                .font(.bodyRegular)
                                .foregroundColor(.accentBeigeDk)
                        }

                        // Divider
                        HStack {
                            Rectangle().fill(Color.border).frame(height: 1)
                            Text("or")
                                .font(.caption2)
                                .foregroundColor(.textTertiary)
                            Rectangle().fill(Color.border).frame(height: 1)
                        }

                        // Sign Up link
                        Button {
                            showSignUp = true
                        } label: {
                            HStack(spacing: 4) {
                                Text("Don't have an account?")
                                    .foregroundColor(.textSecondary)
                                Text("Sign Up")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.accentGreen)
                            }
                            .font(.bodyRegular)
                        }

                    }
                    .padding(Spacing.xxl)
                    .background(Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Corner.xl))
                    .shadow(color: .black.opacity(0.06), radius: 20, x: 0, y: 8)
                    .padding(.horizontal, Spacing.xl)
                }
            }
        }
        .sheet(isPresented: $showSignUp) {
            SignUpView()
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
                .environmentObject(authViewModel)
        }
    }
}
