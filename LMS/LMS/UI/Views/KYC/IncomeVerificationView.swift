//
//  IncomeVerificationView.swift
//  LMS Staff
//
//  UI for the Setu Account Aggregator consent flow.
//

import SwiftUI
import WebKit
import Supabase
import Auth
import PostgREST
struct IncomeVerificationView: View {
    @Environment(\.dismiss) private var dismiss
    
    let mobileNumber: String
    let onVerificationComplete: () -> Void
    
    @State private var consentId: String?
    @State private var consentUrl: String?
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                if isLoading {
                    VStack(spacing: 24) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Initiating secure connection with Account Aggregator...")
                            .font(.body)
                            .foregroundColor(.textSecondary)
                    }
                } else if isSaving {
                    VStack(spacing: 24) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Saving consent...")
                            .font(.title3.weight(.bold))
                            .foregroundColor(.textPrimary)
                    }
                } else if let error = errorMessage {
                    VStack(spacing: 24) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title)
                            .foregroundColor(.accentRed)
                        Text("Verification Failed")
                            .font(.title3.weight(.bold))
                            .foregroundColor(.textPrimary)
                        Text(error)
                            .font(.body)
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        PillButton(title: "Retry", style: .primary, icon: "arrow.clockwise") {
                            startFlow()
                        }
                        .frame(width: 200)
                    }
                } else if let urlStr = consentUrl, let url = URL(string: urlStr) {
                    VStack(spacing: 0) {
                        // We use a simple WebView to display the Setu Consent UI
                        SetuWebView(url: url) { resultUrl in
                            // The callback URL might contain success/failure
                            // For simplicity, we just trigger the check when the webview finishes
                            handleConsentCompleted()
                        }
                    }
                }
            }
            .navigationTitle("Income Verification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#2D8B4E"))
                }
            }
            .task {
                startFlow()
            }
        }
    }
    
    private func startFlow() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let result = try await SetuAAService.shared.startVerification(mobileNumber: mobileNumber)
                self.consentId = result.consentId
                self.consentUrl = result.url
                self.isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func handleConsentCompleted() {
        guard let consentId = consentId else { return }
        
        consentUrl = nil // Hide webview
        isSaving = true
        
        Task {
            do {
                var finalStatus = ""
                var retries = 0
                
                // Poll a few times in case Setu's backend takes a moment to transition from PENDING
                while retries < 5 {
                    let status = try await SetuAAService.shared.getConsentStatus(consentId: consentId)
                    finalStatus = status.status.uppercased()
                    
                    if finalStatus == "ACTIVE" || finalStatus == "APPROVED" || finalStatus == "REJECTED" {
                        break
                    }
                    
                    // If PENDING, wait 2 seconds and retry
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                    retries += 1
                }
                
                if finalStatus == "ACTIVE" || finalStatus == "APPROVED" {
                    // Start full AA extraction
                    do {
                        let analyzedData = try await SetuAAService.shared.completeVerification(consentId: consentId)
                        
                        let user = try await SupabaseManager.shared.client.auth.session.user
                        
                        // Update borrower profile
                        struct AAUpdate: Codable {
                            var aa_consent_id: String
                            var aa_consent_status: String
                            var income_verified: Bool
                            var verified_annual_income: Double
                            var itr_assessment_year: String
                        }
                        
                        let updateData = AAUpdate(
                            aa_consent_id: consentId,
                            aa_consent_status: finalStatus,
                            income_verified: true,
                            verified_annual_income: analyzedData.monthlySalary * 12,
                            itr_assessment_year: "AA_VERIFIED"
                        )
                        
                        try await SupabaseManager.shared.client.database
                            .from("borrower_profiles")
                            .update(updateData)
                            .eq("user_id", value: user.id)
                            .execute()
                        
                        isSaving = false
                        onVerificationComplete()
                        dismiss()
                    } catch {
                        self.errorMessage = "Failed to fetch FI data: \\(error.localizedDescription)"
                        self.isSaving = false
                    }
                } else {
                    self.errorMessage = "Consent not approved (Status: \(finalStatus))"
                    self.isSaving = false
                }
            } catch {
                self.errorMessage = error.localizedDescription
                self.isSaving = false
            }
        }
    }
}

// MARK: - WebView Wrapper

struct SetuWebView: UIViewRepresentable {
    let url: URL
    let onRedirect: (URL) -> Void
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        uiView.load(request)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: SetuWebView
        
        init(_ parent: SetuWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            
            if let url = navigationAction.request.url {
                // Check if redirecting back to our app scheme or the callback URL
                if url.absoluteString.starts(with: "https://lms-app.local/callback") {
                    parent.onRedirect(url)
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
    }
}
