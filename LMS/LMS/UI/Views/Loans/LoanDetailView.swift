import SwiftUI
import Supabase

struct LoanDetailView: View {
    let loan: LoanListItem
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedTab: DetailTab = .timeline
    @State private var isLoading = true
    @State private var loadError: String?
    
    @State private var dbDetails: LoanDetailsFetch? = nil
    @State private var timelineSteps: [TimelineStep] = []
    @State private var documentItems: [DocumentItem] = []
    @State private var emiScheduleItems: [EMIDetailRowItem] = []
    @State private var paymentHistory: [LoanPaymentRow] = []
    
    // Document Download State
    @State private var isDownloadingId: UUID? = nil
    @State private var downloadedURL: URL? = nil
    @State private var showShareSheet = false

    // Realtime Channels
    @State private var realtimeChannels: [RealtimeChannelV2] = []

    enum DetailTab: String, CaseIterable {
        case timeline = "Timeline"
        case documents = "Documents"
        case schedule = "Schedule"
        
        var displayName: String { rawValue }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "#F2F9F4")
                .ignoresSafeArea()
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = loadError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.red)
                    Text("Failed to load details")
                        .font(.system(size: 18, weight: .bold))
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Button {
                        Task {
                            await loadRelatedData()
                        }
                    } label: {
                        Text("Retry")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color(hex: "#2D8B4E"))
                            .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        headerLoanCard
                            .padding(.top, 12)
                        
                        subTabPicker
                        
                        tabContent
                            .padding(.bottom, 140)
                    }
                    .padding(.horizontal, 20)
                }
            }
            
            // Bottom pay bar for active loans
            if loan.status.lowercased() == "active" {
                bottomPayBar
            }
        }
        .navigationTitle(loan.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 36, height: 36)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1.5)
                }
            }
        }
        .task {
            await loadRelatedData()
            subscribeToRealtimeUpdates()
        }
        .onDisappear {
            Task {
                for channel in realtimeChannels {
                    await SupabaseManager.shared.client.realtimeV2.removeChannel(channel)
                }
                realtimeChannels.removeAll()
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = downloadedURL {
                ShareSheet(items: [url])
            }
        }
    }

    // MARK: - Header Loan Card
    private var headerLoanCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Row 1: Loan ID + Value
            HStack {
                Text("Loan ID")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                Spacer()
                Text(loan.loanNumber)
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundColor(.textSecondary)
            }
            
            Divider()
                .background(Color.border.opacity(0.5))
            
            // Row 2: Sanctioned & Monthly EMI
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sanctioned")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textSecondary)
                    Text("₹\(formatIndian(loan.amount))")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    Text("Monthly EMI")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textSecondary)
                    Text("₹\(formatIndian(loan.emiAmount > 0 ? loan.emiAmount : (emiScheduleItems.first?.amount ?? 0)))")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)
                    
                    Text(emiDayString)
                        .font(.system(size: 12))
                        .foregroundColor(.textTertiary)
                }
            }
            
            // Row 3: Info pills – Tenure · Remaining · Rate
            HStack(spacing: 8) {
                infoTile(
                    icon: "calendar",
                    label: "Tenure",
                    value: "\(dbDetails?.tenure_months ?? 0) mo"
                )
                infoTile(
                    icon: "hourglass.tophalf.filled",
                    label: "Remaining",
                    value: "\(remainingMonths) mo"
                )
                infoTile(
                    icon: "percent",
                    label: "Rate p.a.",
                    value: String(format: "%.2f%%", dbDetails?.interest_rate ?? loan.interestRate)
                )
            }
            .padding(.vertical, 4)
            
            Divider()
                .background(Color.border.opacity(0.5))
            
            // Row 4: Repayment Progress
            VStack(alignment: .leading, spacing: 8) {
                Text("Repayment Progress")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.textSecondary)
                
                HStack {
                    Text("\(remainingMonths) EMIs left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Spacer()
                    Text("\(Int(paidPercent * 100))% repaid")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#2D8B4E"))
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(hex: "#E5EFE9"))
                            .frame(height: 8)
                        Capsule()
                            .fill(Color(hex: "#2D8B4E"))
                            .frame(width: geo.size.width * CGFloat(min(max(paidPercent, 0), 1)), height: 8)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.black.opacity(0.03), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.02), radius: 10, x: 0, y: 4)
    }

    // MARK: - Info Tile helper
    @ViewBuilder
    private func infoTile(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "#2D8B4E"))
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.textPrimary)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(hex: "#F0F7F3"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "#2D8B4E").opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Sub-tab Picker
    private var subTabPicker: some View {
        HStack(spacing: 4) {
            ForEach(DetailTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(selectedTab == tab ? Color(hex: "#2D8B4E") : .textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(
                            Group {
                                if selectedTab == tab {
                                    Color.white
                                        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                                } else {
                                    Color.clear
                                }
                            }
                            .clipShape(Capsule())
                        )
                }
            }
        }
        .padding(4)
        .background(Color(hex: "#E5EFE9"))
        .clipShape(Capsule())
    }

    // MARK: - Tab Content
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .timeline:
            timelineContent
        case .documents:
            documentsContent
        case .schedule:
            scheduleContent
        }
    }

    // MARK: - Timeline Content
    private var timelineContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(timelineSteps.enumerated()), id: \.element.id) { index, step in
                TimelineNodeView(step: step, isLast: index == timelineSteps.count - 1)
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.black.opacity(0.03), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.01), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Documents Content
    private var documentsContent: some View {
        VStack(spacing: 12) {
            if documentItems.isEmpty {
                Text("No documents required or uploaded for this loan.")
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
                    .padding(.vertical, 24)
            } else {
                ForEach(documentItems) { doc in
                    Button {
                        if doc.storagePath != nil {
                            Task {
                                await downloadDocument(doc)
                            }
                        }
                    } label: {
                        DocumentRowView(doc: doc, isDownloading: isDownloadingId == doc.id)
                    }
                    .buttonStyle(.plain)
                    .disabled(isDownloadingId != nil)
                }
            }
        }
    }
    
    // MARK: - Schedule Content
    private var scheduleContent: some View {
        VStack(spacing: 12) {
            if emiScheduleItems.isEmpty {
                Text("No EMI schedule recorded for this loan.")
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
                    .padding(.vertical, 24)
            } else {
                ForEach(emiScheduleItems) { emi in
                    EMIScheduleRowView(emi: emi)
                }
                
                NavigationLink {
                    EMIScheduleView(loanId: loan.id)
                } label: {
                    HStack {
                        Spacer()
                        Label("View Complete Schedule & Pay", systemImage: "calendar")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.accentGreen)
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: Corner.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: Corner.md)
                            .stroke(Color.border, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, Spacing.sm)
            }
        }
    }

    // MARK: - Bottom Pay Bar
    private var bottomPayBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Outstanding ₹\(formatIndian(loan.remainingAmount))")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                Text("Check schedule for exact payable amount")
                    .font(.caption2)
                    .foregroundColor(.textSecondary)
            }
            Spacer()
            NavigationLink {
                EMIScheduleView(loanId: loan.id)
            } label: {
                Text("Pay EMI")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentGreen)
                    .clipShape(Capsule())
            }
        }
        .padding(Spacing.lg)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Corner.xl))
        .overlay(
            RoundedRectangle(cornerRadius: Corner.xl)
                .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: -4)
        .padding(.horizontal, Spacing.xl)
        .padding(.bottom, Spacing.sm)
    }

    // MARK: - Computed Properties
    private var remainingMonths: Int {
        emiScheduleItems.filter { $0.status != .paid }.count
    }
    
    private var paidPercent: Double {
        let total = emiScheduleItems.count
        guard total > 0 else { return loan.paidPercent }
        let paid = emiScheduleItems.filter { $0.status == .paid }.count
        return Double(paid) / Double(total)
    }
    
    private var emiDayString: String {
        func ordinalSuffix(for day: Int) -> String {
            if (11...13).contains(day % 100) {
                return "\(day)th"
            }
            switch day % 10 {
            case 1:  return "\(day)st"
            case 2:  return "\(day)nd"
            case 3:  return "\(day)rd"
            default: return "\(day)th"
            }
        }
        
        var targetDate: Date? = nil
        if let nextDueStr = loan.nextDueDate, let nextDueDate = LoansListView.parseDateString(nextDueStr) {
            targetDate = nextDueDate
        } else if let dbDetails = dbDetails, let firstEmiStr = dbDetails.first_emi_date, let firstEmiDate = LoansListView.parseDateString(firstEmiStr) {
            targetDate = firstEmiDate
        }
        
        if let date = targetDate {
            let day = Calendar.current.component(.day, from: date)
            return "\(ordinalSuffix(for: day)) of every month"
        }
        return "15th of every month"
    }

    // MARK: - Helpers
    private func formatIndian(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

    private func downloadDocument(_ doc: DocumentItem) async {
        guard let path = doc.storagePath else { return }
        isDownloadingId = doc.id
        do {
            let url = try await DocumentDownloadService.shared.downloadDocument(storagePath: path, fileName: doc.name)
            downloadedURL = url
            showShareSheet = true
        } catch {
            print("Failed to download doc: \(error)")
        }
        isDownloadingId = nil
    }

    private static func displayDate(_ value: String) -> String {
        guard let date = Formatter.iso8601.date(from: value) else { return value }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    // MARK: - Realtime Subscriptions
    private func subscribeToRealtimeUpdates() {
        guard realtimeChannels.isEmpty else { return } // already subscribed
        guard let applicationId = dbDetails?.application?.id else { return }
        let loanIdStr = loan.id.uuidString
        let appIdStr  = applicationId.uuidString

        // --- EMI Schedule channel ---
        let emiChannel = SupabaseManager.shared.client.realtimeV2
            .channel("loan-detail-emi-\(loanIdStr)")
        Task {
            let changes = await emiChannel.postgresChange(
                AnyAction.self, schema: "public", table: "emi_schedule",
                filter: "loan_id=eq.\(loanIdStr)"
            )
            await emiChannel.subscribe()
            for await _ in changes { await loadRelatedData(silent: true) }
        }
        realtimeChannels.append(emiChannel)

        // --- Documents channel ---
        let docChannel = SupabaseManager.shared.client.realtimeV2
            .channel("loan-detail-docs-\(appIdStr)")
        Task {
            let changes = await docChannel.postgresChange(
                AnyAction.self, schema: "public", table: "documents",
                filter: "application_id=eq.\(appIdStr)"
            )
            await docChannel.subscribe()
            for await _ in changes { await loadRelatedData(silent: true) }
        }
        realtimeChannels.append(docChannel)

        // --- Approval history channel ---
        let historyChannel = SupabaseManager.shared.client.realtimeV2
            .channel("loan-detail-history-\(appIdStr)")
        Task {
            let changes = await historyChannel.postgresChange(
                AnyAction.self, schema: "public", table: "approval_history",
                filter: "application_id=eq.\(appIdStr)"
            )
            await historyChannel.subscribe()
            for await _ in changes { await loadRelatedData(silent: true) }
        }
        realtimeChannels.append(historyChannel)

        // --- Payments channel ---
        let payChannel = SupabaseManager.shared.client.realtimeV2
            .channel("loan-detail-pay-\(loanIdStr)")
        Task {
            let changes = await payChannel.postgresChange(
                AnyAction.self, schema: "public", table: "payments",
                filter: "loan_id=eq.\(loanIdStr)"
            )
            await payChannel.subscribe()
            for await _ in changes { await loadRelatedData(silent: true) }
        }
        realtimeChannels.append(payChannel)
    }

    // Load related data from Supabase
    // Pass silent:true for realtime-triggered refreshes to avoid spinner flash
    private func loadRelatedData(silent: Bool = false) async {
        if !silent { isLoading = true }
        loadError = nil
        
        do {
            // 1. Fetch Loan Details
            let rows: [LoanDetailsFetch] = try await SupabaseManager.shared.client.from("loans")
                .select("""
                    tenure_months, principal_amount, total_payable, disbursement_date, first_emi_date, closed_at, interest_rate, interest_type,
                    loan_product:loan_products(required_documents),
                    application:loan_applications(
                        id, created_at, submitted_at, decided_at, requested_tenure_months
                    )
                """)
                .eq("id", value: loan.id)
                .execute()
                .value

            guard let details = rows.first else {
                throw LoanDetailLoadError.loanNotFound
            }
            
            self.dbDetails = details
            
            // 2. Fetch payments
            struct PaymentFetch: Decodable {
                let id: UUID
                let amount_paid: Double
                let payment_mode: String
                let razorpay_payment_id: String?
                let upi_transaction_id: String?
                let cheque_number: String?
                let bank_reference: String?
                let initiated_at: String
            }
            
            let payments: [PaymentFetch] = try await SupabaseManager.shared.client.from("payments")
                .select("id, amount_paid, payment_mode, razorpay_payment_id, upi_transaction_id, cheque_number, bank_reference, initiated_at")
                .eq("loan_id", value: loan.id)
                .order("initiated_at", ascending: false)
                .execute()
                .value
            
            self.paymentHistory = payments.map {
                LoanPaymentRow(
                    id: $0.id,
                    date: Self.displayDate($0.initiated_at),
                    amount: $0.amount_paid,
                    mode: $0.payment_mode.replacingOccurrences(of: "_", with: " ").capitalized,
                    reference: $0.razorpay_payment_id ?? $0.upi_transaction_id ?? $0.cheque_number ?? $0.bank_reference ?? "Pending"
                )
            }
            
            // 3. Fetch EMI schedule
            struct EMIFetch: Decodable {
                let id: UUID
                let installment_number: Int
                let due_date: String
                let total_emi: Double
                let principal_component: Double
                let interest_component: Double
                let penalty_amount: Double
                let status: String
                let paid_date: String?
            }
            
            let schedule: [EMIFetch] = try await SupabaseManager.shared.client
                .from("emi_schedule")
                .select()
                .eq("loan_id", value: loan.id)
                .order("installment_number", ascending: true)
                .execute()
                .value
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            
            self.emiScheduleItems = schedule.map { s in
                let dueDate = formatter.date(from: String(s.due_date.prefix(10))) ?? Date()
                let paidDate = s.paid_date.flatMap { formatter.date(from: String($0.prefix(10))) }
                
                let status: EMIDetailStatus
                switch s.status.lowercased() {
                case "paid": status = .paid
                case "overdue": status = .overdue
                case "due", "partially_paid": status = .unpaid
                default: status = .upcoming
                }
                
                return EMIDetailRowItem(
                    id: s.id,
                    installmentNumber: s.installment_number,
                    dueDate: dueDate,
                    amount: s.total_emi + s.penalty_amount,
                    principal: s.principal_component,
                    interest: s.interest_component,
                    penalty: s.penalty_amount,
                    status: status,
                    paidDate: paidDate
                )
            }
            
            // 4. Fetch uploaded documents
            struct DocumentFetch: Decodable {
                let id: UUID
                let document_type: String
                let storage_path: String?
                let is_verified: Bool
                let rejection_reason: String?
            }
            
            let uploadedDocs: [DocumentFetch]
            if let applicationId = details.application?.id {
                uploadedDocs = try await SupabaseManager.shared.client.from("documents")
                    .select("id, document_type, storage_path, is_verified, rejection_reason")
                    .eq("application_id", value: applicationId)
                    .execute()
                    .value
            } else {
                uploadedDocs = []
            }
            
            // Merge required and uploaded documents
            let requirements = details.loan_product.required_documents ?? [
                DocumentRequirement(name: "Aadhaar Card", isMandatory: true),
                DocumentRequirement(name: "PAN Card", isMandatory: true),
                DocumentRequirement(name: "Salary Slip", isMandatory: true)
            ]
            
            var docItems: [DocumentItem] = []
            var matchedUploadedIds = Set<UUID>()
            
            for req in requirements {
                if let uploaded = uploadedDocs.first(where: { $0.document_type.lowercased() == req.name.lowercased() }) {
                    matchedUploadedIds.insert(uploaded.id)
                    let status: DocumentItem.DocumentStatus
                    if let reason = uploaded.rejection_reason, !reason.isEmpty {
                        status = .rejected
                    } else if uploaded.is_verified {
                        status = .uploaded
                    } else {
                        status = .pending
                    }
                    docItems.append(DocumentItem(
                        id: uploaded.id,
                        name: uploaded.document_type,
                        isMandatory: req.isMandatory,
                        status: status,
                        storagePath: uploaded.storage_path
                    ))
                } else {
                    docItems.append(DocumentItem(
                        id: UUID(),
                        name: req.name,
                        isMandatory: req.isMandatory,
                        status: .missing,
                        storagePath: nil
                    ))
                }
            }
            
            for uploaded in uploadedDocs where !matchedUploadedIds.contains(uploaded.id) {
                let status: DocumentItem.DocumentStatus
                if let reason = uploaded.rejection_reason, !reason.isEmpty {
                    status = .rejected
                } else if uploaded.is_verified {
                    status = .uploaded
                } else {
                    status = .pending
                }
                docItems.append(DocumentItem(
                    id: uploaded.id,
                    name: uploaded.document_type,
                    isMandatory: false,
                    status: status,
                    storagePath: uploaded.storage_path
                ))
            }
            
            self.documentItems = docItems
            
            // 5. Fetch approval history for timeline
            struct ApprovalHistoryFetch: Decodable {
                let action: String
                let to_status: String
                let actioned_at: String
            }
            
            let history: [ApprovalHistoryFetch]
            if let applicationId = details.application?.id {
                history = try await SupabaseManager.shared.client.from("approval_history")
                    .select("action, to_status, actioned_at")
                    .eq("application_id", value: applicationId)
                    .order("actioned_at", ascending: true)
                    .execute()
                    .value
            } else {
                history = []
            }
            
            // Build dynamic timeline steps
            var steps: [TimelineStep] = []
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "d MMMM yyyy"
            
            func parseAndFormatDate(_ dateStr: String) -> String? {
                if let d = LoansListView.parseDateString(dateStr) {
                    return displayFormatter.string(from: d)
                }
                return nil
            }
            
            // Step 1: Applied
            let appliedDate = history.first(where: { $0.action.lowercased() == "submit" })?.actioned_at
                ?? details.application?.submitted_at
                ?? details.application?.created_at
                ?? details.disbursement_date
                ?? details.first_emi_date
                ?? Date().ISO8601Format()
            steps.append(TimelineStep(
                title: "Applied",
                subtitle: "Application submitted successfully",
                date: parseAndFormatDate(appliedDate),
                status: .completed
            ))
            
            // Step 2: Under Review
            let reviewItem = history.first(where: { $0.to_status.lowercased() == "under_review" || $0.action.lowercased() == "review" })
            let isUnderReview = reviewItem != nil || loan.status.lowercased() != "draft"
            let reviewDate = reviewItem?.actioned_at ?? details.application?.submitted_at
            steps.append(TimelineStep(
                title: "Under Review",
                subtitle: "Documents and credit check under review",
                date: reviewDate.flatMap(parseAndFormatDate),
                status: isUnderReview ? .completed : .upcoming
            ))
            
            // Step 3: Approved
            let approvedItem = history.first(where: { $0.to_status.lowercased() == "approved" || $0.action.lowercased() == "approve" })
            let isApproved = approvedItem != nil || details.disbursement_date != nil || ["active", "closed"].contains(loan.status.lowercased())
            let approveDate = approvedItem?.actioned_at ?? details.application?.decided_at
            steps.append(TimelineStep(
                title: "Approved",
                subtitle: "Loan application approved",
                date: approveDate.flatMap(parseAndFormatDate),
                status: isApproved ? .completed : (isUnderReview ? .inProgress : .upcoming)
            ))
            
            // Step 4: Disbursed
            let disbursedItem = history.first(where: { $0.to_status.lowercased() == "disbursed" || $0.action.lowercased() == "disburse" })
            let isDisbursed = disbursedItem != nil || details.disbursement_date != nil || ["active", "closed"].contains(loan.status.lowercased())
            let disburseDate = disbursedItem?.actioned_at ?? details.disbursement_date
            steps.append(TimelineStep(
                title: "Disbursed",
                subtitle: "Funds transferred to your bank account",
                date: disburseDate.flatMap(parseAndFormatDate),
                status: isDisbursed ? .completed : (isApproved ? .inProgress : .upcoming)
            ))
            
            // Step 5: Closed
            let isClosed = loan.status.lowercased() == "closed"
            let closeDate = details.closed_at
            steps.append(TimelineStep(
                title: "Closed",
                subtitle: isClosed ? "Loan fully repaid and closed" : "Loan repayment ongoing",
                date: closeDate.flatMap(parseAndFormatDate),
                status: isClosed ? .completed : .upcoming
            ))
            
            self.timelineSteps = steps
            
        } catch {
            print("Failed to load details:", error)
            self.loadError = error.localizedDescription
        }
        
        isLoading = false
    }
}

// MARK: - Legacy / Helper Structs
private struct LoanPaymentRow: Identifiable {
    let id: UUID
    let date: String
    let amount: Double
    let mode: String
    let reference: String
}

private struct LoanDocumentRow: Identifiable {
    let id: UUID
    let name: String
    let storagePath: String?
}

// MARK: - Decodable response structs for Supabase joins
struct ApplicationFetch: Decodable {
    let id: UUID
    let created_at: String
    let submitted_at: String?
    let decided_at: String?
    let requested_tenure_months: Int
}

struct ProductFetch: Decodable {
    let required_documents: [DocumentRequirement]?

    init(required_documents: [DocumentRequirement]?) {
        self.required_documents = required_documents
    }
}

struct LoanDetailsFetch: Decodable {
    let tenure_months: Int
    let principal_amount: Double
    let total_payable: Double
    let disbursement_date: String?
    let first_emi_date: String?
    let closed_at: String?
    let interest_rate: Double
    let interest_type: String
    let loan_product: ProductFetch
    let application: ApplicationFetch?

    enum CodingKeys: String, CodingKey {
        case tenure_months
        case principal_amount
        case total_payable
        case disbursement_date
        case first_emi_date
        case closed_at
        case interest_rate
        case interest_type
        case loan_product
        case application
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        tenure_months = try container.decode(Int.self, forKey: .tenure_months)
        principal_amount = try container.decode(Double.self, forKey: .principal_amount)
        total_payable = try container.decode(Double.self, forKey: .total_payable)
        disbursement_date = try container.decodeIfPresent(String.self, forKey: .disbursement_date)
        first_emi_date = try container.decodeIfPresent(String.self, forKey: .first_emi_date)
        closed_at = try container.decodeIfPresent(String.self, forKey: .closed_at)
        interest_rate = try container.decode(Double.self, forKey: .interest_rate)
        interest_type = try container.decode(String.self, forKey: .interest_type)

        if let product = try? container.decode(ProductFetch.self, forKey: .loan_product) {
            loan_product = product
        } else if let products = try? container.decode([ProductFetch].self, forKey: .loan_product) {
            loan_product = products.first ?? ProductFetch(required_documents: nil)
        } else {
            loan_product = ProductFetch(required_documents: nil)
        }

        if let joinedApplication = try? container.decodeIfPresent(ApplicationFetch.self, forKey: .application) {
            application = joinedApplication
        } else if let joinedApplications = try? container.decodeIfPresent([ApplicationFetch].self, forKey: .application) {
            application = joinedApplications.first
        } else {
            application = nil
        }
    }
}

private enum LoanDetailLoadError: LocalizedError {
    case loanNotFound

    var errorDescription: String? {
        switch self {
        case .loanNotFound:
            return "No details were found for this loan."
        }
    }
}

// MARK: - New Models for UI redone
struct TimelineStep: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let date: String?
    let status: StepStatus
    
    enum StepStatus {
        case completed
        case inProgress
        case upcoming
    }
}

