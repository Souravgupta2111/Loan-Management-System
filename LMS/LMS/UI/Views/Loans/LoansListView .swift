import SwiftUI
import Supabase
import Auth

struct LoansListView: View {

    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var selectedFilter: LoanFilter = .all
    @State private var loans: [LoanListItem] = []
    @State private var isLoading = true

    enum LoanFilter: String, CaseIterable, Identifiable {

        case all = "All"
        case active = "Active"
        case pendingApproval = "Pending"
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
                return [
                    "submitted",
                    "pending",
                    "approved",
                    "draft",
                    "under_review"
                ].contains(loan.status.lowercased())

            case .overdue:
                return isOverdue(loan)

            case .closed:
                return loan.status.lowercased() == "closed"
            }
        }

        private func isOverdue(_ loan: LoanListItem) -> Bool {

            guard
                loan.status.lowercased() != "closed",
                let raw = loan.nextDueDate,
                let due = LoansListView.parseDateString(raw)
            else {
                return false
            }

            return Calendar.current.startOfDay(for: due)
            <
            Calendar.current.startOfDay(for: Date())
        }
    }

    // MARK: - Computed Properties

    private var filteredLoans: [LoanListItem] {
        loans.filter {
            selectedFilter.matches($0)
        }
    }

    private var totalOutstanding: Double {
        loans.reduce(0) {
            $0 + $1.remainingAmount
        }
    }

    private var activeCount: Int {
        loans.filter {
            $0.status.lowercased() == "active"
        }.count
    }

    private var nextPaymentLoan: LoanListItem? {

        loans
            .compactMap { loan -> (LoanListItem, Date)? in

                guard
                    let raw = loan.nextDueDate,
                    let date = Self.parseDateString(raw)
                else {
                    return nil
                }

                return (loan, date)
            }
            .sorted {
                $0.1 < $1.1
            }
            .first?
            .0
    }

    // MARK: - Body

    var body: some View {

        NavigationStack {

            ScrollView(.vertical, showsIndicators: false) {

                VStack(alignment: .leading, spacing: 20) {

                    balanceHeroCard
                        .padding(.top, 4)

                    filterSection

                    sectionHeading

                    loanCardsList
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(
                Color(hex: "#FAFAF8")
                    .ignoresSafeArea()
            )
            .navigationTitle("My Loans")
            .navigationBarTitleDisplayMode(.inline)

            .task {
                await loadLoans(resetFilter: true)
            }

            .refreshable {
                await loadLoans(resetFilter: false)
            }

            .onReceive(
                NotificationCenter.default.publisher(
                    for: .loanDataDidChange
                )
            ) { _ in

                Task {
                    await loadLoans(resetFilter: false)
                }
            }
        }
    }
    // MARK: - Balance Hero Card

    private var balanceHeroCard: some View {

        VStack(alignment: .leading, spacing: 16) {

            // Icon + Title
            HStack(spacing: 12) {

                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: "#89DBA6").opacity(0.25))
                        .frame(width: 46, height: 46)

                    Image(systemName: "indianrupeesign.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(hex: "#2D8B4E"))
                }

                Text("Total Balance")
                    .font(.system(size: 18,
                                  weight: .bold,
                                  design: .rounded))
                    .foregroundColor(.textPrimary)

                Spacer()
            }

            // Amount
            VStack(alignment: .leading, spacing: 4) {

                Text("Outstanding Balance")
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)

                Text("₹ \(formatIndian(totalOutstanding))")
                    .font(.system(size: 36,
                                  weight: .bold,
                                  design: .rounded))
                    .foregroundColor(.textPrimary)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#89DBA6").opacity(0.15))
        .clipShape(
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
            .stroke(
                Color(hex: "#89DBA6").opacity(0.30),
                lineWidth: 1
            )
        )
        .shadow(
            color: Color(hex: "#89DBA6").opacity(0.18),
            radius: 12,
            x: 0,
            y: 4
        )
    }

    //
    // MARK: - Filter Section
    //

    private var filterSection: some View {

        VStack(alignment: .leading, spacing: 12) {

            HStack(spacing: 12) {

//                Rectangle()
//                    .fill(Color(hex: "#89DBA6"))
//                    .frame(height: 1)

                Text("FILTER LOANS")
                    .font(.system(size: 16,
                                  weight: .semibold,
                                  design: .rounded))
                    .foregroundColor(.gray)
                    .fixedSize()

//                Rectangle()
//                    .fill(Color(hex: "#89DBA6"))
//                    .frame(height: 1)
            }

            ScrollView(.horizontal, showsIndicators: false) {

                HStack(spacing: 10) {

                    ForEach(LoanFilter.allCases) { filter in
                        filterChip(filter)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func filterChip(_ filter: LoanFilter) -> some View {

        let isSelected = selectedFilter == filter

        return Button {

            selectedFilter = filter

        } label: {

            Text(filter.rawValue)
                .font(
                    .system(
                        size: 14,
                        weight: isSelected ? .semibold : .regular
                    )
                )
                .foregroundColor(
                    isSelected ? .white : .textSecondary
                )
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    isSelected
                    ? Color(hex: "#2D8B4E")
                    : Color.white
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected
                            ? Color.clear
                            : Color(hex: "#89DBA6").opacity(0.35),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: isSelected
                    ? Color(hex: "#2D8B4E").opacity(0.22)
                    : .clear,
                    radius: 8,
                    x: 0,
                    y: 3
                )
        }
        .buttonStyle(.plain)
    }

    //
    // MARK: - Current Loans Heading
    //

    private var sectionHeading: some View {

        HStack {

            VStack(alignment: .leading, spacing: 2) {

                Text("Current Loans")
                    .font(
                        .system(
                            size: 24,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundColor(.textPrimary)

                Text("\(filteredLoans.count) of \(loans.count) loans")
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
            }

            Spacer()
        }
    }
    // MARK: - Loan Cards List

    private var loanCardsList: some View {

        Group {

            if isLoading {

                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)

            } else if filteredLoans.isEmpty {

                emptyState

            } else {

                LazyVStack(spacing: 14) {

                    ForEach(filteredLoans) { loan in

                        NavigationLink {

                            // Navigates to the custom iOS-native LoanDetailView displaying the
                            // detailed timeline stages, required & uploaded documents, and EMI schedule.
                            LoanDetailView(loan: loan)

                        } label: {

                            loanCard(loan)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Loan Card

    private func loanCard(_ loan: LoanListItem) -> some View {

        VStack(alignment: .leading, spacing: 12) {

            // Top Row

            HStack(alignment: .top, spacing: 12) {

                ZStack {

                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "#89DBA6").opacity(0.20))
                        .frame(width: 44, height: 44)

                    Image(systemName: loanIcon(for: loan.loanType))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(hex: "#2D8B4E"))
                }

                VStack(alignment: .leading, spacing: 3) {

                    Text(loan.name)
                        .font(
                            .system(
                                size: 16,
                                weight: .bold,
                                design: .rounded
                            )
                        )
                        .foregroundColor(.textPrimary)
                        .lineLimit(2)

                    statusBadge(for: loan.status)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {

                    Text("Balance")
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)

                    Text("₹\(formatIndian(loan.remainingAmount))")
                        .font(
                            .system(
                                size: 20,
                                weight: .bold,
                                design: .rounded
                            )
                        )
                        .foregroundColor(.textPrimary)
                }
            }

            // Progress

            HStack(spacing: 10) {

                GeometryReader { geo in

                    ZStack(alignment: .leading) {

                        Capsule()
                            .fill(Color(hex: "#89DBA6").opacity(0.25))
                            .frame(height: 6)

                        Capsule()
                            .fill(
                                loan.status.lowercased() == "closed"
                                ? Color.gray.opacity(0.45)
                                : Color(hex: "#2D8B4E")
                            )
                            .frame(
                                width: geo.size.width * CGFloat(min(loan.paidPercent, 1)),
                                height: 6
                            )
                    }
                }
                .frame(height: 6)

                Text("\(Int(loan.paidPercent * 100))% repaid")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "#2D8B4E"))
                    .fixedSize()
            }

            Rectangle()
                .fill(Color(hex: "#89DBA6").opacity(0.25))
                .frame(height: 1)

            // Bottom Row

            HStack {

                VStack(alignment: .leading, spacing: 2) {

                    Text("Monthly EMI")
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)

                    Text(
                        loan.emiAmount > 0
                        ? "₹\(formatIndian(loan.emiAmount))"
                        : "N/A"
                    )
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.textPrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {

                    Text("Next Due")
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)

                    Text(
                        loan.status.lowercased() == "closed"
                        ? "Paid off"
                        : formattedDate(loan.nextDueDate)
                    )
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.textPrimary)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .stroke(
                Color(hex: "#89DBA6").opacity(0.25),
                lineWidth: 1
            )
        )
        .shadow(
            color: Color(hex: "#89DBA6").opacity(0.12),
            radius: 10,
            x: 0,
            y: 4
        )
    }

    // MARK: - Status Badge

    private func statusBadge(for status: String) -> some View {

        let (title, fg, bg): (String, Color, Color) = {

            switch status.lowercased() {

            case "active":
                return (
                    "Active",
                    Color(hex: "#2D8B4E"),
                    Color(hex: "#89DBA6").opacity(0.20)
                )

            case "closed":
                return (
                    "Closed",
                    .textSecondary,
                    Color.surfaceMuted
                )

            case "submitted",
                 "pending",
                 "approved",
                 "draft",
                 "under_review":

                return (
                    "Pending",
                    Color.orange,
                    Color.orange.opacity(0.12)
                )

            case "rejected":

                return (
                    "Rejected",
                    .red,
                    .red.opacity(0.10)
                )

            default:

                return (
                    status.capitalized,
                    .textSecondary,
                    Color.surfaceMuted
                )
            }

        }()

        return Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(fg)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(bg)
            .clipShape(Capsule())
    }

    // MARK: - Empty State

    private var emptyState: some View {

        VStack(spacing: 14) {

            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 42))
                .foregroundColor(Color(hex: "#2D8B4E"))

            Text("No \(selectedFilter.rawValue.lowercased()) loans")
                .font(
                    .system(
                        size: 20,
                        weight: .bold,
                        design: .rounded
                    )
                )

            Text("Try another filter to view a different loan set.")
                .font(.system(size: 15))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    Color(hex: "#89DBA6").opacity(0.25),
                    lineWidth: 1
                )
        )
    }
    // MARK: - Helpers

    private func loanIcon(for type: String) -> String {

        switch type.lowercased() {

        case "home":
            return "house.fill"

        case "vehicle":
            return "car.fill"

        case "business":
            return "briefcase.fill"

        case "education":
            return "graduationcap.fill"

        case "personal":
            return "person.fill"

        case "gold":
            return "gift.fill"

        case "agriculture":
            return "leaf.fill"

        default:
            return "indianrupeesign.circle.fill"
        }
    }

    private func formattedDate(_ rawDate: String?) -> String {

        guard let raw = rawDate else {
            return "N/A"
        }

        if let date = Self.parseDateString(raw) {

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "MMM d"

            return formatter.string(from: date)
        }

        return raw
    }

    private func formatIndian(_ value: Double) -> String {

        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0

        return formatter.string(from: NSNumber(value: value))
            ?? "\(Int(value))"
    }

    static func parseDateString(_ raw: String) -> Date? {

        let iso = ISO8601DateFormatter()

        if let date = iso.date(from: raw) {
            return date
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let formats = [
            "yyyy-MM-dd",
            "dd MMM yyyy",
            "d MMM yyyy",
            "yyyy-MM-dd HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ssZ"
        ]

        for format in formats {

            formatter.dateFormat = format

            if let date = formatter.date(from: raw) {
                return date
            }
        }

        return nil
    }

    // MARK: - Load Loans

    private func loadLoans(resetFilter: Bool) async {

        isLoading = true
        defer { isLoading = false }

        guard let userId = authViewModel.currentUser?.id else {
            return
        }

        do {

            loans = try await LoanService.shared.fetchDetailedUserLoans(
                userId: userId
            )

            if resetFilter {
                selectedFilter = .all
            }

        } catch {

            print("Failed to load loans:", error)
        }
    }
} // End of LoansListView

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

        case "home":
            return "house.fill"

        case "vehicle":
            return "car.fill"

        case "business":
            return "briefcase.fill"

        case "education":
            return "graduationcap.fill"

        case "personal":
            return "person.fill"

        case "gold":
            return "gift.fill"

        case "agriculture":
            return "leaf.fill"

        default:
            return "indianrupeesign.circle.fill"
        }
    }
}
