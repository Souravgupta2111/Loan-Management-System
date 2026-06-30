//
//  ApplicationDetailView.swift
//  LMS Staff
//
//  Detailed inspector view for a single loan application.
//

import SwiftUI

struct ApplicationDetailView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    let appWithBorrower: ApplicationWithBorrower
    let onStatusUpdated: () -> Void
    
    @StateObject private var vm: ApplicationDetailViewModel
    @Environment(\.openURL) private var openURL
    
    @State private var activeTab: InspectorTab = .profile
    
    // Bottom Action Sheets
    @State private var showRejectSheet: Bool = false
    @State private var showRecommendSheet: Bool = false
    @State private var showRequestDocsSheet: Bool = false
    @State private var showSendBackSheet: Bool = false
    
    // Modals data
    @State private var remarks: String = ""
    @State private var selectedDocsToRequest: [String] = []
    @State private var documentNotes: String = ""
    @State private var chatInputText: String = ""
    @State private var isInternalChat: Bool = true
    
    @State private var showShareSheet = false
    @State private var pdfShareURL: URL?
    
    enum InspectorTab: String, CaseIterable {
        case profile = "KYC & Credit"
        case documents = "Documents"
        case chat = "Chat Support"
        case timeline = "Timeline Log"
    }
    
    init(appWithBorrower: ApplicationWithBorrower, onStatusUpdated: @escaping () -> Void) {
        self.appWithBorrower = appWithBorrower
        self.onStatusUpdated = onStatusUpdated
        
        // Initialize viewmodel
        _vm = StateObject(wrappedValue: ApplicationDetailViewModel(
            application: appWithBorrower.application,
            borrower: appWithBorrower.borrower,
            profile: appWithBorrower.profile,
            product: appWithBorrower.product
        ))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Info Bar
            HStack(spacing: StaffSpacing.lg) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(appWithBorrower.borrower.fullName)
                            .font(.staffTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.staffTextPrimary)
                        
                        StaffStatusBadge(status: vm.application.status.displayName)
                    }
                    
                    Text("App ID: \(vm.application.id.uuidString.prefix(8)) | Product: \(vm.product.name)")
                        .font(.staffCaption)
                        .foregroundColor(.staffTextSecondary)
                }
                
                Spacer()
                
                // Primary Application metrics
                HStack(spacing: StaffSpacing.xl) {
                    DetailMetric(label: "Requested Amount", value: "INR \(String(format: "%.2f", vm.application.requestedAmount))")
                    DetailMetric(label: "Tenure", value: "\(vm.application.requestedTenureMonths) Months")
                    DetailMetric(label: "Branch", value: "HQ - Main Branch")
                }
            }
            .padding(StaffSpacing.lg)
            .background(Color.staffSurface)
            
            // Tab Selector bar
            HStack(spacing: 0) {
                ForEach(InspectorTab.allCases, id: \.self) { tab in
                    Button(action: { activeTab = tab }) {
                        VStack(spacing: 8) {
                            Text(tab.rawValue)
                                .font(.staffBody)
                                .fontWeight(activeTab == tab ? .bold : .regular)
                                .foregroundColor(activeTab == tab ? .staffAccent : .staffTextSecondary)
                            
                            // Indicator line
                            Rectangle()
                                .fill(activeTab == tab ? Color.staffAccent : Color.clear)
                                .frame(height: 3)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .background(Color.staffSurface.opacity(0.5))
            
            // Content Body based on selected Tab
            ScrollView {
                VStack(alignment: .leading, spacing: StaffSpacing.xl) {
                    switch activeTab {
                    case .profile:
                        kycAndCreditSection
                    case .documents:
                        documentsSection
                    case .chat:
                        chatSection
                    case .timeline:
                        timelineSection
                    }
                }
                .padding(StaffSpacing.lg)
            }
            .background(Color.staffBackground)
            
            if vm.application.status == .approved || vm.application.status == .disbursed || vm.application.status == .rejected || ((vm.application.status == .submitted || vm.application.status == .underReview || vm.application.status == .sentBack) && authViewModel.currentUser?.role != .admin) {
                Divider()
                    .background(Color.staffBorder)
                actionButtonBar
            }
        }
        .task {
            await vm.loadAllDetails()
        }
        .navigationBarHidden(false)
        // MODALS/SHEETS LIST
        .sheet(isPresented: $showRejectSheet) {
            rejectionRemarksSheet
        }
        .sheet(isPresented: $showRecommendSheet) {
            recommendChecklistSheet
        }
        .sheet(isPresented: $showRequestDocsSheet) {
            requestDocsSheet
        }
        .sheet(isPresented: $showSendBackSheet) {
            sendBackRemarksSheet
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = pdfShareURL {
                ShareSheet(activityItems: [url])
            }
        }
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { isPresented in if !isPresented { vm.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "An unknown error occurred.")
        }
    }
    
    // MARK: - Subviews
    
    private var kycAndCreditSection: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.lg) {
            HStack(alignment: .top, spacing: StaffSpacing.lg) {
                // Personal KYC info
                StaffCard {
                    VStack(alignment: .leading, spacing: StaffSpacing.md) {
                        Text("KYC Verification Details")
                            .font(.staffTitle)
                            .foregroundColor(.staffTextPrimary)
                        
                        Divider()
                        
                        KYCRow(label: "Full Name", value: vm.borrower.fullName)
                        KYCRow(label: "Email", value: vm.borrower.email ?? "N/A")
                        KYCRow(label: "Phone", value: vm.borrower.phone ?? "N/A")
                        KYCRow(label: "PAN ID", value: vm.borrowerProfile?.panNumber ?? "N/A")
                        KYCRow(label: "Aadhaar Card", value: vm.borrowerProfile?.aadhaarNumber ?? "N/A")
                        KYCRow(label: "Employment Type", value: vm.borrowerProfile?.employmentType?.displayName ?? "N/A")
                        KYCRow(label: "Monthly Income", value: vm.borrowerProfile?.monthlyIncome != nil ? "INR \(String(format: "%.2f", vm.borrowerProfile!.monthlyIncome!))" : "N/A")
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Credit Bureau Score Gauge
                VStack(spacing: StaffSpacing.md) {
                    StaffCard {
                        VStack(spacing: StaffSpacing.md) {
                            Text("Credit Bureau Rating")
                                .font(.staffTitle)
                                .foregroundColor(.staffTextPrimary)
                            
                            Divider()
                            
                            CreditScoreGauge(score: vm.borrowerProfile?.creditScore ?? 300)
                            
                            Text("Bureau: \(vm.borrowerProfile?.creditBureau?.rawValue.uppercased() ?? "EQUIFAX")")
                                .font(.staffCaption)
                                .foregroundColor(.staffTextSecondary)
                        }
                    }
                }
                .frame(width: 320)
            }
        }
    }
    
    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.md) {
            Text("Verification Checklist & Files")
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
            
            if vm.documents.isEmpty {
                EmptyStateView(
                    icon: "doc.badge.plus",
                    title: "No Documents Uploaded",
                    message: "The borrower has not uploaded files yet, or you haven't requested any."
                )
            } else {
                ForEach(vm.documents) { doc in
                    HStack(spacing: StaffSpacing.md) {
                        Image(systemName: "doc.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                            .foregroundColor(.staffAccent)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(doc.documentType)
                                .font(.staffBody)
                                .fontWeight(.bold)
                                .foregroundColor(.staffTextPrimary)
                            
                            Text(doc.fileName)
                                .font(.staffCaption)
                                .foregroundColor(.staffTextSecondary)
                        }
                        
                        Spacer()
                        
                        // Action buttons
                        Button(action: {
                            Task {
                                if let url = await vm.getDocumentUrl(for: doc) {
                                    openURL(url)
                                }
                            }
                        }) {
                            Text("View")
                                .font(.staffCaption)
                                .fontWeight(.bold)
                                .foregroundColor(.staffAccent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.staffAccent.opacity(0.15))
                                .cornerRadius(StaffCorner.sm)
                        }
                        
                        if doc.isVerified {
                            Text("Verified")
                                .font(.staffCaption)
                                .fontWeight(.bold)
                                .foregroundColor(.staffGreen)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.staffGreen.opacity(0.15))
                                .cornerRadius(StaffCorner.sm)
                        } else {
                            Button(action: {
                                Task {
                                    await vm.verifyDocument(documentId: doc.id, isVerified: true)
                                }
                            }) {
                                Text("Verify")
                                    .font(.staffCaption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.staffGreen)
                                    .cornerRadius(StaffCorner.sm)
                            }
                            
                            Button(action: {
                                Task {
                                    await vm.verifyDocument(documentId: doc.id, isVerified: false, reason: "Illegible document scan.")
                                }
                            }) {
                                Text("Reject")
                                    .font(.staffCaption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.staffRed)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: StaffCorner.sm)
                                            .stroke(Color.staffRed, lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(StaffSpacing.md)
                    .background(Color.staffSurface)
                    .cornerRadius(StaffCorner.md)
                }
            }
        }
    }
    
    private var chatSection: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.md) {
            HStack {
                Text("Messaging Support")
                    .font(.staffTitle)
                    .foregroundColor(.staffTextPrimary)
                
                Spacer()
                
                // Toggle between Borrower and Internal chat
                if false {
                    Picker("Chat Type", selection: $isInternalChat) {
                        Text("Borrower Chat").tag(false)
                        Text("Internal Chat").tag(true)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 250)
                }
            }
            
            // Messages thread view
            ScrollView {
                VStack(spacing: StaffSpacing.sm) {
                    let activeMessages = isInternalChat ? vm.internalMessages : vm.borrowerMessages
                    
                    if activeMessages.isEmpty {
                        Text(isInternalChat ? "No internal messages. Send a message below to discuss with the branch manager." : "No messages yet. Send a message below to start a thread with this borrower.")
                            .font(.staffCaption)
                            .foregroundColor(.staffTextSecondary)
                            .padding(.top, 40)
                    } else {
                        ForEach(activeMessages) { msg in
                            let isMe = msg.senderId == SupabaseManager.shared.currentUserId
                            HStack {
                                if isMe { Spacer() }
                                
                                VStack(alignment: isMe ? .trailing : .leading, spacing: 2) {
                                    Text(msg.content)
                                        .font(.staffBody)
                                        .padding(12)
                                        .background(isMe ? Color.staffAccent : (isInternalChat ? Color.staffAmber.opacity(0.2) : Color.staffSurface))
                                        .foregroundColor(isMe ? .white : .staffTextPrimary)
                                        .cornerRadius(12)
                                    
                                    if msg.isRead {
                                        Text("Read")
                                            .font(.system(size: 10))
                                            .foregroundColor(.staffTextSecondary)
                                    }
                                }
                                
                                if !isMe { Spacer() }
                            }
                            .onAppear {
                                if !isMe && !msg.isRead {
                                    Task { await vm.markMessageAsRead(msg.id) }
                                }
                            }
                        }
                    }
                }
            }
            .frame(height: 240)
            
            // Input bar
            HStack {
                TextField(isInternalChat ? "Type internal message..." : "Type a message to client...", text: $chatInputText)
                    .padding(12)
                    .background(Color.staffSurface)
                    .cornerRadius(StaffCorner.md)
                    .foregroundColor(.staffTextPrimary)
                
                Button(action: {
                    Task {
                        await vm.sendChatMessage(chatInputText, isInternal: isInternalChat)
                        chatInputText = ""
                    }
                }) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.staffAccent)
                        .cornerRadius(StaffCorner.md)
                }
                .disabled(chatInputText.isEmpty)
            }
        }
    }
    
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.md) {
            Text("Decision History Trail")
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
            
            StaffTimelineView(items: vm.timelineItems)
        }
    }
    
    private var actionButtonBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: StaffSpacing.md) {
                if vm.application.status == .approved || vm.application.status == .disbursed {
                    Spacer()
                    StaffButton(title: "Download Sanction Letter", style: .primary, icon: "doc.text.fill") {
                        generateAndShareSanctionLetter()
                    }
                    .frame(width: 300)
                } else if vm.application.status == .rejected {
                    Spacer()
                    Text("Application Rejected")
                        .font(.staffTitle)
                        .foregroundColor(.staffRed)
                    Spacer()
                } else {
                    if authViewModel.currentUser?.role != .admin {
                        StaffButton(title: "Request Docs", style: .outline, icon: "doc.badge.plus") {
                            showRequestDocsSheet = true
                        }
                        
                        StaffButton(title: "Send Back", style: .outline, icon: "arrow.uturn.left") {
                            showSendBackSheet = true
                        }
                        
                        StaffButton(title: "Reject", style: .destructive, icon: "xmark.circle") {
                            showRejectSheet = true
                        }
                        
                        Spacer(minLength: 20)
                        
                        StaffButton(title: "Recommend to Manager", style: .primary, icon: "hand.thumbsup.fill") {
                            showRecommendSheet = true
                        }
                        .frame(minWidth: 240)
                    }
                }
            }
            .padding(StaffSpacing.lg)
        }
        .background(Color.staffSurface)
    }
    
    private func generateAndShareSanctionLetter() {
        let pdfData = SanctionLetterService.shared.generateSanctionLetterPDF(
            borrowerName: vm.borrower.fullName,
            applicationNo: vm.application.applicationNumber ?? "APP-000",
            approvedAmount: vm.application.requestedAmount,
            interestRate: 12.5, // Mocked for UI
            tenureMonths: 24, // Mocked for UI
            emiAmount: (vm.application.requestedAmount / 24) * 1.05, // Mocked for UI
            branchName: "Main Branch" // Mocked for UI
        )
        
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "Sanction_Letter_\(vm.application.applicationNumber ?? "APP").pdf"
        let fileURL = tempDir.appendingPathComponent(filename)
        
        do {
            try pdfData.write(to: fileURL)
            self.pdfShareURL = fileURL
            self.showShareSheet = true
        } catch {
            print("Failed to save PDF: \(error)")
        }
    }
    
    // MARK: - Modals Content Sheets
    
    private var rejectionRemarksSheet: some View {
        VStack(spacing: StaffSpacing.lg) {
            Text("Rejection Remarks")
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
            
            TextEditor(text: $remarks)
                .frame(height: 120)
                .padding(8)
                .background(Color.staffSurface)
                .cornerRadius(StaffCorner.md)
                .foregroundColor(.staffTextPrimary)
            
            HStack {
                Button("Cancel") { showRejectSheet = false }
                    .foregroundColor(.staffTextSecondary)
                Spacer()
                Button("Reject Application") {
                    Task {
                        if await vm.rejectApplication(reason: remarks) {
                            showRejectSheet = false
                            onStatusUpdated()
                        }
                    }
                }
                .foregroundColor(.staffRed)
                .fontWeight(.bold)
                .disabled(remarks.isEmpty)
            }
        }
        .padding(30)
        .background(Color.staffBackground.ignoresSafeArea())
    }
    
    private var sendBackRemarksSheet: some View {
        VStack(spacing: StaffSpacing.lg) {
            Text("Send Back Remarks")
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
            
            TextEditor(text: $remarks)
                .frame(height: 120)
                .padding(8)
                .background(Color.staffSurface)
                .cornerRadius(StaffCorner.md)
                .foregroundColor(.staffTextPrimary)
            
            HStack {
                Button("Cancel") { showSendBackSheet = false }
                    .foregroundColor(.staffTextSecondary)
                Spacer()
                Button("Send Back") {
                    Task {
                        if await vm.sendBackToBorrower(reason: remarks) {
                            showSendBackSheet = false
                            onStatusUpdated()
                        }
                    }
                }
                .foregroundColor(.staffAmber)
                .fontWeight(.bold)
                .disabled(remarks.isEmpty)
            }
        }
        .padding(30)
        .background(Color.staffBackground.ignoresSafeArea())
    }
    
    private var requestDocsSheet: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.lg) {
            Text("Request Additional Documents")
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
            
            Text("Select the files to request from the borrower:")
                .font(.staffCaption)
                .foregroundColor(.staffTextSecondary)
            
            let options = ["Salary Slips (3 months)", "Bank Statement (6 months)", "PAN ID Card scan", "Aadhaar Card copy", "Tax Returns (2 Years)", "Vehicle Registration Quotation"]
            
            ForEach(options, id: \.self) { docName in
                Toggle(docName, isOn: Binding(
                    get: { selectedDocsToRequest.contains(docName) },
                    set: { isAdd in
                        if isAdd {
                            selectedDocsToRequest.append(docName)
                        } else {
                            selectedDocsToRequest.removeAll { $0 == docName }
                        }
                    }
                ))
                .foregroundColor(.staffTextPrimary)
            }
            
            TextField("Add request instructions...", text: $documentNotes)
                .padding(12)
                .background(Color.staffSurface)
                .cornerRadius(StaffCorner.md)
                .foregroundColor(.staffTextPrimary)
            
            HStack {
                Button("Cancel") { showRequestDocsSheet = false }
                    .foregroundColor(.staffTextSecondary)
                Spacer()
                Button("Send Request") {
                    Task {
                        if await vm.requestDocuments(documentTypes: selectedDocsToRequest, remarks: documentNotes) {
                            showRequestDocsSheet = false
                            selectedDocsToRequest = []
                            documentNotes = ""
                            onStatusUpdated()
                        }
                    }
                }
                .foregroundColor(.staffAccent)
                .fontWeight(.bold)
                .disabled(selectedDocsToRequest.isEmpty || documentNotes.isEmpty)
            }
        }
        .padding(30)
        .background(Color.staffBackground.ignoresSafeArea())
    }
    
    private var recommendChecklistSheet: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.lg) {
            Text("Officer Checklist Audit")
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
            
            Text("Verify requirements checklist before sending to manager:")
                .font(.staffCaption)
                .foregroundColor(.staffTextSecondary)
            
            VStack(alignment: .leading, spacing: StaffSpacing.md) {
                ChecklistItem(text: "KYC Details matched with original scans")
                ChecklistItem(text: "Bank Details exist and confirmed")
                ChecklistItem(text: "Credit score conforms to rules guidelines")
                ChecklistItem(text: "Income verification files confirmed valid")
            }
            
            HStack {
                Button("Cancel") { showRecommendSheet = false }
                    .foregroundColor(.staffTextSecondary)
                Spacer()
                Button("Confirm & Recommend") {
                    Task {
                        if await vm.recommendToManager() {
                            showRecommendSheet = false
                            onStatusUpdated()
                        }
                    }
                }
                .foregroundColor(.staffGreen)
                .fontWeight(.bold)
            }
            .padding(.top, StaffSpacing.lg)
        }
        .padding(30)
        .background(Color.staffBackground.ignoresSafeArea())
    }
}

// MARK: - Detail Helpers

struct DetailMetric: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(label)
                .font(.staffCaption)
                .foregroundColor(.staffTextSecondary)
            Text(value)
                .font(.staffBody)
                .fontWeight(.bold)
                .foregroundColor(.staffAccent)
        }
    }
}

struct KYCRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.staffBody)
                .foregroundColor(.staffTextSecondary)
            Spacer()
            Text(value)
                .font(.staffBody)
                .fontWeight(.medium)
                .foregroundColor(.staffTextPrimary)
        }
    }
}

struct ChecklistItem: View {
    let text: String
    @State private var isChecked: Bool = false
    
    var body: some View {
        Button(action: { isChecked.toggle() }) {
            HStack(spacing: StaffSpacing.md) {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .foregroundColor(isChecked ? .staffGreen : .staffBorder)
                Text(text)
                    .font(.staffBody)
                    .foregroundColor(.staffTextPrimary)
            }
        }
    }
}