struct DocumentItem: Identifiable, Hashable {
    let id: UUID
    let name: String
    let isMandatory: Bool
    let status: DocumentStatus
    let storagePath: String?
    
    enum DocumentStatus: String {
        case uploaded = "Uploaded"
        case missing = "Required"
        case pending = "Pending Verification"
        case rejected = "Rejected"
    }
}

struct EMIDetailRowItem: Identifiable, Hashable {
    let id: UUID
    let installmentNumber: Int
    let dueDate: Date
    let amount: Double
    let principal: Double
    let interest: Double
    let penalty: Double
    let status: EMIDetailStatus
    let paidDate: Date?
}

enum EMIDetailStatus: String {
    case paid = "Paid"
    case unpaid = "Unpaid"
    case upcoming = "Upcoming"
    case overdue = "Overdue"
}

// MARK: - Timeline Node View
struct TimelineNodeView: View {
    let step: TimelineStep
    let isLast: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 0) {
                // Node Icon
                if step.status == .completed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "#2D8B4E"))
                        .background(Circle().fill(Color.white))
                } else if step.status == .inProgress {
                    Circle()
                        .stroke(Color(hex: "#2D8B4E"), lineWidth: 3)
                        .background(Circle().fill(Color.white))
                        .frame(width: 24, height: 24)
                } else {
                    Circle()
                        .fill(Color(hex: "#D0DFD5"))
                        .frame(width: 24, height: 24)
                }
                
                // Line connecting nodes
                if !isLast {
                    Rectangle()
                        .fill(step.status == .completed ? Color(hex: "#2D8B4E") : Color(hex: "#D0DFD5"))
                        .frame(width: 2)
                        .frame(minHeight: 40)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                
                if let subtitle = step.subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.textSecondary)
                }
                
                if let date = step.date {
                    Text(date)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#2D8B4E"))
                        .padding(.top, 2)
                }
            }
            .padding(.bottom, isLast ? 0 : 20)
            
            Spacer()
        }
    }
}

