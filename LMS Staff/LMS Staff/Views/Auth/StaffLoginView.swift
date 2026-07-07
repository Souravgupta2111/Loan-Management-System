//
//  StaffLoginView.swift
//  LMS Staff
//
//  iPad-optimized login screen using credentials to determine user roles.
//

import SwiftUI

struct StaffLoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var employeeId: String = ""
    @State private var password: String = ""
    
    enum ActiveAlert: Identifiable {
        case supportNeeded
        case adminEmailSent(email: String)
        case invalidId
        
        var id: String {
            switch self {
            case .supportNeeded: return "supportNeeded"
            case .adminEmailSent(let email): return "adminEmailSent-\(email)"
            case .invalidId: return "invalidId"
            }
        }
    }
    
    @State private var activeAlert: ActiveAlert? = nil
    
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                // Left half: Branding, institution illustration/message
                VStack(alignment: .leading, spacing: StaffSpacing.xl) {
                    Spacer()
                    
                    Image(systemName: "building.columns.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.staffAccent)
                    
                    Text("LMS Enterprise Portal")
                        .font(.title.weight(.bold))
                        .foregroundColor(.staffTextPrimary)
                    
                    Text("Internal dashboard for Loan Officers, Managers, and System Administrators. Please log in using your pre-provisioned employee credentials.")
                        .font(.staffBody)
                        .foregroundColor(.staffTextSecondary)
                        .lineSpacing(6)
                    
                    Spacer()
                    
                    Text("Version 1.0.0 (Build 2026)")
                        .font(.staffCaption)
                        .foregroundColor(.staffTextSecondary.opacity(0.7))
                }
                .padding(60)
                .frame(width: geo.size.width * 0.45, height: geo.size.height)
                .background(Color.staffSurface.opacity(0.4))
                
                // Right half: Login form
                VStack(spacing: StaffSpacing.xl) {
                    Spacer()
                    
                    VStack(spacing: StaffSpacing.xs) {
                        Text("Welcome Back")
                            .font(.staffTitle)
                            .foregroundColor(.staffTextPrimary)
                        Text("Sign in to your workspace")
                            .font(.staffBody)
                            .foregroundColor(.staffTextSecondary)
                    }
                    
                    VStack(spacing: StaffSpacing.md) {
                        StaffFormField(
                            label: "Employee ID",
                            placeholder: "e.g., ADM-0001, MGR-0001",
                            text: $employeeId,
                            error: nil
                        )
                        .onChange(of: employeeId) { newValue in
                            // Auto uppercase and format
                            let upper = newValue.uppercased()
                            if upper != newValue {
                                employeeId = upper
                            }
                        }
                        
                        StaffFormField(
                            label: "Password",
                            placeholder: "Enter password",
                            text: $password,
                            isSecure: true,
                            error: nil
                        )
                    }
                    .frame(maxWidth: 440)
                    
                    if let errorMsg = authViewModel.errorMessage {
                        Text(errorMsg)
                            .font(.staffCaption)
                            .foregroundColor(.staffRed)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .frame(maxWidth: 440)
                    }
                    
                    VStack(spacing: StaffSpacing.md) {
                        HStack(spacing: StaffSpacing.md) {
                            StaffButton(
                                title: "Log In",
                                style: .primary,
                                icon: "lock.fill",
                                isLoading: authViewModel.isLoading
                            ) {
                                HapticManager.shared.impact(style: .medium)
                                Task {
                                    await authViewModel.login(employeeId: employeeId, password: password)
                                    if authViewModel.errorMessage == nil {
                                        HapticManager.shared.notification(type: .success)
                                    } else {
                                        HapticManager.shared.notification(type: .error)
                                    }
                                }
                            }
                            .disabled(employeeId.isEmpty || password.isEmpty)
                            
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
                                        .foregroundColor(.staffAccent)
                                        .frame(width: 48, height: 48)
                                        .background(Color.staffAccent.opacity(0.15))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                        
                        Button(action: {
                            let cleanId = employeeId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                            if cleanId.isEmpty || !AuthService.shared.isValidEmployeeId(cleanId) {
                                activeAlert = .invalidId
                            } else if cleanId.hasPrefix("ADM-") {
                                Task {
                                    await authViewModel.resetPassword(employeeId: cleanId)
                                    if authViewModel.errorMessage == nil {
                                        activeAlert = .adminEmailSent(email: AuthService.shared.resolveEmail(from: cleanId))
                                    }
                                }
                            } else {
                                activeAlert = .supportNeeded
                            }
                        }) {
                            Text("Reset Password?")
                                .font(.staffCaption)
                                .foregroundColor(.staffAccent)
                        }
                    }
                    .frame(maxWidth: 440)
                    
                    Spacer()
                }
                .padding(60)
                .frame(width: geo.size.width * 0.55, height: geo.size.height)
                .background(Color.staffBackground)
            }
        }
        .ignoresSafeArea()
        .alert(item: $activeAlert) { alertType in
            switch alertType {
            case .supportNeeded:
                return Alert(
                    title: Text("Need Help Signing In?"),
                    message: Text("Password resets must be requested directly from your System Administrator (US-61). Please contact support at admin@lms.internal."),
                    dismissButton: .default(Text("Understood"))
                )
            case .adminEmailSent(let email):
                return Alert(
                    title: Text("Check Your Email"),
                    message: Text("We've sent a password reset link to \(email). Please check your inbox."),
                    dismissButton: .default(Text("Understood"))
                )
            case .invalidId:
                return Alert(
                    title: Text("Invalid Employee ID"),
                    message: Text("Please enter a valid Employee ID (e.g., ADM-0001) in the Employee ID field to request a password reset."),
                    dismissButton: .default(Text("Understood"))
                )
            }
        }
    }
}

struct StaffLoginView_Previews: PreviewProvider {
    static var previews: some View {
        StaffLoginView()
            .environmentObject(AuthViewModel())
    }
}
