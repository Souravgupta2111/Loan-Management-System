import SwiftUI

/// Forgot Password View
struct ForgotPasswordView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var emailSent = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.gradientMintStart, Color.surface],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: Spacing.xxl) {
                    Spacer().frame(height: 40)

                    if emailSent {
                        // Success state
                        VStack(spacing: Spacing.xl) {
                            Image(systemName: "envelope.badge.shield.half.filled.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 64, height: 64)
                                .foregroundColor(.accentGreen)

                            Text("Check Your Email")
                                .font(.sectionTitle)
                                .foregroundColor(.textPrimary)

                            Text("We've sent a password reset link to **\(email)**. Please check your inbox.")
                                .font(.bodyRegular)
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)

                            PillButton(title: "Back to Sign In", style: .primary) {
                                dismiss()
                            }
                            .padding(.top, Spacing.lg)
                        }
                        .padding(Spacing.xxl)
                    } else {
                        // Form state
                        VStack(spacing: Spacing.xl) {
                            Image(systemName: "lock.rotation")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 48, height: 48)
                                .foregroundColor(.accentGreen)

                            Text("Reset Password")
                                .font(.sectionTitle)
                                .foregroundColor(.textPrimary)

                            Text("Enter your email address and we'll send you a link to reset your password.")
                                .font(.bodyRegular)
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)

                            FormField(
                                label: "Email Address",
                                placeholder: "you@example.com",
                                text: $email,
                                keyboardType: .emailAddress
                            )

                            if let error = authViewModel.errorMessage {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                    Text(error)
                                        .font(.caption.weight(.medium))
                                }
                                .foregroundColor(.accentRed)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.accentRed.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: Corner.md))
                            }

                            PillButton(title: "Reset Password", style: .primary) {
                                Task {
                                    await authViewModel.resetPassword(email: email)
                                    if authViewModel.errorMessage == nil {
                                        withAnimation { emailSent = true }
                                    }
                                }
                            }
                            .disabled(email.isEmpty || authViewModel.isLoading)
                            .opacity(email.isEmpty ? 0.6 : 1)

                            if authViewModel.isLoading {
                                ProgressView()
                                    .tint(.accentGreen)
                            }
                        }
                        .padding(Spacing.xxl)
                    }

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    GlassBackButton(iconName: "xmark") { dismiss() }
                }
            }
        }
    }
}
