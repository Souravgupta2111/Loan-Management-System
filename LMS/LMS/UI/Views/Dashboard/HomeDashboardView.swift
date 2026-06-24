import SwiftUI
import Supabase

/// Home Dashboard (design.md §8.3)
/// Matches the screenshot layout with hero card, PAY EMI, quick actions, loan cards.
struct HomeDashboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var userName: String = "User"
    @State private var loans: [LoanSummary] = []
    @State private var hasLoaded = false
    @State private var showProfile = false
    @State private var upcomingEMI: UpcomingEMI?
    @State private var pendingApplicationsCount = 0

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Spacing.xxl) {
                    // MARK: - Hero Card
                    heroCard

                    if loans.isEmpty && hasLoaded {
                        emptyState
                    } else if !loans.isEmpty {
                        // MARK: - Upcoming EMI / PAY EMI Card
                        upcomingEMICard

                        // MARK: - Quick Actions
                        quickActionsSection

                        // MARK: - My Loans
                        myLoansSection
                    }
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, 100)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(greeting)
                            .font(.caption2)
                            .foregroundColor(.textSecondary)
                        Text(userName)
                            .font(.bodyLarge)
                            .foregroundColor(.textPrimary)
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        // notifications
                    } label: {
                        Image(systemName: "bell")
                            .font(.system(size: 16))
                            .foregroundColor(.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(Color.surfaceMuted)
                            .clipShape(Circle())
                    }
                    Button { showProfile = true } label: {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 16))
                            .foregroundColor(.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(Color.surfaceMuted)
                            .clipShape(Circle())
                    }
                }
            }
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

    // MARK: - Hero Card (matches screenshot first panel)
    private var heroCard: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            if loans.isEmpty && hasLoaded {
                Text("Welcome!")
                    .font(.label)
                    .foregroundColor(.textSecondary)
                Text("Get started")
                    .font(.heroAmount)
                    .foregroundColor(.textPrimary)
            } else {
                Text("Total Outstanding")
                    .font(.label)
                    .foregroundColor(.textSecondary)

                AmountDisplay(amount: totalOutstanding, style: .hero)

                if let nextEMI = upcomingEMI {
                    HStack(spacing: Spacing.sm) {
                        Text("+₹\(formatIndian(nextEMI.amount)) due in \(nextEMI.daysUntilDue) days")
                            .font(.caption2)
                            .foregroundColor(.accentGreen)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.accentGreenBg)
                            .clipShape(Capsule())
                    }
                }

                // Stat pills (like screenshot: "2 Active Loans" pills)
                HStack(spacing: Spacing.sm) {
                    DarkStatPill(count: activeLoansCount, label: "Active\nLoans")
                    
                    NavigationLink {
                        ApplicationsListView()
                    } label: {
                        DarkStatPill(count: pendingApplicationsCount, label: "Pending\nApps")
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
                colors: [Color.gradientMintStart, Color.gradientMintEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: Corner.xl))
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
    }

    // MARK: - Empty State (no loans)
    private var emptyState: some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: "doc.text.magnifyingglass")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .foregroundColor(.accentMint)

            Text("No loans yet")
                .font(.cardTitle)
                .foregroundColor(.textPrimary)

            Text("Apply for your first loan and manage everything from one place.")
                .font(.bodyRegular)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)

            PillButton(title: "Apply Now", style: .primary) {
                // Navigate to loan application
            }
            .padding(.horizontal, Spacing.xxxl)
        }
        .padding(.vertical, Spacing.xxxl)
    }

    // MARK: - Upcoming EMI / PAY EMI Card (like "OPTIMIZE" in screenshot)
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

                    // PAY EMI button (replaces "OPTIMIZE" from screenshot)
                    PillButton(title: "Pay EMI", style: .primary) {
                        // Payment flow
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

    // MARK: - Quick Actions (3-column grid like screenshot)
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Quick Actions")
                .font(.cardTitle)
                .foregroundColor(.textPrimary)

            HStack(spacing: Spacing.md) {
                quickActionCard(icon: "doc.text.fill", label: "Apply\nNow", color: .accentGreen)
                quickActionCard(icon: "bubble.left.fill", label: "Message\nStaff", color: .accentBeigeDk)
                quickActionCard(icon: "calendar.badge.clock", label: "EMI\nSchedule", color: .accentLavender)
            }
        }
    }

    private func quickActionCard(icon: String, label: String, color: Color) -> some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(color)
            Text(label)
                .font(.label)
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.lg)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Corner.lg))
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: Corner.lg)
                .stroke(Color.border, lineWidth: 0.5)
        )
    }

    // MARK: - My Loans Section (like bottom cards in screenshot)
    private var myLoansSection: some View {
        VStack(spacing: Spacing.md) {
            SectionHeader(title: "My Loans") {
                // See all
            }

            ForEach(loans) { loan in
                loanRowCard(loan)
            }
        }
    }

    private func loanRowCard(_ loan: LoanSummary) -> some View {
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
                HStack(spacing: 4) {
                    Text(loan.changePercent >= 0 ? "↑" : "↓")
                        .foregroundColor(loan.changePercent >= 0 ? .accentGreen : .accentRed)
                    Text(String(format: "%.1f%%", abs(loan.changePercent)))
                        .foregroundColor(loan.changePercent >= 0 ? .accentGreen : .accentRed)
                }
                .font(.badge)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(loan.changePercent >= 0 ? Color.accentGreenBg : Color.accentRedBg)
                .clipShape(Capsule())
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

    // MARK: - Helpers
    private var totalOutstanding: Double {
        loans.reduce(0) { $0 + $1.outstandingAmount }
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
            // Get user name
            if let userId = authViewModel.currentUser?.id {
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
                loans = try await LoanService.shared.fetchUserLoans(userId: userId)

                struct ApplicationRow: Decodable { let id: UUID }
                let applications: [ApplicationRow] = try await SupabaseManager.shared.client
                    .from("loan_applications").select("id")
                    .eq("borrower_id", value: userId)
                    .or("status.eq.submitted,status.eq.under_review,status.eq.approved,status.eq.sent_back")
                    .execute().value
                pendingApplicationsCount = applications.count

                if let firstLoan = loans.first(where: { $0.status == "active" }) {
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

struct LoanSummary: Identifiable {
    let id: UUID
    let name: String
    let loanType: String
    let outstandingAmount: Double
    let emiAmount: Double
    let status: String
    let paidPercent: Double
    let changePercent: Double
}
