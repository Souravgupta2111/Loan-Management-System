import SwiftUI
import Supabase
import Auth

/// Home Dashboard — matches the reference screenshot exactly.
/// Hero card with active loan, Quick Actions, Transaction History.
struct HomeDashboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var loans: [LoanListItem] = []
    @State private var userName = ""
    @State private var hasLoaded = false
    @State private var showProfile = false
    @State private var showChatHint = false

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection

                    if loans.isEmpty && hasLoaded {
                        emptyState
                    } else if !loans.isEmpty {
                        heroLoanCard

                        quickActionsSection

                        transactionHistorySection
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 20)
            }
            .background(Color(hex: "#FAFAF8").ignoresSafeArea())
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

    // MARK: - Header
    private var headerSection: some View {
        let firstName = userName.components(separatedBy: " ").first ?? "User"

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Good Morning,")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.textSecondary)
                Text(firstName)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
            }

            Spacer()

            HStack(spacing: 12) {
                // Bell button
                Button { } label: {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#89DBA6").opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "bell")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.textPrimary)
                    }
                }
                .buttonStyle(.plain)

                // Profile button
                Button { showProfile = true } label: {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#1A1A1A"))
                            .frame(width: 44, height: 44)
                        Image(systemName: "person.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Hero Loan Card
    private var heroLoanCard: some View {
        let primaryLoan = activeLoans.first ?? loans.first!
        let paidPercent = primaryLoan.paidPercent
        let outstanding = primaryLoan.remainingAmount

        return VStack(alignment: .leading, spacing: 14) {
            // Loan title row
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: "#89DBA6").opacity(0.25))
                        .frame(width: 44, height: 44)
                    Image(systemName: primaryLoan.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "#2D8B4E"))
                }
                Text(primaryLoan.name)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                Spacer()
            }

            // Balance label + amount
            VStack(alignment: .leading, spacing: 4) {
                Text("Outstanding Balance")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.textSecondary)
                Text("₹ \(formatIndian(outstanding))")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
            }

            // Progress bar + repaid %
            HStack(alignment: .center, spacing: 10) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(hex: "#89DBA6").opacity(0.25))
                            .frame(height: 7)
                        Capsule()
                            .fill(Color(hex: "#2D8B4E"))
                            .frame(width: geo.size.width * CGFloat(paidPercent), height: 7)
                    }
                }
                .frame(height: 7)

                Text("\(Int(paidPercent * 100))% repaid")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "#2D8B4E"))
                    .fixedSize()
            }

            // Next EMI + Pay Now
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next EMI")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.textSecondary)
                    Text("₹ \(formatIndian(primaryLoan.emiAmount)) · \(formattedNextDueDate(primaryLoan.nextDueDate))")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.textPrimary)
                }

                Spacer()

                NavigationLink {
                    EMIScheduleView(loanId: primaryLoan.id)
                } label: {
                    Text("Pay Now")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#1A1A1A"))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(Color(hex: "#89DBA6").opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(hex: "#89DBA6").opacity(0.30), lineWidth: 1)
        )
        .shadow(color: Color(hex: "#89DBA6").opacity(0.18), radius: 12, x: 0, y: 4)
    }

    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        VStack(spacing: 16) {
            // Decorative divider with title
            HStack(spacing: 12) {
                Rectangle()
                    .fill(Color(hex: "#89DBA6"))
                    .frame(height: 1)
                Text("Quick Actions")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.textPrimary)
                    .fixedSize()
                Rectangle()
                    .fill(Color(hex: "#89DBA6"))
                    .frame(height: 1)
            }

            HStack(spacing: 12) {
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
                    KYCDashboardView()
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
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(hex: "#89DBA6").opacity(0.18))
                    .frame(width: 54, height: 54)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(hex: "#2D8B4E"))
            }
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(hex: "#89DBA6").opacity(0.20), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 2)
    }

    // MARK: - Transaction History
    private var transactionHistorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Decorative divider with title
            HStack(spacing: 12) {
                Rectangle()
                    .fill(Color(hex: "#89DBA6"))
                    .frame(height: 1)
                Text("Transaction History")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.textPrimary)
                    .fixedSize()
                Rectangle()
                    .fill(Color(hex: "#89DBA6"))
                    .frame(height: 1)
            }

            // Date header
            HStack {
                Text(currentDateString)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                Spacer()
                Button { } label: {
                    Text("See more")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#2D8B4E"))
                }
            }

            // Transaction cards
            VStack(spacing: 10) {
                ForEach(transactionItems.indices, id: \.self) { idx in
                    transactionCard(transactionItems[idx])
                }
            }
        }
    }

    private func transactionCard(_ item: TxItem) -> some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.textPrimary)
                Text(item.subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            HStack(spacing: 12) {
                Text("₹ \(formatIndian(item.amount))")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)

                // Status icon
                ZStack {
                    Circle()
                        .fill(item.statusBg)
                        .frame(width: 28, height: 28)
                    Image(systemName: item.statusIcon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(item.statusColor)
                }
            }
        }
        .padding(16)
        .background(Color(hex: "#89DBA6").opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: "#89DBA6").opacity(0.20), lineWidth: 1)
        )
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 42))
                .foregroundColor(Color(hex: "#2D8B4E"))
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
                .background(Color(hex: "#1A1A1A"))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color(hex: "#89DBA6").opacity(0.25), lineWidth: 1)
        )
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
        guard !loans.isEmpty else {
            return [TxItem(title: "Apply for your first loan", subtitle: "No transactions yet", amount: 0, statusIcon: "arrow.up.right", statusColor: Color(hex: "#2D8B4E"), statusBg: Color(hex: "#89DBA6").opacity(0.2))]
        }

        let loanName = (activeLoans.first ?? loans.first!).name
        let emiAmt = (activeLoans.first ?? loans.first!).emiAmount
        let today = DateFormatter()
        today.dateFormat = "d MMMM"
        let dateStr = today.string(from: Date())

        return [
            TxItem(
                title: loanName,
                subtitle: "\(dateStr) - Auto Debit",
                amount: emiAmt,
                statusIcon: "checkmark",
                statusColor: .white,
                statusBg: Color(hex: "#2D8B4E")
            ),
            TxItem(
                title: loanName,
                subtitle: "\(dateStr) - Netbanking",
                amount: emiAmt,
                statusIcon: "clock.badge.exclamationmark",
                statusColor: .white,
                statusBg: Color(hex: "#E8732A")
            ),
            TxItem(
                title: loanName,
                subtitle: "\(dateStr) - UPI",
                amount: emiAmt,
                statusIcon: "xmark",
                statusColor: .white,
                statusBg: Color(hex: "#D94040")
            )
        ]
    }

    private func formatIndian(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
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
private struct TxItem {
    let title: String
    let subtitle: String
    let amount: Double
    let statusIcon: String
    let statusColor: Color
    let statusBg: Color
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
