import SwiftUI
import Supabase
import Auth

struct ApplicationDetailView: View {
    let application: LoanService.ApplicationListItem
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var newDocuments: [String: Data] = [:]
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.xxl) {
                // MARK: - Tracker View
                LoanApplicationTrackerView(status: application.status)
                
                // MARK: - Details
                detailsCard
                
                // MARK: - Rejection Reason (US-10)
                if application.status == "rejected", let reason = application.rejectionReason {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack {
                            Image(systemName: "xmark.octagon.fill").foregroundColor(.accentRed)
                            Text("Application Rejected").font(.cardTitle).foregroundColor(.accentRed)
                        }
                        Text(reason)
                            .font(.bodyRegular)
                            .foregroundColor(.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.lg)
                    .background(Color.accentRed.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: Corner.md))
                }
                
                // MARK: - Sent Back / Remarks (US-09, US-11)
                if application.status == "sent_back", let remarks = application.sentBackReason {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.accentAmber)
                            Text("Action Required").font(.cardTitle).foregroundColor(.accentAmber)
                        }
                        Text(remarks)
                            .font(.bodyRegular)
                            .foregroundColor(.textPrimary)
                        
                        Divider().padding(.vertical, Spacing.sm)
                        
                        Text("Upload Additional Documents")
                            .font(.label)
                            .foregroundColor(.textSecondary)
                        
                        // User can upload a new generic document based on remarks
                        DocumentUploadView(title: "Additional Document", subtitle: "Requested file", documentData: Binding(
                            get: { newDocuments["additional_document"] },
                            set: { if let d = $0 { newDocuments["additional_document"] = d } }
                        ))
                        
                        if let err = errorMessage {
                            Text(err).font(.caption2).foregroundColor(.accentRed)
                        }
                        if let suc = successMessage {
                            Text(suc).font(.caption2).foregroundColor(.accentGreen)
                        }
                        
                        PillButton(title: isSubmitting ? "Submitting..." : "Submit Response", style: .primary) {
                            Task { await submitResponse() }
                        }
                        .disabled(newDocuments.isEmpty || isSubmitting)
                        .padding(.top, Spacing.sm)
                    }
                    .padding(Spacing.lg)
                    .background(Color.accentAmber.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: Corner.md))
                }
                
                // MARK: - Message Officer (US-17)
                if let officerId = application.officerId, let currentUserId = authViewModel.currentUser?.id {
                    NavigationLink {
                        ChatRoomView(applicationId: application.id, currentUserId: currentUserId, officerId: officerId)
                    } label: {
                        HStack {
                            Image(systemName: "bubble.left.fill")
                            Text("Message Loan Officer")
                        }
                        .font(.bodyLarge)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(Spacing.lg)
                        .background(Color.accentBeigeDk)
                        .clipShape(RoundedRectangle(cornerRadius: Corner.md))
                    }
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, 100)
            .padding(.top, Spacing.md)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle(application.applicationNumber)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Application Details").font(.cardTitle).foregroundColor(.textPrimary)
            
            HStack {
                Text("Type")
                    .font(.bodyRegular)
                    .foregroundColor(.textSecondary)
                Spacer()
                Text(application.loanType)
                    .font(.bodyLarge)
                    .foregroundColor(.textPrimary)
            }
            HStack {
                Text("Requested Amount")
                    .font(.bodyRegular)
                    .foregroundColor(.textSecondary)
                Spacer()
                Text("₹\(formatIndian(application.amount))")
                    .font(.bodyLarge)
                    .foregroundColor(.textPrimary)
            }
            HStack {
                Text("Submitted")
                    .font(.bodyRegular)
                    .foregroundColor(.textSecondary)
                Spacer()
                Text(application.submittedAt)
                    .font(.bodyLarge)
                    .foregroundColor(.textPrimary)
            }
        }
        .padding(Spacing.lg)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Corner.md))
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
    }
    
    private func formatIndian(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
    
    private func submitResponse() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            try await LoanService.shared.resubmitApplication(
                applicationId: application.id,
                newDocuments: newDocuments,
                userId: userId
            )
            successMessage = "Application successfully resubmitted."
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            dismiss()
        } catch {
            errorMessage = "Failed to resubmit application. Please try again."
        }
        isSubmitting = false
    }
}
