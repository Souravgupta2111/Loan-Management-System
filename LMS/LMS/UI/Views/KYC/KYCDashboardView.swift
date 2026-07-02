import SwiftUI
import Combine

struct KYCDashboardView: View {
    @StateObject private var viewModel = KYCViewModel()
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    let allowsSkip: Bool
    let isPresentedModally: Bool

    init(allowsSkip: Bool = true, isPresentedModally: Bool = false) {
        self.allowsSkip = allowsSkip
        self.isPresentedModally = isPresentedModally
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "#E7EFE5"), Color(hex: "#EFF4EA"), Color(hex: "#E7EFE5")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        if viewModel.kycStatus == "verified" {
                            VStack(spacing: Spacing.lg) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 52))
                                    .foregroundColor(.accentGreen)
                                Text("KYC Verified").font(.sectionTitle)
                                Text("Your identity has been successfully verified. You have full access to all loan products.")
                                    .font(.bodyRegular)
                                    .foregroundColor(.textSecondary)
                                    .multilineTextAlignment(.center)
                                
                                PillButton(title: "Done", style: .primary) {
                                    dismiss()
                                }
                                .padding(.top, Spacing.md)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(Spacing.xxl)
                            .liquidGlass(cornerRadius: 22)
                        } else if viewModel.kycStatus == "submitted" {
                            VStack(spacing: Spacing.lg) {
                                Image(systemName: "clock.badge.checkmark")
                                    .font(.system(size: 52))
                                    .foregroundColor(Color(hex: "#1A1A1A"))
                                Text("KYC Submitted").font(.sectionTitle)
                                Text("Your documents are awaiting officer review. This status updates automatically.")
                                    .font(.bodyRegular)
                                    .foregroundColor(.textSecondary)
                                    .multilineTextAlignment(.center)
                                
                                PillButton(title: "Done", style: .primary) {
                                    dismiss()
                                }
                                .padding(.top, Spacing.md)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(Spacing.xxl)
                            .liquidGlass(cornerRadius: 22)
                        } else if viewModel.kycStatus == "rejected" {
                            VStack(spacing: Spacing.md) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.accentRed)
                                Text("KYC Requires Attention").font(.sectionTitle)
                                Text("Some of your documents were rejected. Please review the reasons below and resubmit them.")
                                    .font(.bodyRegular)
                                    .foregroundColor(.textSecondary)
                                    .multilineTextAlignment(.center)
                                
                                if !viewModel.rejectedDocuments.isEmpty {
                                    VStack(alignment: .leading, spacing: Spacing.lg) {
                                        ForEach(Array(viewModel.rejectedDocuments.keys), id: \.self) { docType in
                                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                                Text(docType.replacingOccurrences(of: "_", with: " ").capitalized)
                                                    .font(.cardTitle)
                                                    .foregroundColor(.accentRed)
                                                
                                                Text("Reason: \(viewModel.rejectedDocuments[docType]!)")
                                                    .font(.bodyRegular)
                                                    .foregroundColor(.textSecondary)
                                                
                                                if docType == "selfie" {
                                                    SelfieCaptureView(selfieData: Binding(
                                                        get: { nil },
                                                        set: { data in
                                                            if let data = data {
                                                                Task { await viewModel.resubmitDocument(type: docType, data: data) }
                                                            }
                                                        }
                                                    ))
                                                } else {
                                                    DocumentUploadView(title: "Upload New", subtitle: "Select File", documentData: Binding(
                                                        get: { nil },
                                                        set: { data in
                                                            if let data = data {
                                                                Task { await viewModel.resubmitDocument(type: docType, data: data) }
                                                            }
                                                        }
                                                    ))
                                                }
                                            }
                                            .padding()
                                            .background(Color.accentRed.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: Corner.md))
                                        }
                                    }
                                    .padding(.top, Spacing.md)
                                }
                                
                                if viewModel.isLoading {
                                    ProgressView()
                                        .padding(.top, Spacing.md)
                                }
                            }
                            .padding(Spacing.xxl)
                            .liquidGlass(cornerRadius: 22)
                        } else {
                        VStack(alignment: .leading, spacing: Spacing.lg) {
                            Text("PAN Verification")
                                .font(.cardTitle)
                                .foregroundColor(.textPrimary)
                            
                            Text("Please enter your details exactly as they appear on your PAN card.")
                                .font(.bodyRegular)
                                .foregroundColor(.textSecondary)
                            
                            VStack(spacing: Spacing.md) {
                                MaskedTextField(
                                    placeholder: "PAN Number",
                                    text: $viewModel.panNumber,
                                    keyboardType: .default
                                )
                                
                                TextField("Full Name", text: $viewModel.fullName)
                                    .padding(Spacing.md)
                                    .background(Color.surfaceMuted)
                                    .clipShape(RoundedRectangle(cornerRadius: Corner.md))
                                
                                TextField("Date of Birth (DD/MM/YYYY)", text: $viewModel.dob)
                                    .keyboardType(.numbersAndPunctuation)
                                    .padding(Spacing.md)
                                    .background(Color.surfaceMuted)
                                    .clipShape(RoundedRectangle(cornerRadius: Corner.md))
                            }
                            
                            if let status = viewModel.panVerificationStatus {
                                Text(status)
                                    .font(.caption)
                                    .foregroundColor(.accentGreen)
                                    .padding(.top, Spacing.xs)
                            }
                            
                            if let error = viewModel.panErrorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.accentRed)
                                    .padding(.top, Spacing.xs)
                            }
                            
                            if viewModel.isPANLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, Spacing.md)
                            } else if !viewModel.isVerified {
                                PillButton(
                                    title: "Verify PAN",
                                    style: .outline,
                                    icon: "doc.text.viewfinder"
                                ) {
                                    Task {
                                        await viewModel.verifyPAN()
                                    }
                                }
                                .padding(.top, Spacing.md)
                            }
                        }
                        .padding(Spacing.xl)
                        .liquidGlass(cornerRadius: 22)
                        
                        if viewModel.isVerified {
                            // Phase 2 of KYC: Aadhaar Verification (OTP Flow)
                            VStack(spacing: Spacing.xl) {
                                Text("Aadhaar Verification")
                                    .font(.cardTitle)
                                    .foregroundColor(.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                if !viewModel.isOTPSent {
                                    // Step 1: Enter Aadhaar and send OTP
                                    MaskedTextField(
                                        placeholder: "Aadhaar Number (12 digits)",
                                        text: $viewModel.aadhaarNumber,
                                        keyboardType: .numberPad
                                    )
                                } else if !viewModel.isAadhaarVerified {
                                    // Step 2: Enter OTP
                                    Text("Enter the OTP sent to your Aadhaar-linked mobile")
                                        .font(.bodyRegular)
                                        .foregroundColor(.textSecondary)
                                    
                                    TextField("6-digit OTP", text: $viewModel.aadhaarOTP)
                                        .keyboardType(.numberPad)
                                        .padding(Spacing.md)
                                        .background(Color.surfaceMuted)
                                        .clipShape(RoundedRectangle(cornerRadius: Corner.md))
                                }
                                
                                if let status = viewModel.aadhaarVerificationStatus {
                                    Text(status)
                                        .font(.caption)
                                        .foregroundColor(.accentGreen)
                                        .padding(.top, Spacing.xs)
                                }
                                
                                if let error = viewModel.aadhaarErrorMessage {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.accentRed)
                                        .padding(.top, Spacing.xs)
                                }
                                
                                if viewModel.isAadhaarLoading {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                        .padding(.top, Spacing.md)
                                } else if !viewModel.isAadhaarVerified {
                                    if !viewModel.isOTPSent {
                                        PillButton(
                                            title: "Send OTP",
                                            style: .outline,
                                            icon: "paperplane.fill"
                                        ) {
                                            Task {
                                                await viewModel.sendAadhaarOTP()
                                            }
                                        }
                                        .padding(.top, Spacing.md)
                                    } else {
                                        VStack(spacing: Spacing.sm) {
                                            PillButton(
                                                title: "Verify OTP",
                                                style: .primary,
                                                icon: "checkmark.shield.fill"
                                            ) {
                                                Task {
                                                    await viewModel.verifyAadhaarOTP()
                                                }
                                            }
                                            
                                            Button("Resend OTP") {
                                                Task {
                                                    await viewModel.sendAadhaarOTP()
                                                }
                                            }
                                            .font(.caption)
                                            .foregroundColor(.textSecondary)
                                        }
                                        .padding(.top, Spacing.md)
                                    }
                                }
                            }
                            .padding(Spacing.xl)
                            .liquidGlass(cornerRadius: 22)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                            
                            if viewModel.isAadhaarVerified {
                                // Phase 3 of KYC: Documents & Liveness
                                VStack(spacing: Spacing.xl) {
                                    Text("Upload Documents")
                                        .font(.cardTitle)
                                        .foregroundColor(.textPrimary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    DocumentUploadView(title: "Address Proof", subtitle: "Passport / Driver's License", documentData: $viewModel.addressProofData)
                                
                                Text("Verification")
                                    .font(.cardTitle)
                                    .foregroundColor(.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, Spacing.md)
                                
                                SelfieCaptureView(selfieData: $viewModel.selfieData)
                                
                                if let error = viewModel.errorMessage {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.accentRed)
                                        .padding(.top, Spacing.xs)
                                }
                                
                                if viewModel.isSubmittingFullKYC {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                        .padding(.top, Spacing.lg)
                                } else {
                                    PillButton(title: "Submit Full KYC", style: .primary, icon: "paperplane.fill") {
                                        Task {
                                            await viewModel.submitFullKYC(authViewModel: authViewModel)
                                        }
                                    }
                                    .padding(.top, Spacing.lg)
                                }
                                }
                                .padding(Spacing.xl)
                                .liquidGlass(cornerRadius: 22)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        }
                        }
                    }
                    .padding(Spacing.xl)
                }
            }
            .navigationTitle("KYC Setup")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isPresentedModally {
                        Button(action: { dismiss() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Back")
                                    .font(.system(size: 16, weight: .regular))
                            }
                            .foregroundColor(Color(hex: "#2D8B4E")) // match accent green
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if allowsSkip {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Button(action: {
                                Task {
                                    await viewModel.skipKYC(authViewModel: authViewModel)
                                }
                            }) {
                                Text("Skip KYC")
                                    .font(.bodyLarge)
                                    .foregroundColor(.accentGreen)
                            }
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .tabBar)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.isVerified)
            .task {
                while !Task.isCancelled {
                    await viewModel.refreshKYCStatus()
                    if viewModel.kycStatus == "verified" || viewModel.kycStatus == "submitted" {
                        if authViewModel.authState != .authenticated {
                            authViewModel.authState = .authenticated
                        }
                    }
                    try? await Task.sleep(for: .seconds(5))
                }
            }
        }
    }
}
