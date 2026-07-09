import SwiftUI

/// Sign Up View (design.md §8.2)
/// Full Name, Email, Password, Confirm Password.
struct SignUpView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var fullName = ""
    @State private var email = ""
    @State private var mobileNumber = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var localError: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.xxl) {
                        Spacer().frame(height: 20)

                        // Header
                        VStack(spacing: Spacing.sm) {
                            Image(systemName: "person.badge.plus.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 48, height: 48)
                                .foregroundColor(.accentGreen)
                            Text("Create Account")
                                .font(.sectionTitle)
                                .foregroundColor(.textPrimary)
                            Text("Start your loan journey today")
                                .font(.bodyRegular)
                                .foregroundColor(.textSecondary)
                        }

                        // Form card
                        VStack(spacing: Spacing.xl) {
                            if !authViewModel.signUpSucceeded {
                                FormField(
                                    label: "Full Name",
                                    placeholder: "Enter your full name",
                                    text: $fullName,
                                    error: fullNameError
                                )

                                FormField(
                                    label: "Email Address",
                                    placeholder: "you@example.com",
                                    text: $email,
                                    error: emailError,
                                    keyboardType: .emailAddress
                                )
                                
                                FormField(
                                    label: "Mobile Number",
                                    placeholder: "Enter 10-digit number",
                                    text: $mobileNumber,
                                    error: mobileError,
                                    keyboardType: .phonePad
                                )

                                FormField(
                                    label: "Password",
                                    placeholder: "Minimum 6 characters",
                                    text: $password,
                                    isSecure: true,
                                    error: passwordError
                                )

                                FormField(
                                    label: "Confirm Password",
                                    placeholder: "Re-enter your password",
                                    text: $confirmPassword,
                                    isSecure: true,
                                    error: passwordMismatchError
                                )
                            }

                            if let error = localError ?? authViewModel.errorMessage {
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

                            if authViewModel.signUpSucceeded {
                                VStack(spacing: Spacing.md) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .resizable()
                                        .frame(width: 48, height: 48)
                                        .foregroundColor(.accentGreen)
                                    Text("Account Created!")
                                        .font(.sectionTitle)
                                        .foregroundColor(.textPrimary)
                                    Text("Please check your email to confirm your account, then sign in.")
                                        .font(.bodyRegular)
                                        .foregroundColor(.textSecondary)
                                        .multilineTextAlignment(.center)
                                    PillButton(title: "Go to Sign In", style: .primary) {
                                        dismiss()
                                    }
                                }
                                .padding(.vertical, Spacing.xl)
                            } else {
                                PillButton(title: "Sign Up", style: .primary) {
                                    signUp()
                                }
                                .disabled(!isValid || authViewModel.isLoading)
                                .opacity(isValid ? 1 : 0.6)

                                if authViewModel.isLoading {
                                    ProgressView()
                                        .tint(.accentGreen)
                                }

                                Button {
                                    dismiss()
                                } label: {
                                    HStack(spacing: 4) {
                                        Text("Already have an account?")
                                            .foregroundColor(.textSecondary)
                                        Text("Sign In")
                                            .fontWeight(.semibold)
                                            .foregroundColor(.accentGreen)
                                    }
                                    .font(.bodyRegular)
                                }
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    GlassBackButton(iconName: "xmark") { dismiss() }
                }
            }
            .onAppear {
                authViewModel.errorMessage = nil
                authViewModel.signUpSucceeded = false
                localError = nil
            }
        }
    }

    private var isValid: Bool {
        !fullName.isEmpty && !email.isEmpty && !mobileNumber.isEmpty && password.count >= 6 && password == confirmPassword
    }

    private var fullNameError: String? {
        if !fullName.isEmpty {
            let allowedCharacters = CharacterSet.letters.union(.whitespaces)
            if fullName.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
                return "Name should only contain letters"
            }
        }
        return nil
    }

    private var emailError: String? {
        if !email.isEmpty && !email.contains("@") {
            return "Invalid email format"
        }
        return nil
    }

    private var mobileError: String? {
        if !mobileNumber.isEmpty && mobileNumber.count != 10 {
            return "Must be 10 digits"
        }
        return nil
    }

    private var passwordError: String? {
        if !password.isEmpty && password.count < 6 {
            return "Minimum 6 characters required"
        }
        return nil
    }

    private var passwordMismatchError: String? {
        if !confirmPassword.isEmpty && password != confirmPassword {
            return "Passwords do not match"
        }
        return nil
    }

    private func signUp() {
        guard password == confirmPassword else {
            localError = "Passwords do not match"
            return
        }
        guard password.count >= 6 else {
            localError = "Password must be at least 6 characters"
            return
        }
        localError = nil
        Task {
            await authViewModel.signUp(fullName: fullName, email: email, mobileNumber: mobileNumber, password: password)
        }
    }
}
