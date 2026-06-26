import SwiftUI
import Supabase

/// Home Dashboard (design.md §8.3)
/// Matches the screenshot layout with hero card, PAY EMI, quick actions, loan cards.
struct HomeDashboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var userName: String = "User"
    @State private var loans: [LoanListItem] = []
    @State private var hasLoaded = false
    @State private var showProfile = false
    @State private var upcomingEMI: UpcomingEMI?
    @State private var pendingApplicationsCount = 0
    @State private var pendingApplications: [LoanService.ApplicationListItem] = []
    @State private var activeLoanId: UUID? = nil

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Spacing.xxl) {
                    // MARK: - Custom Header (Prevents Truncation)
                    premiumHeader

                    // MARK: - Hero Card (Emerald Design)
                    heroCard

                    // MARK: - Quick Actions (Always Visible & Connected)
                    quickActionsSection

                    // MARK: - Active Applications (real-time tracking US-08)
                    if pendingApplicationsCount > 0 {
                        pendingApplicationsSection
                    }

                    // MARK: - Active Loans / EMI / My Loans
                    if loans.isEmpty && hasLoaded {
                        noLoansTip
                    } else if !loans.isEmpty {
                        // MARK: - Upcoming EMI / PAY EMI Card
                        upcomingEMICard

                        // MARK: - My Loans
                        myLoansSection
                    }
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, 100)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar) // Hide native navigation bar to avoid truncation
            .sheet(isPresented: $showProfile) {
                ProfileView()
                    .environmentObject(authViewModel)
            }
            .task {
                await loadData()
            }
        }
    }

    // MARK: - Greeting
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        default: return "Good Evening"
        }
    }

    // MARK: - Premium Header
    private var premiumHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.caption2)
                    .foregroundColor(.textSecondary)
                Text(userName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)
            }
            
            Spacer()
            
            HStack(spacing: Spacing.sm) {
                Button {
                    // Action for viewing notifications
                } label: {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.textSecondary)
                        .frame(width: 40, height: 40)
                        .background(Color.surfaceMuted)
                        .clipShape(Circle())
                }
                
                Button { showProfile = true } label: {
                    Image(systemName: "person.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.textSecondary)
                        .frame(width: 40, height: 40)
                        .background(Color.surfaceMuted)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.top, Spacing.lg)
    }

    // MARK: - Hero Card (matches screenshot first panel, redesigned for luxury look)
    private var heroCard: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            if loans.isEmpty && hasLoaded {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Unlock Financial\nOpportunities")
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .lineSpacing(2)
                        
                        Text("Get instant approval loans at attractive interest rates tailored for you.")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.white.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.trailing, 10)
                        
                        NavigationLink {
                            LoanApplicationFlowView()
                        } label: {
                            HStack {
                                Text("Apply Now")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 16))
                            }
                            .foregroundColor(Color(hex: "#164B2D"))
                            .padding(.horizontal, 22)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, Spacing.xs)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .font(.system(size: 60, weight: .ultraLight))
                        .foregroundColor(.white.opacity(0.2))
                        .offset(x: 10, y: -10)
                }
            } else {
                Text("Total Outstanding")
                    .font(.label)
                    .foregroundColor(.white.opacity(0.7))

                AmountDisplay(amount: totalOutstanding, style: .hero, color: .white)

                // Overdue / Due Date pill with logic fix (US-20)
                if let nextEMI = upcomingEMI {
                    HStack(spacing: Spacing.sm) {
                        if nextEMI.daysUntilDue < 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text("₹\(formatIndian(nextEMI.amount)) Overdue by \(abs(nextEMI.daysUntilDue)) days")
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.accentRed)
                            .clipShape(Capsule())
                        } else if nextEMI.daysUntilDue == 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                Text("₹\(formatIndian(nextEMI.amount)) due today")
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.accentAmber)
                            .clipShape(Capsule())
                        } else {
                            Text("Next EMI ₹\(formatIndian(nextEMI.amount)) in \(nextEMI.daysUntilDue) days")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                }

                // Stat pills (Horizontal glass layout)
                HStack(spacing: Spacing.sm) {
                    DarkStatPill(count: activeLoansCount, label: "Active Loans")
                    
                    NavigationLink {
                        ApplicationsListView()
                    } label: {
                        DarkStatPill(count: pendingApplicationsCount, label: "Pending Apps")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, Spacing.sm)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.xl)
        .background(
            LinearGradient(
                colors: [Color(hex: "#164B2D"), Color(hex: "#247C4A")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: Corner.xl))
        .shadow(color: Color(hex: "#164B2D").opacity(0.15), radius: 16, x: 0, y: 8)
    }

    // MARK: - Upcoming EMI / PAY EMI Card (with functional Pay EMI button)
    private var upcomingEMICard: some View {
        Group {
            if let emi = upcomingEMI {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack {
                        Image(systemName: loanIcon(for: emi.loanType))
                            .font(.system(size: 18))
                            .foregroundColor(.accentBeigeDk)
                            .frame(width: 40, height: 40)
                            .background(Color.accentBeige.opacity(0.5))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(emi.loanName)
                                .font(.bodyLarge)
                                .foregroundColor(.textPrimary)
                            Text("Due \(emi.dueDate)")
                                .font(.caption2)
                                .foregroundColor(.textSecondary)
                        }

                        Spacer()

                        StatusBadge(status: emi.status)
                    }

                    // EMI Amount
                    Text("₹\(formatIndian(emi.amount))")
                        .font(.largeAmount)
                        .foregroundColor(.textPrimary)

                    // Progress bar
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        LoanProgressBar(progress: emi.progress, color: .accentGreen)
                        Text("\(Int(emi.progress * 100))% paid")
                            .font(.caption2)
                            .foregroundColor(.textSecondary)
                    }

                    // PAY EMI button (fully functional navigation link to EMI schedule flow)
                    if let loanId = activeLoanId {
                        NavigationLink {
                            EMIScheduleView(loanId: loanId)
                        } label: {
                            Text("Pay EMI")
                                .font(.bodyLarge)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.md)
                                .background(Color.accentGreen)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Spacing.xl)
                .background(Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: Corner.xl))
                .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: Corner.xl)
                        .stroke(Color.border, lineWidth: 0.5)
                )
            }
        }
    }

    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Quick Actions")
                .font(.cardTitle)
                .foregroundColor(.textPrimary)

            HStack(spacing: Spacing.md) {
                NavigationLink {
                    LoanApplicationFlowView()
                } label: {
                    quickActionCard(icon: "doc.text.fill", label: "Apply\nNow", color: .accentGreen)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    ApplicationsListView()
                } label: {
                    quickActionCard(icon: "bubble.left.fill", label: "Message\nStaff", color: .accentBeigeDk)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    LoansListView()
                } label: {
                    quickActionCard(icon: "calendar.badge.clock", label: "EMI\nSchedule", color: .accentLavender)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func quickActionCard(icon: String, label: String, color: Color) -> some View {
        VStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(color)
            }
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Corner.xl)
                .fill(Color.surface)
                .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
        )
    }

    // MARK: - Pending Applications Section (US-08 tracking)
    private var pendingApplicationsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Active Applications")
                .font(.cardTitle)
                .foregroundColor(.textPrimary)
            
            ForEach(pendingApplications) { app in
                NavigationLink {
                    ApplicationDetailView(application: app)
                } label: {
                    HStack(spacing: Spacing.md) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(app.loanType)
                                .font(.bodyLarge)
                                .foregroundColor(.textPrimary)
                            Text(app.applicationNumber)
                                .font(.caption2)
                                .foregroundColor(.textTertiary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            StatusBadge(status: app.status)
                            Text("₹\(formatIndian(app.amount))")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                    }
                    .padding(Spacing.lg)
                    .background(Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Corner.lg))
                    .shadow(color: .black.opacity(0.02), radius: 8, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: Corner.lg)
                            .stroke(Color.border, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - My Loans Section
    private var myLoansSection: some View {
        VStack(spacing: Spacing.md) {
            SectionHeader(title: "My Loans") {
                // Clicking this see all action switches context or focuses loans list
            }

            ForEach(loans) { loan in
                NavigationLink {
                    LoanDetailView(loan: loan)
                } label: {
                    loanRowCard(loan)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func loanRowCard(_ loan: LoanListItem) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: loanIcon(for: loan.loanType))
                .font(.system(size: 18))
                .foregroundColor(.textSecondary)
                .frame(width: 40, height: 40)
                .background(Color.surfaceMuted)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(loan.name)
                    .font(.bodyLarge)
                    .foregroundColor(.textPrimary)
                Text("₹\(formatIndian(loan.emiAmount))/mo")
                    .font(.caption2)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                StatusBadge(status: loan.status)
                Text(loan.loanNumber)
                    .font(.caption2)
                    .foregroundColor(.textTertiary)
            }
        }
        .padding(Spacing.lg)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Corner.lg))
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: Corner.lg)
                .stroke(Color.border, lineWidth: 0.5)
        )
    }

    // MARK: - Empty State Tip
    private var noLoansTip: some View {
        VStack(spacing: Spacing.xl) {
            ZStack {
                Circle()
                    .fill(Color.accentAmberBg)
                    .frame(width: 80, height: 80)
                Image(systemName: "sparkles")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.accentAmber)
            }
            .shadow(color: Color.accentAmber.opacity(0.2), radius: 10, x: 0, y: 5)
            
            VStack(spacing: Spacing.sm) {
                Text("Ready to get started?")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                
                Text("Select from our active loan products including Personal, Home, and Vehicle loans to unlock your financial goals.")
                    .font(.bodyRegular)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
                    .lineSpacing(4)
            }
            
            NavigationLink {
                LoanApplicationFlowView()
            } label: {
                Text("Explore Loans")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.accentGreen, Color(hex: "#164B2D")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color.accentGreen.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.sm)
        }
        .padding(Spacing.xxl)
        .background(
            RoundedRectangle(cornerRadius: Corner.xl)
                .fill(Color.surface)
                .shadow(color: .black.opacity(0.05), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Corner.xl)
                .stroke(
                    LinearGradient(
                        colors: [Color.border, Color.white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Helpers
    private var totalOutstanding: Double {
        loans.reduce(0) { $0 + $1.remainingAmount }
    }

    private var activeLoansCount: Int {
        loans.filter { $0.status == "active" }.count
    }

    private func loanIcon(for type: String) -> String {
        switch type.lowercased() {
        case "home":       return "house.fill"
        case "vehicle":    return "car.fill"
        case "business":   return "building.2.fill"
        case "education":  return "graduationcap.fill"
        case "personal":   return "person.fill"
        case "agriculture": return "leaf.fill"
        default:           return "indianrupeesign.circle.fill"
        }
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
                // Get user name
                let response: [UserRow] = try await SupabaseManager.shared.client
                    .from("users")
                    .select("full_name")
                    .eq("id", value: userId.uuidString)
                    .execute()
                    .value
                if let row = response.first {
                    userName = row.fullName.isEmpty ? "User" : row.fullName.components(separatedBy: " ").first ?? "User"
                }
                
                // Fetch real loans from Supabase
                loans = try await LoanService.shared.fetchDetailedUserLoans(userId: userId)

                // Fetch real applications
                let apps = try await LoanService.shared.fetchUserApplications(userId: userId)
                pendingApplications = apps.filter { ["submitted", "under_review", "approved", "sent_back"].contains($0.status.lowercased()) }
                pendingApplicationsCount = pendingApplications.count

                // Compute upcoming EMI from active loans
                if let firstLoan = loans.first(where: { $0.status == "active" }) {
                    activeLoanId = firstLoan.id
                    struct EMIRow: Decodable {
                        let total_emi: Double; let penalty_amount: Double
                        let due_date: String; let status: String
                    }
                    let rows: [EMIRow] = try await SupabaseManager.shared.client
                        .from("emi_schedule")
                        .select("total_emi, penalty_amount, due_date, status")
                        .eq("loan_id", value: firstLoan.id)
                        .or("status.eq.upcoming,status.eq.due,status.eq.overdue")
                        .order("due_date", ascending: true).limit(1).execute().value
                    if let row = rows.first {
                        let parser = DateFormatter(); parser.dateFormat = "yyyy-MM-dd"
                        let date = parser.date(from: String(row.due_date.prefix(10)))
                        let days = date.map { Calendar.current.dateComponents([.day], from: Date(), to: $0).day ?? 0 } ?? 0
                        upcomingEMI = UpcomingEMI(
                            loanName: firstLoan.name, loanType: firstLoan.loanType,
                            amount: row.total_emi + row.penalty_amount,
                            dueDate: date?.formatted(date: .abbreviated, time: .omitted) ?? row.due_date,
                            daysUntilDue: days, status: row.status, progress: firstLoan.paidPercent
                        )
                    }
                }
            }

            hasLoaded = true
        } catch {
            hasLoaded = true
            print("Dashboard load error: \(error)")
        }
    }
}

// MARK: - Supporting Models

private struct UserRow: Decodable {
    let fullName: String
    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
    }
}

struct UpcomingEMI {
    let loanName: String
    let loanType: String
    let amount: Double
    let dueDate: String
    let daysUntilDue: Int
    let status: String
    let progress: Double
}
