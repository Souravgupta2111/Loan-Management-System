import SwiftUI
import Supabase
import Auth

/// Home Dashboard
/// Light, airy home screen with a swipeable loan hero, quick actions, and recent activity.
struct HomeDashboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var loans: [LoanListItem] = []
    @State private var hasLoaded = false
    @State private var showProfile = false
    @State private var showChatHint = false
    @State private var selectedLoanIndex = 0
    @State private var kycStatus = "pending"

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection

                    // MARK: - Quick Actions (Always Visible & Connected)
                    quickActionsSection

                    // MARK: - Recent Money Flow
                    recentTransactionsSection

                    // MARK: - Active Loans / EMI / My Loans
                    if loans.isEmpty && hasLoaded {
                        noLoansTip
                    } else if !loans.isEmpty {
                        if !activeLoans.isEmpty {
                            loanCarouselSection
                        } else if pendingApplicationsCount == 0 {
                            noLoansTip
                        }
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 110)
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
            .task {
                await loadData()
            }
            .refreshable {
                await loadData()
            }
            .onReceive(NotificationCenter.default.publisher(for: .loanDataDidChange)) { _ in
                Task { await loadData() }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(currentDateString)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.textPrimary.opacity(0.85))
                    .textCase(.uppercase)

                Spacer()

                HStack(spacing: 12) {
                    Button { } label: {
                        Image(systemName: "bell")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.textPrimary)
                            .frame(width: 52, height: 52)
                            .background(Color.white.opacity(0.72))
                            .clipShape(Circle())
                    }

                    Button { showProfile = true } label: {
                        Image(systemName: "person")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 52, height: 52)
                            .background(Color.textPrimary)
                            .clipShape(Circle())
                    }
                }
            }

            Text("You're on track to be debt-free")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }

    private var loanCarouselSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Array(activeLoans.enumerated()), id: \.element.id) { index, loan in
                        loanCarouselCard(loan)
                            .frame(width: UIScreen.main.bounds.width * 0.84)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                                    selectedLoanIndex = index
                                }
                            }
                    }
                }
                .padding(.trailing, 28)
            }
        }
    }

    private func loanCarouselCard(_ loan: LoanListItem) -> some View {
        let accent = cardAccent(for: loan.loanType)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white)
                    Image(systemName: loan.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(accent)
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 4) {
                    Text(loan.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(loan.loanType.capitalized)
                        .font(.system(size: 12, weight: .medium, design: .default))
                        .foregroundColor(.textSecondary)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Outstanding Balance")
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .foregroundColor(.textSecondary)

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("₹\(formatIndian(loan.remainingAmount))")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)

                    Spacer()

                    Text("\(Int(loan.paidPercent * 100))% repaid")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(accent)
                        .lineLimit(1)
                }
            }

            LoanProgressBar(progress: loan.paidPercent, color: accent)
                .frame(height: 10)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next EMI")
                        .font(.system(size: 13, weight: .regular, design: .default))
                        .foregroundColor(.textSecondary)
                    Text("₹\(formatIndian(loan.emiAmount)) • \(nextDueText(for: loan))")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Spacer()
                if loan.status.lowercased() == "active" {
                    Button { } label: {
                        HStack(spacing: 6) {
                            Text("Pay EMI")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color(hex: "#26282A"))
                        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(loan.status.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .background(
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(Color.white)
        )
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Actions")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.textPrimary)

            HStack(spacing: 10) {
                NavigationLink {
                    SelectLoanTypeView()
                } label: {
                    quickActionCard(icon: "plus.circle", label: "Apply")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    EMICalculatorView()
                } label: {
                    quickActionCard(icon: "calendar", label: "EMI\nCalculate")
                }
                .buttonStyle(.plain)

                if shouldShowKYCAction {
                    NavigationLink {
                        KYCDashboardView(allowsSkip: false)
                            .environmentObject(authViewModel)
                    } label: {
                        quickActionCard(icon: "doc.text", label: "KYC")
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    showChatHint = true
                } label: {
                    quickActionCard(icon: "bubble.left", label: "Chat")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func quickActionCard(icon: String, label: String) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#EAF1E5"))
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.accentGreen)
            }
            .frame(width: 40, height: 40)

            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent Transactions")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                Spacer()
                Button { } label: {
                    Text("See all")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.accentGreen)
                }
            }

            VStack(spacing: 0) {
                ForEach(recentTransactions.indices, id: \.self) { index in
                    transactionRow(recentTransactions[index])
                    if index < recentTransactions.count - 1 {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.78))
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.white.opacity(0.9), lineWidth: 1)
            )
        }
    }

    private func transactionRow(_ item: DashboardTransaction) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#EEF4EA"))
                Image(systemName: item.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(item.iconColor)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            Text(item.amountText)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(item.isPositive ? .accentGreen : .accentRed)
                .lineLimit(1)
        }
        .padding(.vertical, 8)
    }

    private var pendingApplicationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Active Applications")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)

                Spacer()

                NavigationLink {
                    ApplicationsListView()
                        .environmentObject(authViewModel)
                } label: {
                    Text("View all")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.accentGreen)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 10) {
                ForEach(pendingApplications.prefix(3)) { application in
                    pendingApplicationRow(application)
                }
            }
        }
    }

    private func pendingApplicationRow(_ application: LoanListItem) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#EEF4EA"))
                Image(systemName: application.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.accentGreen)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(application.name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.textPrimary)
                    .lineLimit(2)

                Text(application.loanNumber)
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(application.status.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.accentGreen)
                    .lineLimit(1)

                Text("₹\(formatIndian(application.amount))")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.9), lineWidth: 1)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 42))
                .foregroundColor(.accentGreen)
            Text("No loans yet")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.textPrimary)
            Text("Apply for your first loan and manage everything from one place.")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            NavigationLink {
                SelectLoanTypeView()
            } label: {
                HStack {
                    Spacer()
                    Text("Apply Now")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(Color.accentDark)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(Color.white.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.9), lineWidth: 1)
        )
    }

    private var noLoansTip: some View {
        emptyState
    }

    private var currentDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: Date()).uppercased()
    }

    private var recentTransactions: [DashboardTransaction] {
        guard !activeLoans.isEmpty else {
            return [
                DashboardTransaction(
                    icon: "tray",
                    iconColor: .accentGreen,
                    title: "No money flow yet",
                    subtitle: "Transactions appear after loan activity starts",
                    amountText: "--",
                    isPositive: true
                )
            ]
        }

        let fallback = activeLoans.first!
        let loanA = activeLoans.first ?? fallback
        let loanB = activeLoans.dropFirst().first ?? fallback
        let loanC = activeLoans.dropFirst(2).first ?? fallback

        return [
            DashboardTransaction(
                icon: "car.fill",
                iconColor: .accentRed,
                title: "\(loanA.name) EMI",
                subtitle: "Today · \(formattedNextDueDate(loanA.nextDueDate))",
                amountText: "-₹\(formatIndian(loanA.emiAmount))",
                isPositive: false
            ),
            DashboardTransaction(
                icon: "banknote.fill",
                iconColor: .accentGreen,
                title: "Disbursement",
                subtitle: loanB.loanType.capitalized,
                amountText: "+₹\(formatIndian(loanB.remainingAmount))",
                isPositive: true
            ),
            DashboardTransaction(
                icon: "house.fill",
                iconColor: .accentRed,
                title: "\(loanC.name) Payment",
                subtitle: "Completed",
                amountText: "-₹\(formatIndian(loanC.emiAmount))",
                isPositive: false
            )
        ]
    }

    private func nextDueText(for loan: LoanListItem) -> String {
        if loan.status.lowercased() == "closed" {
            return "Paid off"
        }
        return formattedNextDueDate(loan.nextDueDate)
    }

    private func formatIndian(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

    private func cardAccent(for loanType: String) -> Color {
        switch loanType.lowercased() {
        case "home": return .accentGreen
        case "vehicle": return .accentBlue
        case "business": return .accentBeigeDk
        case "education": return .accentAmber
        case "personal": return .accentRed
        default: return .accentGreen
        }
    }

    private var activeLoans: [LoanListItem] {
        loans.filter { $0.status.lowercased() == "active" }
    }

    private var pendingApplications: [LoanListItem] {
        loans.filter {
            ["draft", "submitted", "under_review", "sent_back", "approved", "pending"].contains($0.status.lowercased())
        }
    }

    private var pendingApplicationsCount: Int {
        pendingApplications.count
    }

    private var shouldShowKYCAction: Bool {
        !["verified", "submitted"].contains(kycStatus.lowercased())
    }

    private func loadData() async {
        do {
            if let userId = authViewModel.currentUser?.id {
                loans = try await LoanService.shared.fetchDetailedUserLoans(userId: userId)
                kycStatus = await fetchKYCStatus(userId: userId)
                selectedLoanIndex = 0
            }
            hasLoaded = true
        } catch {
            hasLoaded = true
            print("Dashboard load error: \(error)")
        }
    }

    private func fetchKYCStatus(userId: UUID) async -> String {
        struct ProfileStatus: Decodable {
            let kyc_status: String
        }

        do {
            let rows: [ProfileStatus] = try await SupabaseManager.shared.client
                .from("borrower_profiles")
                .select("kyc_status")
                .eq("user_id", value: userId)
                .execute()
                .value
            return rows.first?.kyc_status ?? "pending"
        } catch {
            print("Failed to fetch dashboard KYC status: \(error)")
            return kycStatus
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

private struct DashboardTransaction {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let amountText: String
    let isPositive: Bool
}
