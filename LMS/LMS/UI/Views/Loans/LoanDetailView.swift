import SwiftUI
import Supabase

/// Loan Detail View (design.md §8.5)
/// Hero area with gradient + amount, stat cards, sub-tabs, bottom PAY EMI bar.
struct LoanDetailView: View {
    let loan: LoanListItem
    @State private var selectedTab: DetailTab = .emi
    @State private var paymentHistory: [LoanPaymentRow] = []
    @State private var loanDocuments: [LoanDocumentRow] = []
    @State private var emiList: [EMIDetailLocal] = []
    @State private var loadError: String?
    
    // Document Download State
    @State private var isDownloadingId: UUID? = nil
    @State private var downloadedURL: URL? = nil
    @State private var showShareSheet = false

    enum DetailTab: String, CaseIterable {
        case emi = "EMI"
        case payments = "Payments"
        case documents = "Docs"
        case info = "Info"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Spacing.xxl) {
                    // MARK: - Hero Section
                    heroSection

                    // MARK: - Stat Cards
                    statCardsRow

                    // MARK: - Sub-tabs
                    subTabPicker

                    // MARK: - Tab Content
                    tabContent
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, 140)
            }
            .background(Color.appBackground.ignoresSafeArea())

            // MARK: - Bottom Glass Bar (PAY EMI)
            if loan.status.lowercased() == "active" {
                bottomPayBar
            }
        }
        .navigationTitle(loan.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadRelatedData() }
        .sheet(isPresented: $showShareSheet) {
            if let url = downloadedURL {
                ShareSheet(items: [url])
            }
        }
    }

    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Loan Amount")
                .font(.label)
                .foregroundColor(.textSecondary)

            AmountDisplay(amount: loan.amount, style: .large)

            HStack(spacing: Spacing.sm) {
                Text(loan.loanNumber)
                    .font(.caption2)
                    .foregroundColor(.textTertiary)
                StatusBadge(status: loan.status)
            }

            Text("Disbursed: \(loan.disbursedDate)")
                .font(.caption2)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.xl)
        .background(
            LinearGradient(
                colors: [Color.gradientBeigeStart, Color.gradientBeigeEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: Corner.xl))
        .overlay(
            RoundedRectangle(cornerRadius: Corner.xl)
                .stroke(Color.border, lineWidth: 0.5)
        )
    }

    // MARK: - Stat Cards
    private var statCardsRow: some View {
        HStack(spacing: Spacing.md) {
            StatCard("Paid", value: "₹\(formatK(loan.paidAmount))", backgroundColor: .accentGreenBg)
            StatCard("Remaining", value: "₹\(formatK(loan.remainingAmount))", backgroundColor: .accentAmberBg)
            StatCard("Rate", value: String(format: "%.1f%%", loan.interestRate), backgroundColor: .surfaceMuted)
        }
    }

    // MARK: - Sub-tab Picker
    private var subTabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(response: 0.3)) { selectedTab = tab }
                    } label: {
                        Text(tab.rawValue)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(selectedTab == tab ? .white : .textPrimary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(selectedTab == tab ? Color.accentDark : Color.surfaceMuted)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    // MARK: - Tab Content
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .emi:
            emiScheduleContent
        case .payments:
            paymentsContent
        case .documents:
            documentsContent
        case .info:
            infoContent
        }
    }

    // MARK: - EMI Schedule
    private var emiScheduleContent: some View {
        VStack(spacing: Spacing.md) {
            if emiList.isEmpty {
                Text("No EMI schedule recorded.").foregroundColor(.textSecondary)
            } else {
                ForEach(emiList) { emi in
                    emiRow(emi)
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

    private func emiRow(_ emi: EMIDetailLocal) -> some View {
        let isPaid = emi.status == .paid
        let isOverdue = emi.status == .overdue
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(emi.date)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(isPaid ? Color.accentGreen : (isOverdue ? Color.accentRed : Color.accentAmber))
                        .frame(width: 6, height: 6)
                    Text(isPaid ? "Paid" : (isOverdue ? "Overdue" : "Upcoming"))
                        .font(.badge)
                        .foregroundColor(isPaid ? .accentGreen : (isOverdue ? .accentRed : .accentAmber))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isPaid ? Color.accentGreenBg : (isOverdue ? Color.accentRedBg : Color.accentAmberBg))
                .clipShape(Capsule())
            }
            
            VStack(spacing: 6) {
                HStack {
                    Text("Principal")
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                    Spacer()
                    Text("₹\(formatIndian(emi.principal))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textPrimary)
                }
                
                HStack {
                    Text("Interest")
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                    Spacer()
                    Text("₹\(formatIndian(emi.interest))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textPrimary)
                }
                
                if emi.penalty > 0 {
                    HStack {
                        Text("Penalty")
                            .font(.caption2)
                            .foregroundColor(.accentRed)
                        Spacer()
                        Text("₹\(formatIndian(emi.penalty))")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.accentRed)
                    }
                }
            }
            
            Divider()
            
            HStack {
                Text("Total EMI")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Spacer()
                Text("₹\(formatIndian(emi.amount))")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Corner.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Corner.lg)
                .stroke(Color.border, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.02), radius: 8, x: 0, y: 3)
        .opacity(isPaid ? 0.7 : 1.0)
    }

    // MARK: - Payments
    private var paymentsContent: some View {
        LazyVStack(spacing: Spacing.md) {
            if paymentHistory.isEmpty {
                Text("No payments recorded.").foregroundColor(.textSecondary)
            } else {
                ForEach(paymentHistory) { payment in
                    paymentRow(date: payment.date, amount: payment.amount, mode: payment.mode, ref: payment.reference)
                }
            }
        }
    }

    private func paymentRow(date: String, amount: Double, mode: String, ref: String) -> some View {
        let isCash = mode.lowercased() == "cash" || mode.lowercased() == "cheque"
        
        return HStack {
            Image(systemName: paymentIcon(for: mode))
                .foregroundColor(isCash ? .accentAmber : .accentGreen)
                .frame(width: 36, height: 36)
                .background(isCash ? Color.accentAmberBg : Color.accentGreenBg)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("₹\(formatIndian(amount))")
                    .font(.bodyLarge)
                    .foregroundColor(.textPrimary)
                HStack(spacing: 4) {
                    Text(date)
                    Text("•")
                    Text(mode)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isCash ? Color.accentAmberBg : Color.accentGreenBg)
                        .foregroundColor(isCash ? .accentAmber : .accentGreen)
                        .clipShape(Capsule())
                }
                .font(.caption2)
                .foregroundColor(.textSecondary)
            }

            Spacer()

            Text(ref)
                .font(.caption2)
                .foregroundColor(.textTertiary)
        }
        .padding(Spacing.lg)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Corner.md))
        .overlay(
            RoundedRectangle(cornerRadius: Corner.md)
                .stroke(Color.border, lineWidth: 0.5)
        )
    }

    // MARK: - Documents
    private var documentsContent: some View {
        VStack(spacing: Spacing.md) {
            if loanDocuments.isEmpty {
                Text("No loan documents are available.").foregroundColor(.textSecondary)
            } else {
                ForEach(loanDocuments) { document in
                    Button {
                        if document.storagePath != nil {
                            Task { await downloadDocument(document) }
                        }
                    } label: {
                        documentRow(document: document)
                    }
                    .buttonStyle(.plain)
                    .disabled(isDownloadingId != nil)
                }
            }
        }
    }

    private func documentRow(document: LoanDocumentRow) -> some View {
        let isDownloading = isDownloadingId == document.id
        
        return HStack {
            Image(systemName: "doc.fill")
                .foregroundColor(.accentBeigeDk)
            Text(document.name)
                .font(.bodyRegular)
                .foregroundColor(.textPrimary)
            Spacer()
            
            if isDownloading {
                ProgressView()
                    .scaleEffect(0.8)
            } else if document.storagePath != nil {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.accentGreen)
                    .font(.system(size: 20))
            } else {
                Text("Pending")
                    .font(.badge)
                    .foregroundColor(.accentAmber)
            }
        }
        .padding(Spacing.lg)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Corner.md))
        .overlay(
            RoundedRectangle(cornerRadius: Corner.md)
                .stroke(Color.border, lineWidth: 0.5)
        )
    }

    private func downloadDocument(_ doc: LoanDocumentRow) async {
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

    // MARK: - Info
    private var infoContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            infoRow("Loan Type", value: loan.loanType.capitalized)
            infoRow("Interest Rate", value: String(format: "%.2f%%", loan.interestRate))
            infoRow("Disbursed", value: loan.disbursedDate)
            infoRow("Principal", value: "₹\(formatIndian(loan.amount))")
        }
        .padding(Spacing.lg)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Corner.md))
        .overlay(
            RoundedRectangle(cornerRadius: Corner.md)
                .stroke(Color.border, lineWidth: 0.5)
        )
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.bodyRegular)
                .foregroundColor(.textSecondary)
            Spacer()
            Text(value)
                .font(.bodyLarge)
                .foregroundColor(.textPrimary)
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

    // MARK: - Helpers
    private func formatIndian(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

    private func formatK(_ value: Double) -> String {
        if value >= 100000 {
            return String(format: "%.1fL", value / 100000)
        } else if value >= 1000 {
            return String(format: "%.1fK", value / 1000)
        }
        return formatIndian(value)
    }

    private func paymentIcon(for mode: String) -> String {
        switch mode.lowercased() {
        case "upi": return "indianrupeesign.circle"
        case "razorpay": return "creditcard"
        case "cheque": return "doc.text"
        case "neft", "rtgs": return "building.columns"
        case "auto debit": return "arrow.triangle.2.circlepath"
        default: return "banknote"
        }
    }

    private func loadRelatedData() async {
        do {
            struct PaymentFetch: Decodable {
                let id: UUID; let amount_paid: Double; let payment_mode: String
                let razorpay_payment_id: String?; let upi_transaction_id: String?
                let cheque_number: String?; let bank_reference: String?; let initiated_at: String
            }
            let payments: [PaymentFetch] = try await SupabaseManager.shared.client.from("payments")
                .select("id, amount_paid, payment_mode, razorpay_payment_id, upi_transaction_id, cheque_number, bank_reference, initiated_at")
                .eq("loan_id", value: loan.id).order("initiated_at", ascending: false).execute().value
            paymentHistory = payments.map {
                LoanPaymentRow(
                    id: $0.id, date: Self.displayDate($0.initiated_at), amount: $0.amount_paid,
                    mode: $0.payment_mode.replacingOccurrences(of: "_", with: " ").capitalized,
                    reference: $0.razorpay_payment_id ?? $0.upi_transaction_id ?? $0.cheque_number ?? $0.bank_reference ?? "Pending"
                )
            }

            struct LoanApplicationRef: Decodable { let application_id: UUID }
            let ref: LoanApplicationRef = try await SupabaseManager.shared.client.from("loans")
                .select("application_id").eq("id", value: loan.id).single().execute().value
            struct DocumentFetch: Decodable { let id: UUID; let document_type: String; let storage_path: String? }
            let documents: [DocumentFetch] = try await SupabaseManager.shared.client.from("documents")
                .select("id, document_type, storage_path").eq("application_id", value: ref.application_id).execute().value
            loanDocuments = documents.map { LoanDocumentRow(id: $0.id, name: $0.document_type, storagePath: $0.storage_path) }
            
            // Fetch EMI schedule
            struct EMIFetch: Decodable {
                let id: UUID
                let due_date: String
                let total_emi: Double
                let principal_component: Double
                let interest_component: Double
                let penalty_amount: Double
                let status: String
            }
            let schedule: [EMIFetch] = try await SupabaseManager.shared.client
                .from("emi_schedule")
                .select()
                .eq("loan_id", value: loan.id)
                .order("due_date", ascending: true)
                .execute()
                .value
            
            if !schedule.isEmpty {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let displayFormatter = DateFormatter()
                displayFormatter.dateFormat = "MMM yyyy"
                
                emiList = schedule.map { s in
                    let dateStr: String
                    if let d = formatter.date(from: String(s.due_date.prefix(10))) {
                        dateStr = displayFormatter.string(from: d)
                    } else {
                        dateStr = s.due_date
                    }
                    
                    let emiStatus: EMIDetailLocal.EMIStatus
                    if s.status == "paid" {
                        emiStatus = .paid
                    } else if s.status == "overdue" {
                        emiStatus = .overdue
                    } else {
                        emiStatus = .upcoming
                    }
                    
                    return EMIDetailLocal(
                        id: s.id, date: dateStr, amount: s.total_emi + s.penalty_amount,
                        principal: s.principal_component, interest: s.interest_component,
                        penalty: s.penalty_amount, status: emiStatus
                    )
                }
            } else {
                emiList = getDummyEMIs(for: loan.id)
            }
        } catch {
            loadError = error.localizedDescription
            emiList = getDummyEMIs(for: loan.id)
        }
    }

    private static func displayDate(_ value: String) -> String {
        guard let date = Formatter.iso8601.date(from: value) else { return value }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
    
    private func getDummyEMIs(for loanId: UUID) -> [EMIDetailLocal] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        
        let now = Date()
        var list: [EMIDetailLocal] = []
        
        // Match dummy IDs from DB schema if any or create generic
        let isHome = loan.loanType.lowercased() == "home"
        let isVehicle = loan.loanType.lowercased() == "vehicle"
        let isPersonal = loan.loanType.lowercased() == "personal"
        
        let monthsCount = isPersonal ? 3 : 6
        let startOffset = isPersonal ? -2 : -3
        
        for i in startOffset...(monthsCount + startOffset) {
            let dueDate = Calendar.current.date(byAdding: .month, value: i, to: now) ?? now
            let dateStr = formatter.string(from: dueDate)
            let isPaid = i < 0
            let isOverdue = i == 0 && !isPaid && !isPersonal
            let status: EMIDetailLocal.EMIStatus = isPaid ? .paid : (isOverdue ? .overdue : .upcoming)
            
            let amount = isHome ? 38500.0 : (isVehicle ? 16200.0 : 9500.0)
            let principal = amount * 0.75
            let interest = amount * 0.25
            
            list.append(EMIDetailLocal(
                id: UUID(),
                date: dateStr,
                amount: amount + (isOverdue ? 500.0 : 0.0),
                principal: principal,
                interest: interest,
                penalty: isOverdue ? 500.0 : 0.0,
                status: status
            ))
        }
        return list
    }
}

private struct LoanPaymentRow: Identifiable {
    let id: UUID; let date: String; let amount: Double; let mode: String; let reference: String
}

private struct LoanDocumentRow: Identifiable {
    let id: UUID; let name: String; let storagePath: String?
}

struct EMIDetailLocal: Identifiable {
    let id: UUID
    let date: String
    let amount: Double
    let principal: Double
    let interest: Double
    let penalty: Double
    var status: EMIStatus
    
    enum EMIStatus {
        case paid
        case upcoming
        case overdue
    }
}
