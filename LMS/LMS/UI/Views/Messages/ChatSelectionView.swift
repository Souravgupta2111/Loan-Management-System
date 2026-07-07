import SwiftUI
import Auth
import Combine
import Supabase
import PostgREST

struct ChatSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = ChatSelectionViewModel()
    
    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                VStack(spacing: Spacing.md) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .themeGreen))
                        .scaleEffect(1.5)
                    Text("Loading Chats...")
                        .font(.bodyRegular)
                        .foregroundColor(.themeGreen)
                }
                .frame(maxWidth: .infinity)
                .padding(Spacing.xxl)
                .liquidGlass(tint: .themeGreen, tintOpacity: 0.1)
                .padding(Spacing.lg)
            } else if viewModel.loans.isEmpty {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "bubble.left.and.exclamationmark.bubble.right")
                        .font(.title)
                        .foregroundColor(.textSecondary)
                    Text("No loans available for chat")
                        .font(.bodyRegular)
                        .foregroundColor(.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(Spacing.xxl)
                .liquidGlass()
                .padding(Spacing.lg)
            } else {
                LazyVStack(spacing: Spacing.md) {
                    ForEach(viewModel.loans) { loan in
                        NavigationLink {
                            if let officerId = loan.officerUserId, let appId = loan.applicationId {
                                MessageView(applicationId: appId, receiverId: officerId, officerName: loan.officerName)
                            } else {
                                Text("Chat not available for this loan. Officer may not be assigned.")
                            }
                        } label: {
                            ChatLoanCard(loan: loan)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Spacing.md)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar { ToolbarItem(placement: .topBarLeading) { GlassBackButton { dismiss() } } }
        .navigationTitle("Your Chats")
        .navigationBarTitleDisplayMode(.inline)
        .background(
            LinearGradient(
                colors: [Color(hex: "#E7EFE5"), Color(hex: "#EFF4EA"), Color(hex: "#E7EFE5")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .task {
            if let userId = authViewModel.currentUser?.id {
                await viewModel.fetchLoans(userId: userId)
            }
        }
    }
}

struct ChatLoanCard: View {
    let loan: ChatLoanItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(loan.name)
                    .font(.body.weight(.bold))
                    .foregroundColor(.textPrimary)
                Text(loan.loanNumber)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
            
            if loan.officerUserId != nil {
                Image(systemName: "chevron.right")
                    .foregroundColor(.textSecondary)
            } else {
                Text("Pending Assignment")
                    .font(.caption)
                    .foregroundColor(Color(hex: "#F5A623")) // Orange color manually
            }
        }
        .padding(Spacing.md)
        .liquidGlass(cornerRadius: 18)
    }
}

struct ChatLoanItem: Identifiable {
    let id: UUID
    let applicationId: UUID?
    let name: String
    let loanNumber: String
    let officerUserId: UUID?
    let officerName: String?
}

@MainActor
class ChatSelectionViewModel: ObservableObject {
    @Published var loans: [ChatLoanItem] = []
    @Published var isLoading = true
    
    func fetchLoans(userId: UUID) async {
        isLoading = true
        do {
            let detailedLoans = try await LoanService.shared.fetchDetailedUserLoans(userId: userId)
            
            var fetched: [ChatLoanItem] = []
            for loan in detailedLoans {
                var officerUserId: UUID? = nil
                var officerName: String? = nil
                if let appId = loan.applicationId {
                    if let info = try? await BranchAssignmentService.shared.fetchAssignedOfficerInfo(applicationId: appId) {
                        officerUserId = info.officerUserId
                        officerName = info.officerName
                    }
                }
                
                fetched.append(ChatLoanItem(
                    id: loan.id,
                    applicationId: loan.applicationId,
                    name: loan.name,
                    loanNumber: loan.loanNumber.isEmpty ? "Application" : loan.loanNumber,
                    officerUserId: officerUserId,
                    officerName: officerName
                ))
            }
            // Fetch latest messages to sort
            let appIds = fetched.compactMap { $0.applicationId }
            if !appIds.isEmpty {
                struct MessageTimestamp: Decodable {
                    let application_id: UUID
                    let sent_at: String
                }
                
                if let timestamps: [MessageTimestamp] = try? await SupabaseManager.shared.client
                    .from("messages")
                    .select("application_id, sent_at")
                    .in("application_id", values: appIds.map { $0.uuidString })
                    .execute()
                    .value {
                    
                    var latestTimes: [UUID: Date] = [:]
                    let isoFormatter = ISO8601DateFormatter()
                    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    let fallbackFormatter = ISO8601DateFormatter()
                    
                    for ts in timestamps {
                        if let date = isoFormatter.date(from: ts.sent_at) ?? fallbackFormatter.date(from: ts.sent_at) {
                            if let current = latestTimes[ts.application_id] {
                                if date > current { latestTimes[ts.application_id] = date }
                            } else {
                                latestTimes[ts.application_id] = date
                            }
                        }
                    }
                    
                    fetched.sort {
                        let date0 = $0.applicationId.flatMap { latestTimes[$0] } ?? .distantPast
                        let date1 = $1.applicationId.flatMap { latestTimes[$0] } ?? .distantPast
                        return date0 > date1
                    }
                }
            }
            
            self.loans = fetched
        } catch {
            print("Error fetching loans for chat: \(error)")
        }
        isLoading = false
    }
}
