import SwiftUI

struct SelectLoanTypeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedLoanType: LoanType = .personal
    @State private var navigateToApplication = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea(edges: .bottom)

            VStack(alignment: .leading, spacing: 18) {
                progressBar
                loanTypeList
                nextButton
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 92)
            .padding(.top, -6)
        }
        .navigationBarBackButtonHidden(true)
        .navigationTitle("Select Loan Type")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.white, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.accentGreen)
                }
                .buttonStyle(.plain)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationDestination(isPresented: $navigateToApplication) {
            LoanApplicationFlowView(initialLoanType: selectedLoanType)
        }
    }

    private var progressBar: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(index == 0 ? Color.accentGreen : Color.gray.opacity(0.16))
                    .frame(height: 5)
            }
        }
    }

    private var loanTypeList: some View {
        VStack(spacing: 12) {
            ForEach(LoanTypeSelectionOption.allCases) { option in
                Button {
                    selectedLoanType = option.type
                } label: {
                    loanTypeRow(for: option)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func loanTypeRow(for option: LoanTypeSelectionOption) -> some View {
        let isSelected = option.type == selectedLoanType

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#F6F8F4"))
                Image(systemName: option.type.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.accentGreen)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(option.title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                Text(option.subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(isSelected ? .accentGreen : .textSecondary.opacity(0.55))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(isSelected ? Color.accentGreenBg.opacity(0.35) : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? Color.accentGreen.opacity(0.45) : Color.black.opacity(0.04), lineWidth: 1)
        )
    }

    private var nextButton: some View {
        Button {
            navigateToApplication = true
        } label: {
            HStack {
                Spacer()
                Text("Next")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Spacer()
            }
            .foregroundColor(.white)
            .padding(.vertical, 16)
            .background(Color.accentDark)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct LoanTypeSelectionOption: Identifiable, CaseIterable {
    let type: LoanType

    var id: String { type.rawValue }

    var title: String { type.displayName }

    var subtitle: String {
        switch type {
        case .personal:
            return "Quick cash for immediate needs. Flexible terms & low interest."
        case .business:
            return "Grow your enterprise. Working capital & expansion funds."
        case .home:
            return "Buy your dream home. Competitive rates & long tenure."
        case .education:
            return "Invest in your future. Covers tuition & expenses."
        default:
            return "Explore available options and continue."
        }
    }

    static var allCases: [LoanTypeSelectionOption] {
        [.personal, .business, .home, .education].map { LoanTypeSelectionOption(type: $0) }
    }
}
