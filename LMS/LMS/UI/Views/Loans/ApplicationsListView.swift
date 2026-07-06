import SwiftUI
import Supabase
import Auth

struct ApplicationsListView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var applications: [LoanService.ApplicationListItem] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: Spacing.md) {
                    if isLoading {
                        ProgressView()
                            .padding(.top, 80)
                    } else if applications.isEmpty {
                        VStack(spacing: Spacing.lg) {
                            Image(systemName: "tray")
                                .font(.title)
                                .foregroundColor(.textTertiary)
                            Text("No pending applications")
                                .font(.bodyLarge)
                                .foregroundColor(.textSecondary)
                        }
                        .padding(.top, 80)
                    } else {
                        ForEach(applications) { app in
                            NavigationLink {
                                ApplicationDetailView(application: app)
                            } label: {
                                applicationCard(app)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, Spacing.xl)
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
            .navigationTitle("Applications")
            .toolbar(.hidden, for: .tabBar)
            .task { await loadApplications() }
            .refreshable { await loadApplications() }
            .onReceive(NotificationCenter.default.publisher(for: .loanDataDidChange)) { _ in
                Task { await loadApplications() }
            }
        }
    }

    private func applicationCard(_ app: LoanService.ApplicationListItem) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.loanType)
                        .font(.bodyLarge)
                        .foregroundColor(.textPrimary)
                    Text(app.applicationNumber)
                        .font(.caption2)
                        .foregroundColor(.textTertiary)
                }

                Spacer()

                AccessibleStatusBadge(status: app.status)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("₹\(formatIndian(app.amount))")
                        .font(.cardTitle)
                        .foregroundColor(.textPrimary)
                }
                Spacer()
                Text(app.submittedAt)
                    .font(.caption2)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(Spacing.lg)
        .liquidGlass(cornerRadius: 16)
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
    }

    private func formatIndian(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

    private func loadApplications() async {
        isLoading = true
        defer { isLoading = false }

        guard let userId = authViewModel.currentUser?.id else { return }
        do {
            applications = try await LoanService.shared.fetchUserApplications(userId: userId)
        } catch {
            print("Failed to load applications:", error)
        }
    }
}
