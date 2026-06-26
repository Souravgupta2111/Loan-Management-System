import SwiftUI

/// Select Loan Product / Type Screen (design.md §8.6 Step 1)
/// NEXT button is in a VStack below the ScrollView — no ZStack overlay needed
/// because MainTabView now uses VStack layout (tab bar sits below, not over).
struct SelectLoanTypeView: View {
    @Environment(\.dismiss) private var dismiss
    var isTabRoot: Bool = false

    @State private var selectedLoanType: LoanType = .personal
    @State private var navigateToApplication = false

    var body: some View {
        VStack(spacing: 0) {
            // Scrollable content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    progressBar

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Choose Loan Type")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                        Text("Select the product that fits your financial needs")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.textSecondary)
                    }

                    loanTypeGrid
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }

            // NEXT button — in the VStack below scroll, above the tab bar
            Divider().opacity(0.4)

            Button {
                navigateToApplication = true
            } label: {
                HStack(spacing: 8) {
                    Text("NEXT")
                        .font(.system(size: 16, weight: .bold))
                        .tracking(1.5)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color(hex: "#1A1A1A"))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 18)
            .background(Color.appBackground)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .navigationTitle(isTabRoot ? "Apply" : "Select Loan Type")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.white, for: .navigationBar)
        .toolbar {
            if !isTabRoot {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.accentGreen)
                    }
                    .buttonStyle(.plain)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Text("Cancel")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationDestination(isPresented: $navigateToApplication) {
            LoanApplicationFlowView(initialLoanType: selectedLoanType)
        }
    }

    // MARK: - Progress bar

    private var progressBar: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(index == 0 ? Color(hex: "#2D8B4E") : Color(hex: "#89DBA6").opacity(0.25))
                    .frame(height: 5)
            }
        }
    }

    // MARK: - Grid

    private var loanTypeGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ]
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(LoanTypeGridOption.options) { option in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        selectedLoanType = option.type
                    }
                } label: {
                    loanTypeCard(for: option)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func loanTypeCard(for option: LoanTypeGridOption) -> some View {
        let isSelected = option.type == selectedLoanType
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color(hex: "#89DBA6").opacity(0.20) : Color.surfaceMuted)
                    Image(systemName: option.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isSelected ? Color(hex: "#2D8B4E") : .textSecondary)
                }
                .frame(width: 40, height: 40)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "#2D8B4E"))
                        .font(.title3)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(option.title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                Text(option.rateRange)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#2D8B4E"))
                Text(option.rateType)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.textSecondary)
                Text(option.amountRange)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color(hex: "#89DBA6").opacity(0.07) : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? Color(hex: "#89DBA6") : Color.border, lineWidth: isSelected ? 2 : 1)
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .shadow(color: isSelected ? Color(hex: "#89DBA6").opacity(0.20) : .black.opacity(0.03),
                radius: 8, x: 0, y: 3)
    }
}

// MARK: - Data

private struct LoanTypeGridOption: Identifiable {
    let type: LoanType
    let rateRange: String
    let rateType: String
    let amountRange: String

    var id: String { type.rawValue }
    var title: String { type.displayName }
    var icon: String { type.icon }

    static let options: [LoanTypeGridOption] = [
        LoanTypeGridOption(type: .home,     rateRange: "8.5% - 12.5%", rateType: "Fixed/Floating", amountRange: "₹5L - ₹2Cr"),
        LoanTypeGridOption(type: .vehicle,  rateRange: "9.2% - 14.0%", rateType: "Fixed/Reducing", amountRange: "₹1L - ₹50L"),
        LoanTypeGridOption(type: .personal, rateRange: "From 11.5%",   rateType: "Fixed",           amountRange: "₹50K - ₹20L"),
        LoanTypeGridOption(type: .business, rateRange: "From 10.0%",   rateType: "Fixed/Reducing",  amountRange: "₹2L - ₹1Cr")
    ]
}
