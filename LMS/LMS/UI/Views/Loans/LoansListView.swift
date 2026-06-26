import SwiftUI
import Supabase
import Auth

/// My Loans List
/// Hero balance card, horizontal status filters, and rich loan cards.
struct LoansListView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedFilter: LoanFilter = .all
    @State private var loans: [LoanListItem] = []
    @State private var isLoading = true

    enum LoanFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case active = "Active"
        case pendingApproval = "Pending Approval"
        case overdue = "Overdue"
        case closed = "Closed"

        var id: String { rawValue }

        func matches(_ loan: LoanListItem) -> Bool {
            switch self {
            case .all:
                return true
            case .active:
                return loan.status.lowercased() == "active"
            case .pendingApproval:
                return loan.status.lowercased() == "under_review"
                    || loan.status.lowercased() == "submitted"
                    || loan.status.lowercased() == "draft"
                    || loan.status.lowercased() == "pending"
            case .overdue:
                return isOverdue(loan)
            case .closed:
                return loan.status.lowercased() == "closed"
            }
        }

        private func isOverdue(_ loan: LoanListItem) -> Bool {
            guard loan.status.lowercased() != "closed",
                  let nextDueDate = loan.nextDueDate,
                  let dueDate = LoansListView.parseDateString(nextDueDate) else {
                return false
            }

            return Calendar.current.startOfDay(for: dueDate) < Calendar.current.startOfDay(for: Date())
        }
    }

    private var filteredLoans: [LoanListItem] {
        loans.filter { selectedFilter.matches($0) }
    }

    private var totalOutstanding: Double {
        loans.reduce(0) { $0 + $1.remainingAmount }
    }

    private var activeLoansCount: Int {
        loans.filter { $0.status.lowercased() == "active" }.count
    }

    private var nextPaymentLoan: LoanListItem? {
        loans
            .compactMap { loan -> (loan: LoanListItem, date: Date)? in
                guard let nextDueDate = loan.nextDueDate,
                      let dueDate = Self.parseDateString(nextDueDate) else { return nil }
                return (loan, dueDate)
            }
            .sorted { $0.date < $1.date }
            .first?
            .loan
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 12) {
                    balanceHeroCard
                        .padding(.top, 0)

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Filter loans")
                            .font(.label)
                            .foregroundColor(.textSecondary)
                            .textCase(.uppercase)
                            .tracking(1.2)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Spacing.md) {
                                ForEach(LoanFilter.allCases) { filter in
                                    filterChip(filter)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Loans")
                            .font(.sectionTitle)
                            .foregroundColor(.textPrimary)
                        Text("\(filteredLoans.count) of \(loans.count) loans")
                            .font(.bodyRegular)
                            .foregroundColor(.textSecondary)
                    }

                    LazyVStack(spacing: Spacing.md) {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 48)
                        } else if filteredLoans.isEmpty {
                            emptyState
                        } else {
                            ForEach(filteredLoans) { loan in
                                NavigationLink {
                                    LoanDetailView(loan: loan)
                                } label: {
                                    loanCard(loan)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, 20)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("My Loans")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadLoans(resetFilter: true)
            }
            .refreshable {
                await loadLoans(resetFilter: false)
            }
            .onReceive(NotificationCenter.default.publisher(for: .loanDataDidChange)) { _ in
                Task { await loadLoans(resetFilter: false) }
            }
        }
    }

    private var balanceHeroCard: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "#081834"),
                    Color(hex: "#0C2147"),
                    Color(hex: "#0A1A39")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 100, height: 100)
                .offset(x: -76, y: 46)

            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 128, height: 128)
                .offset(x: 72, y: -46)

            VStack(alignment: .leading, spacing: 16) {
                Text("TOTAL BALANCE")
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.65))
                    .tracking(1.8)

                Text("₹\(formatIndian(totalOutstanding))")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                    .padding(.bottom, 2)

                HStack(spacing: 8) {
                    Text("\(activeLoansCount) active loans")
                        .font(.badge)
                        .foregroundColor(Color(hex: "#071A2C"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(hex: "#45E0A9"))
                        .clipShape(Capsule())

                    if let nextPaymentLoan {
                        Text("Next payment: \(formattedNextDueDate(nextPaymentLoan.nextDueDate))")
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .foregroundColor(.white.opacity(0.82))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    } else {
                        Text("No upcoming payments")
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .foregroundColor(.white.opacity(0.82))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 6)
    }

    private func filterChip(_ filter: LoanFilter) -> some View {
        let isSelected = selectedFilter == filter
        return Button {
            selectedFilter = filter
        } label: {
            Text(filter.rawValue)
                .font(.bodyRegular)
                .foregroundColor(isSelected ? .white : .textSecondary)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(isSelected ? Color(hex: "#081834") : Color.white)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.border, lineWidth: 1)
                )
                .shadow(color: isSelected ? .black.opacity(0.14) : .clear, radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(.textTertiary)
            Text("No \(selectedFilter.rawValue.lowercased()) loans")
                .font(.bodyLarge)
                .foregroundColor(.textSecondary)
            Text("Try another filter to view a different loan set.")
                .font(.bodyRegular)
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Corner.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Corner.lg)
                .stroke(Color.border, lineWidth: 0.5)
        )
    }

    private func loanCard(_ loan: LoanListItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                loanIconTile(for: loan.loanType)

                VStack(alignment: .leading, spacing: 2) {
                    Text(loan.name)
                        .font(.system(size: 18, weight: .semibold, design: .default))
                        .foregroundColor(.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 6)

                VStack(alignment: .trailing, spacing: 1) {
                    Text("Balance")
                        .font(.system(size: 13, weight: .regular, design: .default))
                        .foregroundColor(.textTertiary)

                    Text("₹\(formatIndian(loan.remainingAmount))")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }

            HStack(alignment: .center, spacing: 8) {
                LoanProgressBar(
                    progress: loan.paidPercent,
                    color: loan.status.lowercased() == "closed" ? .textTertiary : .accentGreen
                )
                .frame(maxWidth: .infinity)

                Text("\(Int(loan.paidPercent * 100))% repaid")
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .foregroundColor(.accentGreen)
                    .lineLimit(1)
            }

            Rectangle()
                .fill(Color.border)
                .frame(height: 1)

            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Monthly")
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundColor(.textSecondary)
                    Text(loan.emiAmount > 0 ? "₹\(formatIndian(loan.emiAmount))" : "N/A")
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text("Next due")
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundColor(.textSecondary)
                    Text(nextDueDisplay(for: loan))
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                }
            }
        }
        .padding(10)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.border, lineWidth: 0.7)
        )
    }

    private func loanIconTile(for loanType: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(hex: "#0B1A39"))

            Image(systemName: loanIcon(for: loanType))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(hex: "#F3B84B"))
        }
        .frame(width: 54, height: 54)
    }

    private func loanIcon(for type: String) -> String {
        switch type.lowercased() {
        case "home":        return "house.fill"
        case "vehicle":     return "car.fill"
        case "business":    return "building.2.fill"
        case "education":   return "graduationcap.fill"
        case "personal":    return "person.fill"
        case "agriculture": return "leaf.fill"
        default:            return "indianrupeesign.circle.fill"
        }
    }

    private func nextDueDisplay(for loan: LoanListItem) -> String {
        if loan.status.lowercased() == "closed" {
            return "Paid off"
        }
        return formattedNextDueDate(loan.nextDueDate)
    }

    private func formattedNextDueDate(_ rawDate: String?) -> String {
        guard let rawDate else { return "N/A" }
        if let date = Self.parseDateString(rawDate) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
        return rawDate
    }

    static func parseDateString(_ rawDate: String) -> Date? {
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: rawDate) {
            return date
        }

        let formats = [
            "yyyy-MM-dd",
            "dd MMM yyyy",
            "d MMM yyyy",
            "yyyy-MM-dd HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ssZ"
        ]

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: rawDate) {
                return date
            }
        }

        return nil
    }

    private func formatIndian(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

    private func loadLoans(resetFilter: Bool) async {
        isLoading = true
        defer { isLoading = false }

        guard let userId = authViewModel.currentUser?.id else { return }

        do {
            loans = try await LoanService.shared.fetchDetailedUserLoans(userId: userId)
            if resetFilter {
                selectedFilter = .all
            }
        } catch {
            print("Failed to load loans:", error)
        }
    }
}

// MARK: - LoanListItem Model

struct LoanListItem: Identifiable {
    let id: UUID
    let name: String
    let loanType: String
    let loanNumber: String
    let amount: Double
    let emiAmount: Double
    let status: String
    let paidPercent: Double
    let interestRate: Double
    let disbursedDate: String
    let nextDueDate: String?
    let paidAmount: Double
    let remainingAmount: Double

    var icon: String {
        switch loanType.lowercased() {
        case "home":        return "house.fill"
        case "vehicle":     return "car.fill"
        case "business":    return "building.2.fill"
        case "education":   return "graduationcap.fill"
        case "personal":    return "person.fill"
        case "agriculture": return "leaf.fill"
        default:            return "indianrupeesign.circle.fill"
        }
    }
}
