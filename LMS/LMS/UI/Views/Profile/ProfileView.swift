import SwiftUI
import Supabase

/// Profile View (design.md §8.9)
/// Avatar, name, email, KYC status, personal details, sign out.
struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var userName = ""
    @State private var userEmail = ""
    @State private var kycStatus = "pending"
    @State private var phone = ""
    @State private var pan = ""
    @State private var creditScore: Int?
    @State private var creditBureau: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xxl) {
                    // MARK: - Avatar Card
                    VStack(spacing: Spacing.md) {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.accentMint, Color.accentGreenBg],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            Text(initials)
                                .font(.sectionTitle)
                                .foregroundColor(.accentGreen)
                        }

                        Text(userName.isEmpty ? "User" : userName)
                            .font(.cardTitle)
                            .foregroundColor(.textPrimary)

                        Text(userEmail)
                            .font(.bodyRegular)
                            .foregroundColor(.textSecondary)

                        StatusBadge(status: kycStatus == "verified" ? "verified" : "pending")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(Spacing.xxl)
                    .background(Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Corner.xl))
                    .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)

                    // MARK: - Personal Details
                    profileSection("Personal Details") {
                        profileRow("Phone", value: phone.isEmpty ? "Not set" : phone)
                        profileRow("PAN", value: pan.isEmpty ? "Not set" : pan)
                        profileRow("KYC Status", value: kycStatus.capitalized)
                    }
                    
                    // MARK: - Credit Score
                    if let score = creditScore, let bureau = creditBureau {
                        CreditScoreView(score: score, bureau: bureau)
                            .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
                    }

                    // MARK: - Actions
                    VStack(spacing: Spacing.md) {
                        actionRow(icon: "bell", title: "Notifications", color: .textPrimary)
                        actionRow(icon: "questionmark.circle", title: "Help & Support", color: .textPrimary)
                    }
                    .padding(Spacing.lg)
                    .background(Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Corner.xl))
                    .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)

                    // MARK: - Sign Out
                    PillButton(title: "Sign Out", style: .destructive, icon: "rectangle.portrait.and.arrow.right") {
                        Task {
                            await authViewModel.signOut()
                            dismiss()
                        }
                    }
                    .padding(.top, Spacing.lg)
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, 60)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.textPrimary)
                    }
                }
            }
            .task { await loadProfile() }
        }
    }

    // MARK: - Components
    private func profileSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(title)
                .font(.bodyLarge)
                .foregroundColor(.textPrimary)
            content()
        }
        .padding(Spacing.lg)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Corner.xl))
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
    }

    private func profileRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.bodyRegular)
                .foregroundColor(.textSecondary)
            Spacer()
            Text(value)
                .font(.bodyLarge)
                .foregroundColor(.textPrimary)
        }
    }

    private func actionRow(icon: String, title: String, color: Color) -> some View {
        Button {
            // Action
        } label: {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.bodyRegular)
                    .foregroundColor(color)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.textTertiary)
            }
        }
    }

    private var initials: String {
        let parts = userName.components(separatedBy: " ")
        let first = parts.first?.prefix(1) ?? "U"
        let last = parts.count > 1 ? String(parts.last!.prefix(1)) : ""
        return "\(first)\(last)".uppercased()
    }

    // MARK: - Data Loading
    private func loadProfile() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        userEmail = authViewModel.currentUser?.email ?? ""

        do {
            let users: [ProfileRow] = try await SupabaseManager.shared.client
                .from("users")
                .select("full_name, phone")
                .eq("id", value: userId.uuidString)
                .execute()
                .value
            if let row = users.first {
                userName = row.fullName
                phone = row.phone ?? ""
            }

            let profiles: [BorrowerRow] = try await SupabaseManager.shared.client
                .from("borrower_profiles")
                .select("kyc_status, pan_number, credit_score, credit_bureau")
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value
            if let profile = profiles.first {
                kycStatus = profile.kycStatus
                pan = profile.panNumber ?? ""
                creditScore = profile.creditScore
                creditBureau = profile.creditBureau?.uppercased() ?? "CIBIL"
            }
        } catch {
            print("Profile load error: \(error)")
        }
    }
}

// MARK: - Decodable Models
private struct ProfileRow: Decodable {
    let fullName: String
    let phone: String?
    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case phone
    }
}

private struct BorrowerRow: Decodable {
    let kycStatus: String
    let panNumber: String?
    let creditScore: Int?
    let creditBureau: String?
    enum CodingKeys: String, CodingKey {
        case kycStatus = "kyc_status"
        case panNumber = "pan_number"
        case creditScore = "credit_score"
        case creditBureau = "credit_bureau"
    }
}
