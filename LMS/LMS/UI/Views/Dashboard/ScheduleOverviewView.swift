import SwiftUI
import Auth

struct ScheduleOverviewView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var loans: [LoanListItem] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    headerCard

                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else if scheduleItems.isEmpty {
                        emptyState
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(scheduleItems) { item in
                                NavigationLink {
                                    LoanDetailView(loan: item.loan)
                                } label: {
                                    scheduleRow(item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(20)
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
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadLoans()
            }
            .refreshable {
                await loadLoans()
            }
            .onReceive(NotificationCenter.default.publisher(for: .loanDataDidChange)) { _ in
                Task { await loadLoans() }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming Schedule")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(.textPrimary)

            Text("Track the next due dates for each active loan.")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.9), lineWidth: 1)
        )
    }

    private var scheduleItems: [ScheduleItem] {
        loans
            .compactMap { loan -> ScheduleItem? in
                guard let due = loan.nextDueDate,
                      let dueDate = LoansListView.parseDateString(due) else { return nil }
                return ScheduleItem(loan: loan, dueDate: dueDate)
            }
            .sorted { $0.dueDate < $1.dueDate }
    }

    private func scheduleRow(_ item: ScheduleItem) -> some View {
        let overdue = item.dueDate < Calendar.current.startOfDay(for: Date())
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#EEF4EA"))
                Image(systemName: item.loan.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.accentGreen)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.loan.name)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.textPrimary)
                    .lineLimit(2)

                Text(item.loan.loanType.capitalized)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(overdue ? "Overdue" : "Due")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(overdue ? .accentRed : .accentGreen)

                Text(formattedDate(item.dueDate))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.9), lineWidth: 1)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 40))
                .foregroundColor(.accentGreen)
            Text("No upcoming schedule")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.textPrimary)
            Text("Once loans are active, their next due dates will appear here.")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.white.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.9), lineWidth: 1)
        )
    }

    private func loadLoans() async {
        isLoading = true
        defer { isLoading = false }

        do {
            guard let userId = authViewModel.currentUser?.id else { return }
            loans = try await LoanService.shared.fetchDetailedUserLoans(userId: userId)
        } catch {
            print("Failed to load schedule loans: \(error)")
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

private struct ScheduleItem: Identifiable {
    let id = UUID()
    let loan: LoanListItem
    let dueDate: Date
}
