import SwiftUI
import Combine

struct KYCDashboardView: View {
    @StateObject private var viewModel = KYCViewModel()
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        if viewModel.kycStatus == "submitted" {
                            VStack(spacing: Spacing.lg) {
                                Image(systemName: "clock.badge.checkmark")
                                    .font(.system(size: 52))
                                    .foregroundColor(.accentAmber)
                                Text("KYC Submitted").font(.sectionTitle)
                                Text("Your documents are awaiting officer review. This status updates automatically.")
                                    .font(.bodyRegular)
                                    .foregroundColor(.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(Spacing.xxl)
                            .background(Color.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Corner.xl))
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
                            .background(Color.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Corner.xl))
                        } else {
                        VStack(alignment: .leading, spacing: Spacing.lg) {
                            Text("PAN Verification")
                                .font(.cardTitle)
                                .foregroundColor(.textPrimary)
                            
                            Text("Please enter your details exactly as they appear on your PAN card.")
                                .font(.bodyRegular)
                                .foregroundColor(.textSecondary)
                            
                            VStack(spacing: Spacing.md) {
                                TextField("PAN Number", text: $viewModel.panNumber)
                                    .autocapitalization(.allCharacters)
                                    .padding(Spacing.md)
                                    .background(Color.surfaceMuted)
                                    .clipShape(RoundedRectangle(cornerRadius: Corner.md))
                                
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
                            
                            if let status = viewModel.verificationStatus {
                                Text(status)
                                    .font(.caption)
                                    .foregroundColor(.accentGreen)
                                    .padding(.top, Spacing.xs)
                            }
                            
                            if let error = viewModel.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.accentRed)
                                    .padding(.top, Spacing.xs)
                            }
                            
                            if viewModel.isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, Spacing.md)
                            } else {
                                PillButton(
                                    title: viewModel.isVerified ? "Continue" : "Verify PAN",
                                    style: viewModel.isVerified ? .primary : .outline,
                                    icon: viewModel.isVerified ? "checkmark.seal.fill" : "doc.text.viewfinder"
                                ) {
                                    if !viewModel.isVerified {
                                        Task {
                                            await viewModel.verifyPAN()
                                        }
                                    }
                                }
                                .padding(.top, Spacing.md)
                            }
                        }
                        .padding(Spacing.xl)
                        .background(Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Corner.xl))
                        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
                        
                        if viewModel.isVerified {
                            // Phase 2 of KYC: Aadhaar Verification & Documents
                            VStack(spacing: Spacing.xl) {
                                Text("Aadhaar Verification")
                                    .font(.cardTitle)
                                    .foregroundColor(.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                TextField("Aadhaar Number (12 digits)", text: $viewModel.aadhaarNumber)
                                    .keyboardType(.numberPad)
                                    .padding(Spacing.md)
                                    .background(Color.surfaceMuted)
                                    .clipShape(RoundedRectangle(cornerRadius: Corner.md))
                                
                                if let status = viewModel.aadhaarVerificationStatus {
                                    Text(status)
                                        .font(.caption)
                                        .foregroundColor(.accentGreen)
                                        .padding(.top, Spacing.xs)
                                }
                                
                                if !viewModel.isAadhaarVerified {
                                    PillButton(
                                        title: "Verify Aadhaar",
                                        style: .outline,
                                        icon: "doc.text.viewfinder"
                                    ) {
                                        Task {
                                            await viewModel.verifyAadhaar()
                                        }
                                    }
                                    .padding(.top, Spacing.md)
                                }
                            }
                            .padding(Spacing.xl)
                            .background(Color.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Corner.xl))
                            .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
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
                                .background(Color.surface)
                                .clipShape(RoundedRectangle(cornerRadius: Corner.xl))
                                .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
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
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.isVerified)
            .task {
                while !Task.isCancelled {
                    await viewModel.refreshKYCStatus()
                    if viewModel.kycStatus == "verified" {
                        authViewModel.checkSession()
                        return
                    }
                    try? await Task.sleep(for: .seconds(5))
                }
            }
        }
    }
}