// MARK: - Document Row View
struct DocumentRowView: View {
    let doc: DocumentItem
    let isDownloading: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(statusColor.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(statusColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(doc.name)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.textPrimary)
                
                Text(doc.isMandatory ? "Required" : "Optional")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
            
            if isDownloading {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                statusBadge
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(0.03), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.01), radius: 5, x: 0, y: 2)
    }
    
    private var iconName: String {
        let n = doc.name.lowercased()
        if n.contains("aadhaar") || n.contains("aadhar") || n.contains("national id") {
            return "person.text.rectangle.fill"
        } else if n.contains("pan") || n.contains("tax") {
            return "creditcard.fill"
        } else if n.contains("salary") || n.contains("pay") || n.contains("income") {
            return "doc.text.fill"
        } else if n.contains("bank") || n.contains("statement") {
            return "building.columns.fill"
        } else if n.contains("photo") || n.contains("signature") {
            return "photo.fill"
        }
        return "doc.fill"
    }
    
    private var statusColor: Color {
        switch doc.status {
        case .uploaded: return Color(hex: "#2D8B4E")
        case .pending:  return .orange
        case .rejected: return .red
        case .missing:  return .gray
        }
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        switch doc.status {
        case .uploaded:
            if doc.storagePath != nil {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Color(hex: "#2D8B4E"))
            } else {
                Text("Uploaded")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: "#2D8B4E"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#2D8B4E").opacity(0.1))
                    .clipShape(Capsule())
            }
        case .pending:
            Text("Pending")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .clipShape(Capsule())
        case .rejected:
            Text("Rejected")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.red)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.1))
                .clipShape(Capsule())
        case .missing:
            Text("Missing")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.1))
                .clipShape(Capsule())
        }
    }
}

