import SwiftUI
import Supabase
import Auth

struct LoansListView: View {
    @Environment(\.dismiss) private var dismiss

    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var themeManager: AppThemeManager

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
                    colors: [Color.gradientMintStart, Color.gradientMintEnd, Color.gradientMintStart],
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
        .id(themeManager.selectedPalette)
    }
    // MARK: - Balance Hero Card

    private var balanceHeroCard: some View {

        VStack(alignment: .leading, spacing: 14) {

            // Icon + Title
            HStack(spacing: 10) {

                ZStack {
                    Circle()
                        .fill(Color.accentGreenBg)
                        .frame(width: 40, height: 40)

                    Image(systemName: "indianrupeesign.circle.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(Color.accentGreen)
                }

                Text("Total Balance")
                    .font(.headline.weight(.bold)).fontDesign(.rounded)
                    .foregroundColor(Color(hex: "#1A1A1A"))

                Spacer()
            }

            // Amount
            VStack(alignment: .leading, spacing: 3) {

                Text("Outstanding Balance")
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "#6B6B6B"))

                Text("₹ \(formatIndian(totalOutstanding))")
                    .font(.largeTitle.weight(.bold)).fontDesign(.rounded)
                    .foregroundColor(Color(hex: "#1A1A1A"))
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(cornerRadius: 22, tint: Color.accentGreen, tintOpacity: 0.06)
    }

    //
    // MARK: - Filter Section
    //

    private var filterSection: some View {

        VStack(alignment: .leading, spacing: 10) {

            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.accentGreen)
                Text("FILTER LOANS")
                    .font(.subheadline.weight(.semibold)).fontDesign(.rounded)
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
                    ? Color.accentGreen
                    : Color.clear
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected
                            ? Color.clear
                            : Color.accentGreen.opacity(0.3),
                            lineWidth: 1
                        )
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

                Text(sectionTitle)
                    .font(
                        .system(
                            size: 20,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundColor(Color(hex: "#1A1A1A"))

                Text(sectionSubtitle)
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "#6B6B6B"))
            }

            Spacer()
        }
    }

    private var sectionTitle: String {
        switch selectedFilter {
        case .all:
            return "Current Loans"
        default:
            return "\(selectedFilter.rawValue) Loans"
        }
    }

    private var sectionSubtitle: String {
        switch selectedFilter {
        case .all:
            return "\(filteredLoans.count) of \(loans.count) loans"
        default:
            let count = filteredLoans.count
            let name = selectedFilter.rawValue.lowercased()
            return "\(count) \(name) loan\(count == 1 ? "" : "s")"
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
        let totalEMIs = loan.emiSchedule?.count ?? (loan.requestedTenure ?? 12)
        let paidEMIs = loan.emiAmount > 0 ? Int(loan.paidAmount / loan.emiAmount) : 0

        return VStack(alignment: .leading, spacing: 10) {

            // Top Row

            HStack(alignment: .top, spacing: 10) {

                ZStack {

                    Circle()
                        .fill(Color.accentGreenBg)
                        .frame(width: 38, height: 38)

                    Image(systemName: loanIcon(for: loan.loanType))
                        .font(.headline.weight(.semibold))
                        .foregroundColor(Color.accentGreen)
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
                            .multilineTextAlignment(.leading)
                        
                        if let appId = loan.applicationId, let count = unreadMessageCounts[appId], count > 0 {
                            ZStack {
                                Circle()
                                    .fill(Color.accentGreen)
                                    .frame(width: 18, height: 18)
                                Text("\(count)")
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }

                    statusBadge(for: loan.status)
                        .offset(x: -4) // Optical alignment
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {

                    if loan.status.lowercased() == "closed" {
                        Text("Total Amount")
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "#6B6B6B"))

                        Text("₹\(formatIndian(loan.amount))")
                            .font(
                                .system(
                                    size: 19,
                                    weight: .bold,
                                    design: .rounded
                                )
                            )
                            .foregroundColor(Color(hex: "#1A1A1A"))
                    } else {
                        Text("Balance")
                            .font(.subheadline)
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
            }

            // Progress

            if loan.status.lowercased() == "active" {
                HStack(spacing: 8) {

                    GeometryReader { geo in

                        ZStack(alignment: .leading) {

                            Capsule()
                                .fill(Color.themeGreen.opacity(0.5))
                                .frame(height: 5)

                            Capsule()
                                .fill(Color.accentGreen)
                                .frame(
                                    width: geo.size.width * CGFloat(min(loan.paidPercent, 1)),
                                    height: 5
                                )
                        }
                    }
                    .frame(height: 5)

                    Text("\(Int(loan.paidPercent * 100))% repaid")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color.accentGreen)
                        .fixedSize()
                }
            }

            Divider()
                .background(Color.white.opacity(0.3))

            // Bottom Row

            if loan.status.lowercased() == "active" || loan.status.lowercased() == "overdue" {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Monthly EMI")
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "#6B6B6B"))

                        Text(
                            loan.emiAmount > 0
                            ? "₹\(formatIndian(loan.emiAmount))"
                            : "N/A"
                        )
                        .font(.body.weight(.semibold))
                        .foregroundColor(Color(hex: "#1A1A1A"))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Next Due")
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "#6B6B6B"))

                        Text(formattedDate(loan.nextDueDate))
                        .font(.body.weight(.semibold))
                        .foregroundColor(Color(hex: "#1A1A1A"))
                    }
                }
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Remarks")
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "#6B6B6B"))

                        Text(statusRemark(for: loan))
                            .font(.body.weight(.semibold))
                            .foregroundColor(Color(hex: "#1A1A1A"))
                    }

                    Spacer()
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
                    Color.accentGreen,
                    Color.accentGreenBg
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

            case "sent_back":
                return (
                    "Sent_Back",
                    Color(hex: "#E65100"),
                    Color(hex: "#FFEDD5")
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
            .font(.caption.weight(.semibold))
            .foregroundColor(fg)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(bg)
            .clipShape(Capsule())
    }

    // MARK: - Status Remark

    private func statusRemark(for loan: LoanListItem) -> String {
        switch loan.status.lowercased() {
        case "submitted", "pending":
            return "Awaiting Initial Review"
        case "under_review":
            return "Under Manager Review"
        case "approved":
            return "Pending Your Acceptance"
        case "pending_acceptance":
            return "Awaiting Agreement"
        case "pending_disbursal":
            return "Processing Disbursal"
        case "sent_back":
            return "Action Required"
        case "rejected":
            if let reason = loan.rejectionReason, !reason.isEmpty {
                let lower = reason.lowercased()
                if lower.contains("borrower") || lower.contains("user") {
                    return "Rejected by borrower"
                } else {
                    return "Rejected by manager"
                }
            }
            return "Rejected by manager"
        case "closed":
            return "Paid in Full"
        case "draft":
            return "Incomplete Application"
        default:
            return "Processing"
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {

        VStack(spacing: 12) {

            Image(systemName: "doc.text.magnifyingglass")
                .font(.title)
                .foregroundColor(Color.themeGreen)

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
                .font(.subheadline)
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
