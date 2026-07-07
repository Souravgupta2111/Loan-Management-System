import SwiftUI
import Supabase
import Auth

struct ApplicationDetailView: View {
    let application: LoanService.ApplicationListItem
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var newDocuments: [String: Data] = [:]
    @State private var remarksText: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    @State private var showShareSheet = false
    @State private var pdfShareURL: URL?
    
    // Assigned officer info
    @State private var officerInfo: AssignedOfficerInfo?
    @State private var isLoadingOfficer = false
    
    // Documents
    @State private var uploadedDocuments: [LoanService.DocumentRow] = []
    @State private var isLoadingDocuments = false
    @State private var unreadCount = 0
    @State private var messagesChannel: RealtimeChannelV2? = nil
    @State private var customDocumentName: String = ""
    @State private var isUploadingCustomDoc = false
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.xxl) {
                // MARK: - Tracker View
                LoanApplicationTrackerView(status: application.status)
                
                // MARK: - Details
                detailsCard
                
                // MARK: - Documents
                documentsCard
                
                // MARK: - Assigned Officer & Branch Card
                if application.officerId != nil || application.branchName != nil {
                    assignedOfficerCard
                }
                
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
                        
                        Text("Your Remarks / Explanation")
                            .font(.label)
                            .foregroundColor(.textSecondary)
                        
                        TextEditor(text: $remarksText)
                            .frame(height: 80)
                            .padding(8)
                            .liquidGlass(cornerRadius: 8)
                            .overlay(RoundedRectangle(cornerRadius: Corner.md).stroke(Color.border, lineWidth: 1))
                            .foregroundColor(.textPrimary)
                            
                        // Document upload moved to Documents Card
                        
                        if let err = errorMessage {
                            Text(err).font(.caption2).foregroundColor(.accentRed)
                        }
                        if let suc = successMessage {
                            Text(suc).font(.caption2).foregroundColor(.accentGreen)
                        }
                        
                        PillButton(title: isSubmitting ? "Submitting..." : "Submit Response", style: .primary) {
                            Task { await submitResponse() }
                        }
                        .disabled(remarksText.isEmpty || isSubmitting)
                        .padding(.top, Spacing.sm)
                    }
                    .padding(Spacing.lg)
                    .background(Color.accentAmber.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: Corner.md))
                }
                

                // MARK: - Pending Acceptance
                if application.status == "pending_acceptance" {
                    let approvedAmount = application.approvedAmount ?? application.amount
                    let tenure = application.approvedTenure ?? 12
                    let rate = application.approvedInterestRate ?? 12.0 // Annual rate
                    let monthlyRate = (rate / 100.0) / 12.0
                    let x = pow(1.0 + monthlyRate, Double(tenure))
                    let emiAmount = (monthlyRate > 0) ? (approvedAmount * (monthlyRate * x) / (x - 1.0)) : (approvedAmount / Double(tenure))
                    
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        HStack {
                            Image(systemName: "signature").foregroundColor(.accentBlue)
                            Text("Disbursement Terms Ready").font(.cardTitle).foregroundColor(.accentBlue)
                        }
                        Text("Your loan has been approved and is ready for disbursement. Please review and accept the final terms below.")
                            .font(.bodyRegular)
                            .foregroundColor(.textPrimary)
                        
                        Divider().padding(.vertical, Spacing.sm)
                        
                        // Show terms
                        VStack(spacing: Spacing.sm) {
                            HStack {
                                Text("Approved Amount")
                                    .font(.bodyRegular)
                                    .foregroundColor(.textSecondary)
                                Spacer()
                                Text("₹\(formatIndian(approvedAmount))")
                                    .font(.bodyLarge)
                                    .foregroundColor(.textPrimary)
                            }
                            HStack {
                                Text("Tenure")
                                    .font(.bodyRegular)
                                    .foregroundColor(.textSecondary)
                                Spacer()
                                Text("\(tenure) Months")
                                    .font(.bodyLarge)
                                    .foregroundColor(.textPrimary)
                            }
                            HStack {
                                Text("Monthly EMI")
                                    .font(.bodyRegular)
                                    .foregroundColor(.textSecondary)
                                Spacer()
                                Text("₹\(formatIndian(emiAmount))")
                                    .font(.bodyLarge)
                                    .foregroundColor(.textPrimary)
                            }
                        }
                        
                        if let err = errorMessage {
                            Text(err).font(.caption2).foregroundColor(.accentRed)
                        }
                        if let suc = successMessage {
                            Text(suc).font(.caption2).foregroundColor(.accentGreen)
                        } else {
                            HStack(spacing: Spacing.md) {
                                PillButton(title: isSubmitting ? "Processing..." : "Accept Terms", style: .primary) {
                                    Task { await acceptTerms() }
                                }
                                .disabled(isSubmitting)
                                
                                PillButton(title: "Reject", style: .outline) {
                                    Task { await rejectTerms() }
                                }
                                .disabled(isSubmitting)
                            }
                        }
                    }
                    .padding(Spacing.lg)
                    .background(Color.accentBlue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: Corner.md))
                }
                
                // MARK: - Message Officer (US-17)
                if let officerId = application.officerId, let currentUserId = authViewModel.currentUser?.id {
                    NavigationLink {
                        ChatRoomView(applicationId: application.id, currentUserId: currentUserId, officerId: officerId)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "bubble.left.fill")
                            Text("Message Loan Officer")
                            if unreadCount > 0 {
                                Text("\(unreadCount)")
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(.accentGreen)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.accentGreenBg)
                                    .clipShape(Circle())
                            }
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
        .background(
            LinearGradient(
                colors: [Color(hex: "#E7EFE5"), Color(hex: "#EFF4EA"), Color(hex: "#E7EFE5")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationBarBackButtonHidden(true)
        .toolbar { ToolbarItem(placement: .topBarLeading) { GlassBackButton { dismiss() } } }
        .navigationTitle(application.applicationNumber)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showShareSheet) {
            if let url = pdfShareURL {
                ShareSheet(items: [url])
            }
        }
        .task {
            await loadOfficerInfo()
            await loadDocuments()
            await fetchUnreadCount()
            subscribeToUnreadMessages()
        }
        .onDisappear {
            unsubscribeMessages()
        }
    }
    
    // MARK: - Assigned Officer Card
    
    private var assignedOfficerCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "person.badge.shield.checkmark.fill")
                    .font(.title3)
                    .foregroundColor(.accentGreen)
                Text("Your Loan Officer")
                    .font(.cardTitle)
                    .foregroundColor(.textPrimary)
            }
            
            if isLoadingOfficer {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading officer details...")
                        .font(.bodyRegular)
                        .foregroundColor(.textSecondary)
                }
            } else if let info = officerInfo {
                // Officer Name
                HStack(spacing: Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(Color.accentGreen.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Text(String(info.officerName.prefix(1)).uppercased())
                            .font(.headline.weight(.bold))
                            .foregroundColor(.accentGreen)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(info.officerName)
                            .font(.bodyLarge)
                            .foregroundColor(.textPrimary)
                        Text("Loan Officer")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                }
                
                Divider()
                
                // Branch Info
                HStack {
                    Image(systemName: "building.2.fill")
                        .foregroundColor(.textSecondary)
                        .font(.subheadline)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(info.branchName)
                            .font(.bodyRegular)
                            .foregroundColor(.textPrimary)
                        if let city = info.branchCity {
                            Text(city)
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                    }
                }
            } else if let branchName = application.branchName {
                // Fallback: show just branch name if officer info couldn't be loaded
                HStack {
                    Image(systemName: "building.2.fill")
                        .foregroundColor(.textSecondary)
                    Text(branchName)
                        .font(.bodyRegular)
                        .foregroundColor(.textPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(Color.accentGreen.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: Corner.md))
        .overlay(
            RoundedRectangle(cornerRadius: Corner.md)
                .stroke(Color.accentGreen.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func loadOfficerInfo() async {
        guard application.officerId != nil else { return }
        isLoadingOfficer = true
        officerInfo = await BranchAssignmentService.shared.fetchAssignedOfficerInfo(applicationId: application.id)
        isLoadingOfficer = false
    }
    
    private func loadDocuments() async {
        isLoadingDocuments = true
        do {
            uploadedDocuments = try await LoanService.shared.fetchApplicationDocuments(applicationId: application.id)
        } catch {
            print("Failed to load documents: \(error)")
        }
        isLoadingDocuments = false
    }
    
    private func fetchUnreadCount() async {
        guard let currentUserId = authViewModel.currentUser?.id else { return }
        do {
            struct MessageRow: Decodable { let id: UUID }
            let list: [MessageRow] = try await SupabaseManager.shared.client
                .from("messages")
                .select("id")
                .eq("application_id", value: application.id)
                .eq("receiver_id", value: currentUserId)
                .eq("is_read", value: false)
                .execute()
                .value
            unreadCount = list.count
        } catch {
            print("Failed to fetch unread messages count: \(error)")
        }
    }
    
    private func subscribeToUnreadMessages() {
        let channel = SupabaseManager.shared.client.realtimeV2.channel("public:messages:detail_\(application.id.uuidString)")
        self.messagesChannel = channel
        
        let insertions = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "messages",
            filter: .eq("application_id", value: application.id)
        )
        
        Task {
            do {
                try await channel.subscribeWithError()
                for await _ in insertions {
                    await fetchUnreadCount()
                }
            } catch {
                print("Failed to subscribe: \(error)")
            }
        }
    }
    
    private func unsubscribeMessages() {
        if let channel = messagesChannel {
            Task {
                await SupabaseManager.shared.client.realtimeV2.removeChannel(channel)
            }
        }
    }
    
    private var documentsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Documents").font(.cardTitle).foregroundColor(.textPrimary)
            
            if isLoadingDocuments {
                ProgressView()
            } else if uploadedDocuments.isEmpty {
                Text("No documents uploaded yet.")
                    .font(.bodyRegular)
                    .foregroundColor(.textSecondary)
            } else {
                ForEach(uploadedDocuments) { doc in
                    HStack {
                        Image(systemName: "doc.text.fill").foregroundColor(.accentGreen)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(doc.document_type.capitalized.replacingOccurrences(of: "_", with: " "))
                                .font(.bodyLarge)
                                .foregroundColor(.textPrimary)
                            if let date = Formatter.iso8601.date(from: doc.uploaded_at) {
                                Text("Uploaded \(date.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            if application.status == "disbursed" {
                Divider().padding(.vertical, 8)
                
                HStack {
                    Image(systemName: "doc.text.fill").foregroundColor(.accentGreen)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sanction Letter")
                            .font(.bodyLarge)
                            .foregroundColor(.textPrimary)
                        Text("Official approved terms")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                    Spacer()
                    Button(action: {
                        generateAndShareSanctionLetter()
                    }) {
                        Text("Download")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.accentGreen)
                            .cornerRadius(Corner.sm)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Divider().padding(.vertical, 8)
            
            Text("Upload Additional Document")
                .font(.label)
                .foregroundColor(.textSecondary)
            
            TextField("Document Name (e.g. Bank Statement)", text: $customDocumentName)
                .padding(12)
                .background(Color.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: Corner.md))
                .overlay(RoundedRectangle(cornerRadius: Corner.md).stroke(Color.border, lineWidth: 1))
                .foregroundColor(.textPrimary)
            
            DocumentUploadView(
                title: customDocumentName.isEmpty ? "New Document" : customDocumentName,
                subtitle: "Select File",
                documentData: Binding(
                    get: { newDocuments["custom_doc"] },
                    set: { if let d = $0 { newDocuments["custom_doc"] = d } }
                )
            )
            
            if newDocuments["custom_doc"] != nil {
                PillButton(title: isUploadingCustomDoc ? "Uploading..." : "Upload Document", style: .primary) {
                    Task { await uploadCustomDocument() }
                }
                .disabled(isUploadingCustomDoc || customDocumentName.isEmpty)
                .padding(.top, 4)
            }
        }
        .padding(Spacing.lg)
        .liquidGlass(cornerRadius: 16)
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
    }
    
    private func uploadCustomDocument() async {
        guard let data = newDocuments["custom_doc"], !customDocumentName.isEmpty, let userId = authViewModel.currentUser?.id else { return }
        isUploadingCustomDoc = true
        do {
            try await LoanService.shared.uploadAdditionalDocument(
                applicationId: application.id,
                userId: userId,
                data: data,
                title: customDocumentName
            )
            newDocuments["custom_doc"] = nil
            customDocumentName = ""
            await loadDocuments() // Refresh the list
        } catch {
            print("Failed to upload custom document: \(error)")
        }
        isUploadingCustomDoc = false
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
        .liquidGlass(cornerRadius: 16)
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
            // Note: Ideally remarksText would be sent to the backend too, but keeping signature the same for now
            try await LoanService.shared.resubmitApplication(
                applicationId: application.id,
                newDocuments: [:], // Document upload is now handled separately
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
    
    private func generateAndShareSanctionLetter() {
        let pdfData = SanctionLetterService.shared.generateSanctionLetterPDF(
            borrowerName: "Borrower",
            applicationNo: application.applicationNumber,
            approvedAmount: application.amount,
            interestRate: 12.5, // Mocked for UI
            tenureMonths: 24, // Mocked for UI
            emiAmount: (application.amount / 24) * 1.05, // Mocked for UI
            branchName: application.branchName ?? "Main Branch"
        )
        
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "Sanction_Letter_\(application.applicationNumber).pdf"
        let fileURL = tempDir.appendingPathComponent(filename)
        
        do {
            try pdfData.write(to: fileURL)
            self.pdfShareURL = fileURL
            self.showShareSheet = true
        } catch {
            print("Failed to save PDF: \(error)")
        }
    }
    
    private func acceptTerms() async {
        isSubmitting = true
        errorMessage = nil
        do {
            try await LoanService.shared.acceptDisbursement(applicationId: application.id)
            successMessage = "Disbursement accepted successfully!"
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            dismiss()
        } catch {
            errorMessage = "Failed to accept disbursement. Please try again."
        }
        isSubmitting = false
    }
    
    private func rejectTerms() async {
        isSubmitting = true
        errorMessage = nil
        do {
            try await LoanService.shared.rejectDisbursement(applicationId: application.id)
            successMessage = "Disbursement rejected."
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            dismiss()
        } catch {
            errorMessage = "Failed to reject disbursement. Please try again."
        }
        isSubmitting = false
    }
}

