import SwiftUI
import Supabase
import Auth
/// My Loans List (design.md §8.4)
/// Segmented control: Active / Closed / All, loan cards with progress bars.
struct LoansListView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedFilter: LoanFilter = .active
    @State private var loans: [LoanListItem] = []

    enum LoanFilter: String, CaseIterable {
        case active = "Active"
        case closed = "Closed"
        case all = "All"
    }

    var filteredLoans: [LoanListItem] {
        switch selectedFilter {
        case .active: return loans.filter { $0.status == "active" }
        case .closed: return loans.filter { $0.status == "closed" }
        case .all:    return loans
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented control
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(LoanFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.md)

                // Loan list
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: Spacing.md) {
                        if filteredLoans.isEmpty {
                            VStack(spacing: Spacing.lg) {
                                Image(systemName: "tray")
                                    .font(.system(size: 48))
                                    .foregroundColor(.textTertiary)
                                Text("No \(selectedFilter.rawValue.lowercased()) loans")
                                    .font(.bodyLarge)
                                    .foregroundColor(.textSecondary)
                            }
                            .padding(.top, 80)
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
                    .padding(.horizontal, Spacing.xl)
                    .padding(.bottom, 100)
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("My Loans")
            .task {
                if let userId = authViewModel.currentUser?.id {
                    if let fetchedLoans = try? await LoanService.shared.fetchDetailedUserLoans(userId: userId) {
                        loans = fetchedLoans
                    }
                }
            }
        }
    }

    private func loanCard(_ loan: LoanListItem) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: loan.icon)
                    .font(.system(size: 18))
                    .foregroundColor(.textSecondary)
                    .frame(width: 40, height: 40)
                    .background(Color.surfaceMuted)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(loan.name)
                        .font(.bodyLarge)
                        .foregroundColor(.textPrimary)
                    Text(loan.loanNumber)
                        .font(.caption2)
                        .foregroundColor(.textTertiary)
                }

                Spacer()

                StatusBadge(status: loan.status)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("₹\(formatIndian(loan.amount))")
                        .font(.cardTitle)
                        .foregroundColor(.textPrimary)
                }
                Spacer()
                Text("EMI: ₹\(formatIndian(loan.emiAmount))/mo")
                    .font(.label)
                    .foregroundColor(.textSecondary)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                LoanProgressBar(
                    progress: loan.paidPercent,
                    color: loan.status == "closed" ? .textTertiary : .accentGreen
                )
                Text("\(Int(loan.paidPercent * 100))%")
                    .font(.caption2)
                    .foregroundColor(.textSecondary)
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

    private func formatIndian(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
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
    let paidAmount: Double
    let remainingAmount: Double

    var icon: String {
        switch loanType.lowercased() {
        case "home":       return "house.fill"
        case "vehicle":    return "car.fill"
        case "business":   return "building.2.fill"
        case "education":  return "graduationcap.fill"
        case "personal":   return "person.fill"
        case "agriculture": return "leaf.fill"
        default:           return "indianrupeesign.circle.fill"
        }
    }
}
