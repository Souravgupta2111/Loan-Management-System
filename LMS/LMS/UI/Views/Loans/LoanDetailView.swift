import SwiftUI
import Supabase

/// Loan Detail View (design.md §8.5)
/// Hero area with gradient + amount, stat cards, sub-tabs, bottom PAY EMI bar.
struct LoanDetailView: View {
    let loan: LoanListItem
    @State private var selectedTab: DetailTab = .emi
    @State private var paymentHistory: [LoanPaymentRow] = []
    @State private var loanDocuments: [LoanDocumentRow] = []
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
                .padding(.bottom, 120)
            }
            .background(Color.appBackground.ignoresSafeArea())

            // MARK: - Bottom Glass Bar (PAY EMI)
            if loan.status == "active" {
                bottomPayBar
            }
        }
        .navigationTitle(loan.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
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
        NavigationLink {
            EMIScheduleView(loanId: loan.id)
        } label: {
            Label("View complete EMI schedule", systemImage: "calendar")
                .font(.bodyLarge)
                .foregroundColor(.accentGreen)
                .frame(maxWidth: .infinity)
                .padding(Spacing.lg)
                .background(Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: Corner.md))
        }
        .buttonStyle(.plain)
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
                    .font(.cardTitle)
                    .foregroundColor(.textPrimary)
                Text("Open schedule for the exact payable amount")
                    .font(.caption2)
                    .foregroundColor(.textSecondary)
            }
            Spacer()
            NavigationLink {
                EMIScheduleView(loanId: loan.id)
            } label: {
                Text("View & Pay EMI")
                    .font(.bodyLarge)
                    .foregroundColor(.white)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                    .background(Color.accentGreen)
                    .clipShape(Capsule())
            }
        }
        .padding(Spacing.lg)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Corner.xl))
        .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: -4)
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
        } catch {
            loadError = error.localizedDescription
        }
    }

    private static func displayDate(_ value: String) -> String {
        guard let date = Formatter.iso8601.date(from: value) else { return value }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

private struct LoanPaymentRow: Identifiable {
    let id: UUID; let date: String; let amount: Double; let mode: String; let reference: String
}

private struct LoanDocumentRow: Identifiable {
    let id: UUID; let name: String; let storagePath: String?
}
