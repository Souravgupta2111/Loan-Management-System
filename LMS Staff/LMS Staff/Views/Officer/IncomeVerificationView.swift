//
//  IncomeVerificationView.swift
//  LMS Staff
//
//  UI for the Setu Account Aggregator consent flow.
//

import SwiftUI

struct IncomeVerificationView: View {
    @Environment(\.dismiss) private var dismiss
    
    let consentId: String?
    let consentStatus: String?
    let onVerificationComplete: (AnalyzedIncome) -> Void
    
    @State private var isAnalyzing = false
    @State private var isCheckingStatus = false
    @State private var errorMessage: String?
    @State private var currentStatus: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.staffBackground.ignoresSafeArea()
                
                if isAnalyzing || isCheckingStatus {
                    VStack(spacing: StaffSpacing.lg) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text(isAnalyzing ? "Analyzing bank transactions..." : "Checking consent status...")
                            .font(.staffTitle)
                            .foregroundColor(.staffTextPrimary)
                        if isAnalyzing {
                            Text("Extracting salary credits and FOIR obligations.")
                                .font(.staffBody)
                                .foregroundColor(.staffTextSecondary)
                        }
                    }
                } else if let error = errorMessage {
                    VStack(spacing: StaffSpacing.lg) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title)
                            .foregroundColor(.staffRed)
                        Text("Error")
                            .font(.staffTitle)
                            .foregroundColor(.staffTextPrimary)
                        Text(error)
                            .font(.staffBody)
                            .foregroundColor(.staffTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        StaffButton(title: "Retry", style: .primary, icon: "arrow.clockwise") {
                            checkStatus()
                        }
                        .frame(width: 200)
                    }
                } else {
                    VStack(spacing: StaffSpacing.xl) {
                        Image(systemName: "banknote.fill")
                            .font(.title)
                            .foregroundColor(.staffAccent)
                        
                        Text("Account Aggregator")
                            .font(.staffTitle)
                            .foregroundColor(.staffTextPrimary)
                        
                        if let status = currentStatus, (status.uppercased() == "ACTIVE" || status.uppercased() == "APPROVED"), let _ = consentId {
                            Text("The borrower has successfully verified their income and provided consent. You can now analyze their financial data.")
                                .font(.staffBody)
                                .foregroundColor(.staffTextSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            StaffButton(title: "Analyze Income Data", style: .primary, icon: "chart.bar.doc.horizontal") {
                                startAnalysis()
                            }
                            .frame(width: 300)
                        } else {
                            Text("Waiting for the borrower to complete income verification via the borrower app. Current status: \(currentStatus?.capitalized ?? "Not Started")")
                                .font(.staffBody)
                                .foregroundColor(.staffTextSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            StaffButton(title: "Refresh Status", style: .secondary, icon: "arrow.clockwise") {
                                checkStatus()
                            }
                            .frame(width: 200)
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
                    .foregroundColor(.staffTextSecondary)
                }
            }
            .onAppear {
                currentStatus = consentStatus
                checkStatus()
            }
        }
    }
    
    private func checkStatus() {
        guard let cId = consentId else { return }
        
        isCheckingStatus = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await SetuAAService.shared.getConsentStatus(consentId: cId)
                self.currentStatus = response.status
                self.isCheckingStatus = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isCheckingStatus = false
            }
        }
    }
    
    private func startAnalysis() {
        guard let cId = consentId else { return }
        
        isAnalyzing = true
        errorMessage = nil
        
        Task {
            do {
                let analyzedData = try await SetuAAService.shared.completeVerification(consentId: cId)
                isAnalyzing = false
                dismiss()
                onVerificationComplete(analyzedData)
            } catch {
                self.errorMessage = error.localizedDescription
                self.isAnalyzing = false
            }
        }
    }
}