// MARK: - EMI Schedule Row View
struct EMIScheduleRowView: View {
    let emi: EMIDetailRowItem
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("EMI #\(emi.installmentNumber)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                        
                        Text(formatDate(emi.dueDate))
                            .font(.system(size: 13))
                            .foregroundColor(.textSecondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("₹\(formatIndian(emi.amount))")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                        
                        statusBadge(for: emi.status)
                    }
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(16)
                .background(Color.white)
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(spacing: 10) {
                    Divider()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 2)
                    
                    HStack {
                        Text("Principal Component")
                            .font(.system(size: 13))
                            .foregroundColor(.textSecondary)
                        Spacer()
                        Text("₹\(formatIndian(emi.principal))")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.textPrimary)
                    }
                    .padding(.horizontal, 16)
                    
                    HStack {
                        Text("Interest Component")
                            .font(.system(size: 13))
                            .foregroundColor(.textSecondary)
                        Spacer()
                        Text("₹\(formatIndian(emi.interest))")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.textPrimary)
                    }
                    .padding(.horizontal, 16)
                    
                    if emi.penalty > 0 {
                        HStack {
                            Text("Late Payment Penalty")
                                .font(.system(size: 13))
                                .foregroundColor(.red)
                            Spacer()
                            Text("₹\(formatIndian(emi.penalty))")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    if let paidDate = emi.paidDate {
                        HStack {
                            Text("Paid On")
                                .font(.system(size: 13))
                                .foregroundColor(.textSecondary)
                            Spacer()
                            Text(formatDate(paidDate))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.textPrimary)
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 16)
                .background(Color(hex: "#F9FBF9"))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(0.03), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.01), radius: 5, x: 0, y: 2)
    }
    
    private func statusBadge(for status: EMIDetailStatus) -> some View {
        let (text, fg, bg): (String, Color, Color) = {
            switch status {
            case .paid:
                return ("Paid", Color(hex: "#2D8B4E"), Color(hex: "#2D8B4E").opacity(0.1))
            case .unpaid:
                return ("Unpaid", .red, .red.opacity(0.1))
            case .overdue:
                return ("Overdue", .red, .red.opacity(0.1))
            case .upcoming:
                return ("Upcoming", .blue, .blue.opacity(0.1))
            }
        }()
        
        return Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(fg)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(bg)
            .clipShape(Capsule())
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
    
    private func formatIndian(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
}
