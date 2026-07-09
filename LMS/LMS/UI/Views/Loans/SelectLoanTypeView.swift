import SwiftUI

/// Select Loan Type Screen (design.md §8.6 Step 1)
/// Cards show only the loan type name + icon — all financial details are
/// surfaced on the product detail screen and fetched live from the backend.
struct SelectLoanTypeView: View {
    @Environment(\.dismiss) private var dismiss
    var isTabRoot: Bool = false
    @Binding var path: NavigationPath

    @State private var selectedLoanType: LoanType? = nil
    @State private var navigateToApplication = false

    init(isTabRoot: Bool = false, path: Binding<NavigationPath> = .constant(NavigationPath())) {
        self.isTabRoot = isTabRoot
        self._path = path
    }

    /// Distinct loan types that have at least one active product in the DB.
    @State private var availableTypes: [LoanType] = []
    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Choose Loan Type")
                            .font(.title3.weight(.bold)).fontDesign(.rounded)
                            .foregroundColor(.textPrimary)
                        Text("Explore loan options and start your application in just a few taps.")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.textSecondary)
                    }

                    if isLoading {
                        loadingGrid
                    } else if let error = loadError {
                        errorView(message: error)
                    } else {
                        loanTypeGrid
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }



            Button {
                path.append(LoanNavigation.applicationFlow(selectedLoanType))
            } label: {
                HStack(spacing: 8) {
                    Text("NEXT")
                        .font(.body.weight(.bold))
                        .tracking(1.5)
                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(isLoading || availableTypes.isEmpty || selectedLoanType == nil
                    ? Color(hex: "#1A1A1A").opacity(0.4)
                    : Color(hex: "#1A1A1A"))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isLoading || availableTypes.isEmpty || selectedLoanType == nil)
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 18)

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
        .navigationTitle(isTabRoot ? "Apply" : "Select Loan Type")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if !isTabRoot {
                ToolbarItem(placement: .topBarLeading) {
                    GlassBackButton { dismiss() }
                }
            }
        }
        .task { await loadLoanTypes() }
        .refreshable { await loadLoanTypes() }
    }

    // MARK: - Data Fetch

    /// Fetches all active products and collects the distinct loan types present.
    /// No financial data is derived or displayed here — that lives on the detail screen.
    @MainActor
    private func loadLoanTypes() async {
        isLoading = true
        loadError = nil
        do {
            let products = try await LoanService.shared.fetchActiveProducts()
            let order: [LoanType] = [.home, .vehicle, .personal, .business,
                                     .education, .gold, .agriculture, .other]
            var seen = Set<LoanType>()
            availableTypes = products
                .map(\.type)
                .filter { seen.insert($0).inserted }
                .sorted { (order.firstIndex(of: $0) ?? 99) < (order.firstIndex(of: $1) ?? 99) }

            if let selected = selectedLoanType, !availableTypes.contains(selected) {
                selectedLoanType = nil
            }
        } catch {
            loadError = "Couldn't load loan types. Pull to refresh."
        }
        isLoading = false
    }

    // MARK: - Grid (name + icon only)

    private var loanTypeGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(availableTypes, id: \.rawValue) { loanType in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        if selectedLoanType == loanType {
                            selectedLoanType = nil
                        } else {
                            selectedLoanType = loanType
                        }
                    }
                } label: {
                    loanTypeCard(for: loanType)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Skeleton loading grid

    private var loadingGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.surfaceMuted)
                    .frame(height: 100)
                    .shimmering()
            }
        }
    }

    // MARK: - Error view

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundColor(.textSecondary)
            Text(message)
                .font(.body)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
            Button("Retry") { Task { await loadLoanTypes() } }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Color.accentGreen)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Card (name + icon only — no financial info)

    private func loanTypeCard(for loanType: LoanType) -> some View {
        let isSelected = loanType == selectedLoanType
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentGreen.opacity(0.20) : Color.surfaceMuted)
                    Image(systemName: loanType.icon)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(isSelected ? Color.accentGreen : .textSecondary)
                }
                .frame(width: 44, height: 44)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color.accentGreen)
                        .font(.title3)
                }
            }
            Text(loanType.displayName)
                .font(.headline.weight(.bold)).fontDesign(.rounded)
                .foregroundColor(.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(
            cornerRadius: 18,
            borderColor: isSelected ? Color.accentGreen : Color.border,
            borderOpacity: isSelected ? 1.0 : 0.5,
            shadowOpacity: isSelected ? 0.1 : 0.03,
            shadowRadius: 8
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
    }
}

// MARK: - Shimmer

private extension View {
    func shimmering() -> some View { self.overlay(ShimmerView()).clipped() }
}

private struct ShimmerView: View {
    @State private var phase: CGFloat = -1
    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white.opacity(0.4), location: 0.4),
                    .init(color: .white.opacity(0.4), location: 0.6),
                    .init(color: .clear, location: 1)
                ]),
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: geo.size.width * 3)
            .offset(x: geo.size.width * phase)
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { phase = 1 }
            }
        }
    }
}
