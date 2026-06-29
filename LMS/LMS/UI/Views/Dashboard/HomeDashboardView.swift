import SwiftUI
import Supabase
import Auth

struct HomeDashboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var loans: [LoanListItem] = []
    @State private var userName = ""
    @State private var hasLoaded = false
    @State private var showProfile = false
    @State private var showChatHint = false
    @State private var showAllTransactions = false

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection

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
                .padding(.top, 6)
                .padding(.bottom, 100)
            }
            .background(
                LinearGradient(
                    colors: [Color(hex: "#E7EFE5"), Color(hex: "#EFF4EA"), Color(hex: "#E7EFE5")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showProfile) {
                ProfileView()
                    .environmentObject(authViewModel)
            }
            .alert("Chat", isPresented: $showChatHint) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Open chat from a loan or application detail for a specific conversation.")
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
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color(hex: "#6B6B6B"))
                    Text(firstName)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#1A1A1A"))
                }

                Spacer()

                HStack(spacing: 10) {
                    // Bell button
                    Button { } label: {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#E8F5EC"))
                                .frame(width: 40, height: 40)
                            Image(systemName: "bell")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color(hex: "#2D8B4E"))
                        }
                    }
                    .buttonStyle(.plain)

                    // Profile button
                    Button { showProfile = true } label: {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#1A1A1A"))
                                .frame(width: 40, height: 40)
                            Image(systemName: "person.fill")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            if !activeLoans.isEmpty {
                Text("You're on track!")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#1A1A1A"))
            } else if let _ = loans.first(where: { $0.status.lowercased() != "active" }) {
                Text("We 're in Process !")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
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

        return VStack(alignment: .leading, spacing: 12) {
            // Loan title row
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(hex: "#E8F5EC"))
                        .frame(width: 38, height: 38)
                    Image(systemName: primaryLoan.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "#2D8B4E"))
                }
                Text(primaryLoan.name)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#1A1A1A"))
                    .lineLimit(1)
                Spacer()
            }

            // Balance label + amount
            VStack(alignment: .leading, spacing: 3) {
                if primaryLoan.status.lowercased() == "active" {
                    Text("Outstanding Balance")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color(hex: "#6B6B6B"))
                    Text("₹ \(formatIndian(outstanding))")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#1A1A1A"))
                } else {
                    Text("Requested Amount")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color(hex: "#6B6B6B"))
                    Text("₹ \(formatIndian(outstanding))")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#1A1A1A"))
                }
            }

            if primaryLoan.status.lowercased() == "active" {
                // Progress bar + repaid %
                if paidPercent > 0 {
                    HStack(alignment: .center, spacing: 8) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color(hex: "#C8E6D0").opacity(0.5))
                                    .frame(height: 6)
                                Capsule()
                                    .fill(Color(hex: "#2D8B4E"))
                                    .frame(width: geo.size.width * CGFloat(min(paidPercent, 1)), height: 6)
                            }
                        }
                        .frame(height: 6)

                        Text("\(Int(paidPercent * 100))% repaid")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#2D8B4E"))
                            .fixedSize()
                    }
                } else {
                    HStack(alignment: .center, spacing: 8) {
                        GeometryReader { geo in
                            Capsule()
                                .fill(Color(hex: "#C8E6D0").opacity(0.5))
                                .frame(height: 6)
                        }
                        .frame(height: 6)

                        Text("No EMIs paid")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#9E9E9E"))
                            .fixedSize()
                    }
                }

                // Next EMI + Pay Now
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next EMI")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(Color(hex: "#6B6B6B"))
                        Text("₹ \(formatIndian(primaryLoan.emiAmount)) · \(formattedNextDueDate(primaryLoan.nextDueDate))")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "#1A1A1A"))
                    }

                    Spacer()

                    NavigationLink {
                        EMIScheduleView(loanId: primaryLoan.id)
                    } label: {
                        Text("Pay Now")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 12)
                            .background(Color(hex: "#1A1A1A"))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // Pending State
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Application Status")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(Color(hex: "#6B6B6B"))
                        Text(primaryLoan.status.capitalized.replacingOccurrences(of: "_", with: " "))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "#2D8B4E"))
                    }

                    Spacer()

                    NavigationLink {
                        LoanDetailView(loan: primaryLoan)
                    } label: {
                        Text("View Updates")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Color(hex: "#1A1A1A"))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
        }
        .padding(18)
        .liquidGlass(cornerRadius: 22, tint: Color(hex: "#2D8B4E"), tintOpacity: 0.06)
    }

    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#2D8B4E"))
                Text("QUICK ACTIONS")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#6B6B6B"))
                    .tracking(0.8)
            }

            HStack(spacing: 10) {
                NavigationLink {
                    EMICalculatorView()
                } label: {
                    quickActionCard(icon: "plusminus", label: "Calculator")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    SelectLoanTypeView()
                } label: {
                    quickActionCard(icon: "rays", label: "Apply")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    KYCDashboardView(allowsSkip: false)
                        .environmentObject(authViewModel)
                } label: {
                    quickActionCard(icon: "doc.on.doc", label: "KYC")
                }
                .buttonStyle(.plain)

                Button { showChatHint = true } label: {
                    quickActionCard(icon: "bubble.left.and.text.bubble.right", label: "Chat")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func quickActionCard(icon: String, label: String) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#E8F5EC"))
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(Color(hex: "#2D8B4E"))
            }
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
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
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#2D8B4E"))
                    Text("TRANSACTION HISTORY")
                        .font(.system(size: 14, weight: .semibold))
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
                                .font(.system(size: 15, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(Color(hex: "#2D8B4E"))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Transaction cards
            if transactionItems.isEmpty {
                VStack(alignment: .center, spacing: 6) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 26))
                        .foregroundColor(Color(hex: "#C8E6D0"))
                    Text("No transactions yet")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "#6B6B6B"))
                }
                .frame(maxWidth: .infinity, minHeight: 290)
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
                    .frame(width: 34, height: 34)
                Image(systemName: item.statusIcon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(item.statusColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(hex: "#1A1A1A"))
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color(hex: "#6B6B6B"))
            }

            Spacer()

            HStack(spacing: 2) {
                Text(item.direction.sign)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(item.direction.color)
                Text("₹\(formatIndian(abs(item.amount)))")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#1A1A1A"))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .liquidGlass(cornerRadius: 18)
    }

    // MARK: - Empty State
    
    private var applyLoanPromoCard: some View {
        NavigationLink {
            SelectLoanTypeView()
        } label: {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#E8F5EC"))
                            .frame(width: 48, height: 48)
                        Image(systemName: "indianrupeesign.circle.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Color(hex: "#2D8B4E"))
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "#2D8B4E"))
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Unlock Your Potential Today")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#1A1A1A"))
                    Text("Get an instant loan with flexible tenures, lowest interest rates, and approval in minutes. Fulfill your dreams now!")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color(hex: "#6B6B6B"))
                        .lineSpacing(4)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .liquidGlass(cornerRadius: 24, tint: Color(hex: "#2D8B4E"), tintOpacity: 0.08)
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(Color(hex: "#C8E6D0"))
            Text("No loans yet")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#1A1A1A"))
            Text("Apply for your first loan and manage everything from one place.")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color(hex: "#6B6B6B"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            NavigationLink {
                SelectLoanTypeView()
            } label: {
                HStack {
                    Spacer()
                    Text("Apply Now")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color(hex: "#2D8B4E"))
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
            let disbursedDateStr = loan.disbursedDate

            let paidCount = emiAmt > 0 ? Int(loan.paidAmount / emiAmt) : 0

            // Add EMI payments
            for i in 0..<paidCount {
                let formatter = DateFormatter()
                formatter.dateFormat = "d MMMM yyyy"
                let dateStr = formatter.string(from: Calendar.current.date(byAdding: .month, value: -i, to: Date()) ?? Date())
                items.append(
                    TxItem(
                        title: loan.name,
                        subtitle: "\(dateStr) - EMI Payment",
                        amount: emiAmt,
                        direction: .debit,
                        statusIcon: "checkmark",
                        statusColor: .white,
                        statusBg: Color(hex: "#2D8B4E")
                    )
                )
            }

            // Loan disbursed transaction
            items.append(
                TxItem(
                    title: loan.name,
                    subtitle: "\(disbursedDateStr ?? "Recently") - Loan Disbursed",
                    amount: loan.amount,
                    direction: .credit,
                    statusIcon: "arrow.down",
                    statusColor: .white,
                    statusBg: Color(hex: "#1A1A1A")
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
        case .debit: return "-"
        }
    }

    var color: Color {
        switch self {
        case .credit: return Color(hex: "#2D8B4E")
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
