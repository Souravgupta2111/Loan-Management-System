import SwiftUI
import Supabase
import Auth

struct LoansListView: View {
    @Environment(\.dismiss) private var dismiss

    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var selectedFilter: LoanFilter = .all
    @State private var loans: [LoanListItem] = []
    @State private var isLoading = true
    @State private var unreadMessageCounts: [UUID: Int] = [:]
    @State private var messagesChannel: RealtimeChannelV2? = nil

    enum LoanFilter: String, CaseIterable, Identifiable {

        case all = "All"
        case active = "Active"
        case pendingApproval = "Pending"
        case overdue = "Overdue"
        case closed = "Closed"
        case rejected = "Rejected"

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
                    "under_review",
                    "sent_back",
                    "pending_acceptance",
                    "pending_disbursal"
                ].contains(loan.status.lowercased())

            case .overdue:
                return isOverdue(loan)

            case .closed:
                return loan.status.lowercased() == "closed"
                
            case .rejected:
                return loan.status.lowercased() == "rejected"
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
        loans
            .filter { $0.status.lowercased() == "active" }
            .reduce(0) { $0 + $1.remainingAmount }
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

                VStack(alignment: .leading, spacing: 16) {

                    balanceHeroCard
                        .padding(.top, 4)

                    filterSection

                    sectionHeading

                    loanCardsList
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
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
            .navigationBarBackButtonHidden(true)
            .navigationTitle("My Loans")
            .navigationBarTitleDisplayMode(.large)

            .task {
                await loadLoans(resetFilter: false)
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
            .onDisappear {
                unsubscribeMessages()
                messagesChannel = nil
            }
        }
    }
    // MARK: - Balance Hero Card

