import SwiftUI
import Supabase
import Auth

enum LoanNavigation: Hashable {
    case selectLoanType
    case applicationFlow(LoanType?)
}

struct HomeDashboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var loans: [LoanListItem] = []
    @State private var userName = ""
    @State private var hasLoaded = false
    @State private var showProfile = false
    @State private var showChatHint = false
    @State private var showAllTransactions = false
    @State private var showAIChat = false
    @State private var path = NavigationPath()

    // UI control flags to hide elements
    private let showChatButton = true
    private let showNotificationButton = false

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                ZStack(alignment: .top) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {
                            headerSection
                                .padding(.top, 4)

                            if loans.isEmpty && hasLoaded {
                                applyLoanPromoCard
                                quickActionsSection
                                emptyState
                            } else if !loans.isEmpty {
                                heroLoanCarousel
                                    .padding(.horizontal, -16) // offset the ScrollView padding

                                quickActionsSection

                                transactionHistorySection
                            } else {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 48)
                            }
                        }
                        .padding(.horizontal, 16)
                        // Push content below the status bar
                        .padding(.top, 54)
                        .padding(.bottom, 100)
                    }
                    .ignoresSafeArea(edges: .top)

                    // Status bar blur effect
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .frame(height: 0)
                        .ignoresSafeArea(edges: .top)
                }
                
                // Floating AI Chat Button
                Button {
                    showAIChat = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 60, height: 60)
                            .overlay(
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                Color.white.opacity(0.55),
                                                Color.themeGreen.opacity(0.18),
                                                Color.white.opacity(0.08)
                                            ],
                                            center: .topLeading,
                                            startRadius: 4,
                                            endRadius: 56
                                        )
                                    )
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.75), lineWidth: 1)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.accentGreen.opacity(0.28), lineWidth: 1.5)
                            )
                        
                        Image(systemName: "sparkles")
                            .font(.title2.weight(.semibold))
                            .foregroundColor(Color.accentGreen)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 20)
                .padding(.bottom, 20)
                .shadow(color: Color.accentGreen.opacity(0.25), radius: 16, x: 0, y: 8)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                .accessibilityLabel("Open AI Financial Advisor")
                .accessibilityHint("Double tap to chat with your personal AI assistant")
            }
            .background(
                LinearGradient(
                    colors: [Color.gradientMintStart, Color.gradientMintEnd, Color.gradientMintStart],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationBarHidden(true)
            .sheet(isPresented: $showProfile) {
                ProfileView()
                    .environmentObject(authViewModel)
            }
            .fullScreenCover(isPresented: $showAIChat) {
                AIChatView()
            }
            .navigationDestination(for: LoanNavigation.self) { dest in
                switch dest {
                case .selectLoanType:
                    SelectLoanTypeView(path: $path)
                case .applicationFlow(let loanType):
                    LoanApplicationFlowView(initialLoanType: loanType, path: $path)
                }
            }
            .task { await loadData() }
            .refreshable { await loadData() }
            .onReceive(NotificationCenter.default.publisher(for: .loanDataDidChange)) { _ in
                Task { await loadData() }
            }
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good Morning,"
        case 12..<17: return "Good Afternoon,"
        default: return "Good Evening,"
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        let firstName = userName.components(separatedBy: " ").first ?? "User"

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(greetingText)
                        .font(.subheadline.weight(.regular))
                        .foregroundColor(Color(hex: "#6B6B6B"))
                    Text(firstName)
                        .font(.title2.weight(.bold)).fontDesign(.rounded)
                        .foregroundColor(Color(hex: "#1A1A1A"))
                }

                Spacer()

                HStack(spacing: 10) {
                    // Bell button
                    if showNotificationButton {
                        Button { } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.accentGreenBg)
                                    .frame(width: 40, height: 40)
                                Image(systemName: "bell")
                                    .font(.body.weight(.medium))
                                    .foregroundColor(Color.accentGreen)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    // Profile button
                    Button { showProfile = true } label: {
                        ZStack {
                            Circle()
                                .fill(Color.accentDark)
                                .frame(width: 40, height: 40)
                            Image(systemName: "person.fill")
                                .font(.body.weight(.medium))
                                .foregroundColor(Color.accentDarkText)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            if !activeLoans.isEmpty {
                Text("You're on track!")
                    .font(.title3.weight(.bold)).fontDesign(.rounded)
                    .foregroundColor(Color(hex: "#1A1A1A"))
            } else if let _ = loans.first(where: { $0.status.lowercased() != "active" }) {
                Text("We 're in Process !")
                    .font(.title3.weight(.bold)).fontDesign(.rounded)
                    .foregroundColor(Color(hex: "#6B6B6B"))
                    .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Hero Loan Carousel
    private var heroLoanCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(loans) { loan in
                    singleHeroLoanCard(for: loan)
                        .frame(width: UIScreen.main.bounds.width - 48)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 16)
        }
        .scrollTargetBehavior(.viewAligned)
    }

    private func singleHeroLoanCard(for primaryLoan: LoanListItem) -> some View {
        let paidPercent = primaryLoan.paidPercent
        let outstanding = primaryLoan.remainingAmount
        let totalEMIs = primaryLoan.emiSchedule?.count ?? (primaryLoan.requestedTenure ?? 12)
        let paidEMIs = primaryLoan.emiAmount > 0 ? Int(primaryLoan.paidAmount / primaryLoan.emiAmount) : 0

        return VStack(alignment: .leading, spacing: 12) {
            // Loan title row
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.accentGreenBg)
                        .frame(width: 38, height: 38)
                    Image(systemName: primaryLoan.icon)
                        .font(.body.weight(.semibold))
                        .foregroundColor(Color.accentGreen)
                }
                Text(primaryLoan.name)
                    .font(.headline.weight(.bold)).fontDesign(.rounded)
                    .foregroundColor(Color(hex: "#1A1A1A"))
                Spacer()
            }

            // Balance label + amount
            VStack(alignment: .leading, spacing: 3) {
                if primaryLoan.status.lowercased() == "active" {
                    Text("Outstanding Balance")
                        .font(.subheadline.weight(.regular))
                        .foregroundColor(Color(hex: "#6B6B6B"))
                    Text("₹ \(formatIndian(outstanding))")
                        .font(.title.weight(.bold)).fontDesign(.rounded)
                        .foregroundColor(Color(hex: "#1A1A1A"))
                } else {
                    Text("Requested Amount")
                        .font(.subheadline.weight(.regular))
                        .foregroundColor(Color(hex: "#6B6B6B"))
                    Text("₹ \(formatIndian(outstanding))")
                        .font(.title.weight(.bold)).fontDesign(.rounded)
                        .foregroundColor(Color(hex: "#1A1A1A"))
                }
            }

            if primaryLoan.status.lowercased() == "active" {
                // Progress bar + repaid %
                HStack(alignment: .center, spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.themeGreen.opacity(0.5))
                                .frame(height: 6)
                            Capsule()
                                .fill(Color.accentGreen)
                                .frame(width: geo.size.width * CGFloat(min(paidPercent, 1)), height: 6)
                        }
                    }
                    .frame(height: 6)

                    Text("\(paidEMIs)/\(totalEMIs) paid")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color.accentGreen)
                        .fixedSize()
                }

                // Next EMI + Pay Now
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next EMI")
                            .font(.subheadline.weight(.regular))
                            .foregroundColor(Color(hex: "#6B6B6B"))
                        Text("₹ \(formatIndian(primaryLoan.emiAmount)) · \(formattedNextDueDate(primaryLoan.nextDueDate))")
                            .font(.body.weight(.semibold))
                            .foregroundColor(Color(hex: "#1A1A1A"))
                    }

                    Spacer()

                    NavigationLink {
                        EMIScheduleView(loanId: primaryLoan.id)
                    } label: {
                        Text("Pay Now")
                            .font(.body.weight(.bold))
                            .foregroundColor(.accentDarkText)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 12)
                            .background(Color.accentDark)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // Pending State
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Application Status")
                            .font(.subheadline.weight(.regular))
                            .foregroundColor(Color(hex: "#6B6B6B"))
                        Text(primaryLoan.status.capitalized.replacingOccurrences(of: "_", with: " "))
                            .font(.body.weight(.semibold))
                            .foregroundColor(Color.accentGreen)
                    }

                    Spacer()

                    NavigationLink {
                        LoanDetailView(loan: primaryLoan)
                    } label: {
                        Text("View Updates")
                            .font(.body.weight(.bold))
                            .foregroundColor(.accentDarkText)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Color.accentDark)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
        }
        .padding(18)
        .liquidGlass(cornerRadius: 22, tint: Color.accentGreen, tintOpacity: 0.06)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(primaryLoan.name), \(primaryLoan.status.lowercased() == "active" ? "Outstanding Balance" : "Requested Amount") ₹ \(formatIndian(primaryLoan.remainingAmount)). \(primaryLoan.status.lowercased() == "active" ? "\(paidEMIs) out of \(totalEMIs) EMIs paid" : "Status: \(primaryLoan.status)")")
        .accessibilityHint("Double tap to view loan details")
    }

    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.accentGreen)
                Text("QUICK ACTIONS")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color(hex: "#6B6B6B"))
                    .tracking(0.8)
            }

            HStack(spacing: 10) {
                NavigationLink {
                    EMICalculatorView()
                } label: {
                    quickActionCard(icon: "plus.forwardslash.minus", label: "Calculator")
                }
                .buttonStyle(.plain)

                NavigationLink(value: LoanNavigation.selectLoanType) {
                    quickActionCard(icon: "pointer.arrow.rays", label: "Apply")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    KYCDashboardView(allowsSkip: false)
                        .environmentObject(authViewModel)
                } label: {
                    quickActionCard(icon: "doc.on.doc", label: "KYC")
                }
                .buttonStyle(.plain)

                if showChatButton {
                    NavigationLink {
                        ChatSelectionView()
                    } label: {
                        quickActionCard(icon: "bubble.left.and.text.bubble.right", label: "Chat")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func quickActionCard(icon: String, label: String) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.accentGreenBg)
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(Color.accentGreen)
            }
            Text(label)
                .font(.subheadline.weight(.medium)).fontDesign(.rounded)
                .foregroundColor(Color(hex: "#1A1A1A"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .liquidGlass(cornerRadius: 18)
    }

    // MARK: - Transaction History
    private var transactionHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color.accentGreen)
                    Text("TRANSACTION HISTORY")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color(hex: "#6B6B6B"))
                        .tracking(0.8)
                }

                Spacer()

                if !transactionItems.isEmpty {
                    NavigationLink {
                        TransactionHistoryView(transactions: transactionItems)
                            .environmentObject(authViewModel)
                    } label: {
                        HStack(spacing: 4) {
                            Text("See more")
                                .font(.footnote.weight(.semibold))
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.bold))
                        }
                        .foregroundColor(Color.accentGreen)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Transaction cards
            if transactionItems.isEmpty {
                VStack(alignment: .center, spacing: 6) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.title2)
                        .foregroundColor(Color.themeGreen)
                    Text("No transactions yet")
                        .font(.body.weight(.medium))
                        .foregroundColor(Color(hex: "#6B6B6B"))
                }
                .frame(maxWidth: .infinity, minHeight: 150)
                .liquidGlass(cornerRadius: 18)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(transactionItems.prefix(5))) { item in
                        transactionCard(item)
                    }
                }
            }
        }
    }

    private func transactionCard(_ item: TxItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            // Status icon
            ZStack {
                Circle()
                    .fill(item.statusBg)
                    .frame(width: 28, height: 28)
                Image(systemName: item.statusIcon)
                    .font(.footnote.weight(.bold))
                    .foregroundColor(item.statusColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body.weight(.bold))
                    .foregroundColor(Color(hex: "#1A1A1A"))
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.subheadline.weight(.regular))
                    .foregroundColor(Color(hex: "#6B6B6B"))
            }

            Spacer()

            HStack(spacing: 2) {
                Text(item.direction.sign)
                    .font(.body.weight(.bold)).fontDesign(.rounded)
                    .foregroundColor(item.direction.color)
                Text("₹\(formatIndian(abs(item.amount)))")
                    .font(.body.weight(.bold)).fontDesign(.rounded)
                    .foregroundColor(item.direction == .credit ? item.direction.color : Color(hex: "#1A1A1A"))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .liquidGlass(cornerRadius: 18)
    }

    // MARK: - Empty State
    
    private var applyLoanPromoCard: some View {
        NavigationLink(value: LoanNavigation.selectLoanType) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.accentGreenBg)
                            .frame(width: 48, height: 48)
                        Image(systemName: "indianrupeesign.circle.fill")
                            .font(.title2.weight(.bold))
                            .foregroundColor(Color.accentGreen)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color.accentGreen)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Start Your Loan Journey")
                        .font(.title3.weight(.bold)).fontDesign(.rounded)
                        .foregroundColor(Color(hex: "#1A1A1A"))
                    Text("Apply for a new loan today. Get instant approval, competitive interest rates, and flexible tenure options customized for you.")
                        .font(.subheadline.weight(.regular))
                        .foregroundColor(Color(hex: "#6B6B6B"))
                        .lineSpacing(4)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .liquidGlass(cornerRadius: 24, tint: Color.accentGreen, tintOpacity: 0.08)
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.title)
                .foregroundColor(Color.themeGreen)
            Text("No loans yet")
                .font(.headline.weight(.bold)).fontDesign(.rounded)
                .foregroundColor(Color(hex: "#1A1A1A"))
            Text("Apply for your first loan and manage everything from one place.")
                .font(.subheadline.weight(.regular))
                .foregroundColor(Color(hex: "#6B6B6B"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            NavigationLink(value: LoanNavigation.selectLoanType) {
                HStack {
                    Spacer()
                    Text("Apply Now")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.accentDarkText)
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.accentDarkText)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.accentGreen)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .liquidGlass(cornerRadius: 24)
    }

    // MARK: - Computed Helpers
    private var currentDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: Date())
    }

    private var activeLoans: [LoanListItem] {
        loans.filter { $0.status.lowercased() == "active" }
    }

    private var transactionItems: [TxItem] {
        guard !activeLoans.isEmpty else { return [] }

        var items: [TxItem] = []

        for loan in activeLoans {
            let emiAmt = loan.emiAmount
            
            let rawDate = loan.disbursedDate
            let disbursedDateStr: String
            if !rawDate.isEmpty {
                let parseFormatter = DateFormatter()
                parseFormatter.dateFormat = "yyyy-MM-dd"
                if let parsed = parseFormatter.date(from: rawDate) {
                    let outFormatter = DateFormatter()
                    outFormatter.dateFormat = "d MMM yyyy"
                    disbursedDateStr = outFormatter.string(from: parsed)
                } else {
                    disbursedDateStr = rawDate
                }
            } else {
                disbursedDateStr = "Recently"
            }

            let paidCount = emiAmt > 0 ? Int(loan.paidAmount / emiAmt) : 0

            // Add EMI payments
            for i in 0..<paidCount {
                let formatter = DateFormatter()
                formatter.dateFormat = "d MMM yyyy"
                let dateStr = formatter.string(from: Calendar.current.date(byAdding: .month, value: -i, to: Date()) ?? Date())
                items.append(
                    TxItem(
                        title: loan.name,
                        subtitle: "\(dateStr) - EMI Payment",
                        amount: emiAmt,
                        direction: .debit,
                        statusIcon: "checkmark",
                        statusColor: .white,
                        statusBg: Color.accentGreen
                    )
                )
            }

            // Loan disbursed transaction
            items.append(
                TxItem(
                    title: loan.name,
                    subtitle: "\(disbursedDateStr) - Loan Disbursed",
                    amount: loan.amount,
                    direction: .credit,
                    statusIcon: "indianrupeesign",
                    statusColor: .accentDarkText,
                    statusBg: Color.accentDark
                )
            )
        }

        return items
    }

    private func formatIndian(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

    private func transactionAmountText(_ item: TxItem) -> String {
        "\(item.direction.sign) ₹\(formatIndian(abs(item.amount)))"
    }

    // MARK: - Data Loading
    private func loadData() async {
        do {
            if let userId = authViewModel.currentUser?.id {
                loans = try await LoanService.shared.fetchDetailedUserLoans(userId: userId)

                struct ProfileRow: Decodable {
                    let fullName: String
                    enum CodingKeys: String, CodingKey {
                        case fullName = "full_name"
                    }
                }
                let users: [ProfileRow] = try await SupabaseManager.shared.client
                    .from("users")
                    .select("full_name")
                    .eq("id", value: userId.uuidString)
                    .execute()
                    .value
                if let row = users.first {
                    userName = row.fullName
                }

                // Proactive nudges: schedule local EMI reminders for active loans.
                let reminders: [NotificationService.EMIReminder] = loans
                    .filter { $0.status.lowercased() == "active" }
                    .compactMap { loan in
                        guard let raw = loan.nextDueDate,
                              let date = LoansListView.parseDateString(raw) else { return nil }
                        return NotificationService.EMIReminder(
                            loanName: loan.name,
                            amount: loan.emiAmount,
                            dueDate: date
                        )
                    }
                NotificationService.shared.scheduleEMIReminders(reminders)

                // ----- Widgets: publish a rich snapshot to the shared App Group -----
                let active = loans.filter { $0.status.lowercased() == "active" }

                let loanDTOs: [WidgetLoanDTO] = active.map { loan in
                    WidgetLoanDTO(
                        id: loan.id.uuidString,
                        name: loan.name,
                        loanType: loan.loanType,
                        outstanding: loan.remainingAmount,
                        emiAmount: loan.emiAmount,
                        nextDue: loan.nextDueDate.flatMap { LoansListView.parseDateString($0) },
                        paidPercent: loan.paidPercent,
                        status: loan.status
                    )
                }

                // EMI calendar: merge active loans' schedules into (day, status).
                var calendar: [WidgetEMIDayDTO] = []
                for loan in active {
                    for emi in loan.emiSchedule ?? [] {
                        if let day = LoansListView.parseDateString(emi.dueDate) {
                            calendar.append(WidgetEMIDayDTO(date: day, status: emi.status.lowercased()))
                        }
                    }
                }

                // An application still in progress (not yet an active loan).
                let pendingStatuses = ["submitted", "under_review", "sent_back", "approved", "pending_acceptance", "pending_disbursal"]
                let pendingItem = loans.first { pendingStatuses.contains($0.status.lowercased()) }
                let appUpdated = pendingItem?.timeline?.compactMap { LoansListView.parseDateString($0.date) }.max()

                // Credit score (not otherwise loaded on the dashboard).
                var creditScore: Int? = nil
                if let userId = authViewModel.currentUser?.id {
                    struct ScoreRow: Decodable { let credit_score: Int? }
                    let rows: [ScoreRow] = (try? await SupabaseManager.shared.client
                        .from("borrower_profiles")
                        .select("credit_score")
                        .eq("user_id", value: userId.uuidString)
                        .execute()
                        .value) ?? []
                    creditScore = rows.first?.credit_score
                }

                WidgetDataProvider.update(WidgetSnapshotDTO(
                    loans: loanDTOs,
                    creditScore: creditScore,
                    applicationStage: pendingItem?.status,
                    applicationLoanName: pendingItem?.name,
                    applicationUpdated: appUpdated,
                    calendar: calendar,
                    generated: Date()
                ))
            }
            hasLoaded = true
        } catch {
            hasLoaded = true
            print("Dashboard load error: \(error)")
        }
    }
}

// MARK: - Transaction item model
struct TxItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let amount: Double
    let direction: TxDirection
    let statusIcon: String
    let statusColor: Color
    let statusBg: Color
}

enum TxDirection {
    case credit
    case debit

    var sign: String {
        switch self {
        case .credit: return "+"
        case .debit: return ""
        }
    }

    var color: Color {
        switch self {
        case .credit: return Color.accentGreen
        case .debit: return Color(hex: "#D94040")
        }
    }
}

private func formattedNextDueDate(_ rawDate: String?) -> String {
    guard let rawDate else { return "Soon" }
    if let date = LoansListView.parseDateString(rawDate) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    return rawDate
}