    private var balanceHeroCard: some View {

        VStack(alignment: .leading, spacing: 14) {

            // Icon + Title
            HStack(spacing: 10) {

                ZStack {
                    Circle()
                        .fill(Color(hex: "#E8F5EC"))
                        .frame(width: 40, height: 40)

                    Image(systemName: "indianrupeesign.circle.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(Color(hex: "#2D8B4E"))
                }

                Text("Total Balance")
                    .font(.system(size: 18,
                                  weight: .bold,
                                  design: .rounded))
                    .foregroundColor(Color(hex: "#1A1A1A"))

                Spacer()
            }

            // Amount
            VStack(alignment: .leading, spacing: 3) {

                Text("Outstanding Balance")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#6B6B6B"))

                Text("₹ \(formatIndian(totalOutstanding))")
                    .font(.system(size: 30,
                                  weight: .bold,
                                  design: .rounded))
                    .foregroundColor(Color(hex: "#1A1A1A"))
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(cornerRadius: 22, tint: Color(hex: "#2D8B4E"), tintOpacity: 0.06)
    }

    //
    // MARK: - Filter Section
    //

    private var filterSection: some View {

        VStack(alignment: .leading, spacing: 10) {

            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "#2D8B4E"))
                Text("FILTER LOANS")
                    .font(.system(size: 13,
                                  weight: .semibold,
                                  design: .rounded))
                    .foregroundColor(Color(hex: "#6B6B6B"))
                    .tracking(0.8)
                    .fixedSize()
            }

            ScrollView(.horizontal, showsIndicators: false) {

                HStack(spacing: 8) {

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
                        size: 15,
                        weight: isSelected ? .semibold : .regular
                    )
                )
                .foregroundColor(
                    isSelected ? .white : Color(hex: "#6B6B6B")
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isSelected
                    ? Color(hex: "#2D8B4E")
                    : Color.clear
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected
                            ? Color.clear
                            : Color.white.opacity(0.5),
                            lineWidth: 1
                        )
                )
                .liquidGlass(cornerRadius: 999)
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
                            size: 20,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundColor(Color(hex: "#1A1A1A"))

                Text("\(filteredLoans.count) of \(loans.count) loans")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#6B6B6B"))
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

                LazyVStack(spacing: 10) {

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
    }

    // MARK: - Loan Card

    private func loanCard(_ loan: LoanListItem) -> some View {

        VStack(alignment: .leading, spacing: 10) {

            // Top Row

            HStack(alignment: .top, spacing: 10) {

                ZStack {

                    Circle()
                        .fill(Color(hex: "#E8F5EC"))
                        .frame(width: 38, height: 38)

                    Image(systemName: loanIcon(for: loan.loanType))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(hex: "#2D8B4E"))
                }

                VStack(alignment: .leading, spacing: 3) {

                    HStack(spacing: 6) {
                        Text(loan.name)
                            .font(
                                .system(
                                    size: 17,
                                    weight: .bold,
                                    design: .rounded
                                )
                            )
                            .foregroundColor(Color(hex: "#1A1A1A"))
                            .lineLimit(1)
                        
                        if let appId = loan.applicationId, let count = unreadMessageCounts[appId], count > 0 {
                            ZStack {
                                Circle()
                                    .fill(Color.accentGreen)
                                    .frame(width: 18, height: 18)
                                Text("\(count)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }

                    statusBadge(for: loan.status)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {

                    Text("Balance")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#6B6B6B"))

                    Text("₹\(formatIndian(loan.remainingAmount))")
                        .font(
                            .system(
                                size: 19,
                                weight: .bold,
                                design: .rounded
                            )
                        )
                        .foregroundColor(Color(hex: "#1A1A1A"))
                }
            }

            // Progress

            if loan.paidPercent > 0 {
                HStack(spacing: 8) {

                    GeometryReader { geo in

                        ZStack(alignment: .leading) {

                            Capsule()
                                .fill(Color(hex: "#C8E6D0").opacity(0.5))
                                .frame(height: 5)

                            Capsule()
                                .fill(
                                    loan.status.lowercased() == "closed"
                                    ? Color.gray.opacity(0.45)
                                    : Color(hex: "#2D8B4E")
                                )
                                .frame(
                                    width: geo.size.width * CGFloat(min(loan.paidPercent, 1)),
                                    height: 5
                                )
                        }
                    }
                    .frame(height: 5)

                    Text("\(Int(loan.paidPercent * 100))% repaid")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#2D8B4E"))
                        .fixedSize()
                }
            }

            Divider()
                .background(Color.white.opacity(0.3))

            // Bottom Row

            HStack {

                VStack(alignment: .leading, spacing: 2) {

                    Text("Monthly EMI")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#6B6B6B"))

                    Text(
                        loan.emiAmount > 0
                        ? "₹\(formatIndian(loan.emiAmount))"
                        : "N/A"
                    )
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "#1A1A1A"))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {

                    Text("Next Due")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#6B6B6B"))

                    Text(
                        loan.status.lowercased() == "closed"
                        ? "Paid off"
                        : formattedDate(loan.nextDueDate)
                    )
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "#1A1A1A"))
                }
            }
        }
        .padding(14)
        .liquidGlass(cornerRadius: 20)
    }

    // MARK: - Status Badge

    private func statusBadge(for status: String) -> some View {

        let (title, fg, bg): (String, Color, Color) = {

            switch status.lowercased() {

            case "active":
                return (
                    "Active",
                    Color(hex: "#2D8B4E"),
                    Color(hex: "#E8F5EC")
                )

            case "closed":
                return (
                    "Closed",
                    Color(hex: "#6B6B6B"),
                    Color(hex: "#F5F5F0")
                )

            case "submitted",
                 "pending",
                 "approved",
                 "draft",
                 "under_review":

                return (
                    "Pending",
                    Color(hex: "#E8A830"),
                    Color(hex: "#FFF3D6")
                )

            case "rejected":

                return (
                    "Rejected",
                    Color(hex: "#D94040"),
                    Color(hex: "#FDE8E8")
                )

            case "npa":
                return (
                    "NPA",
                    Color(hex: "#D94040"),
                    Color(hex: "#FDE8E8")
                )

            case "restructured":
                return (
                    "Restructured",
                    Color(hex: "#E8A830"),
                    Color(hex: "#FFF3D6")
                )

            case "written_off":
                return (
                    "Written Off",
                    Color(hex: "#6B6B6B"),
                    Color(hex: "#F5F5F0")
                )

            default:

                return (
                    status.capitalized,
                    Color(hex: "#6B6B6B"),
                    Color(hex: "#F5F5F0")
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

        VStack(spacing: 12) {

            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(Color(hex: "#C8E6D0"))

            Text(selectedFilter == .all ? "No loans yet" : "No \(selectedFilter.rawValue.lowercased()) loans")
                .font(
                    .system(
                        size: 18,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundColor(Color(hex: "#1A1A1A"))

            Text("Try another filter to view a different loan set.")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#6B6B6B"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .liquidGlass(cornerRadius: 24)
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
            await fetchUnreadCounts(userId: userId)
            
            if messagesChannel == nil {
                subscribeToUnreadMessages(userId: userId)
            }

            if resetFilter {
                selectedFilter = .all
            }

        } catch {

            print("Failed to load loans:", error)
        }
    }
    
    private func fetchUnreadCounts(userId: UUID) async {
        do {
            struct UnreadMessageRow: Decodable {
                let application_id: UUID
            }
            let unreadMessages: [UnreadMessageRow] = try await SupabaseManager.shared.client
                .from("messages")
                .select("application_id")
                .eq("receiver_id", value: userId.uuidString)
                .eq("is_read", value: false)
                .execute()
                .value
            
            var counts: [UUID: Int] = [:]
            for msg in unreadMessages {
                counts[msg.application_id, default: 0] += 1
            }
            self.unreadMessageCounts = counts
        } catch {
            print("Failed to fetch unread messages counts in LoansListView: \(error)")
        }
    }
    
    private func subscribeToUnreadMessages(userId: UUID) {
        let channel = SupabaseManager.shared.client.realtimeV2.channel("public:messages:loanslist_\(userId.uuidString)")
        self.messagesChannel = channel
        
        let insertions = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "messages",
            filter: .eq("receiver_id", value: userId)
        )
        
        Task {
            do {
                try await channel.subscribeWithError()
                for await _ in insertions {
                    await fetchUnreadCounts(userId: userId)
                }
            } catch {
                print("Failed to subscribe to unread messages in LoansListView: \(error)")
            }
        }
    }
    
    private func unsubscribeMessages() {
        if let channel = messagesChannel {
            Task {
                await SupabaseManager.shared.client.realtimeV2.removeChannel(channel)
            }
        }
    }
} // End of LoansListView

// MARK: - LoanListItem Model

struct LoanListItemEMI: Equatable {
    let amount: Double
    let status: String
    let dueDate: String
}

struct LoanTimelineEvent: Equatable {
    let title: String
    let date: String
    let remarks: String?
}

struct LoanDocumentEvent: Equatable {
    let title: String
    let documentType: String
    let category: String
    let storagePath: String
    let uploadDate: String
    let icon: String
}

struct LoanListItem: Identifiable {

    let id: UUID
    let applicationId: UUID?
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
    let requestedTenure: Int?
    let emiSchedule: [LoanListItemEMI]?
    let timeline: [LoanTimelineEvent]?
    let documents: [LoanDocumentEvent]?
    let sentBackReason: String?
    let rejectionReason: String?

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
