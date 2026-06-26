import SwiftUI
import Combine

/// Loan Detail View
/// Premium, scrollable loan detail screen for the My Loans flow.
struct LoanDetailView: View {
    let loan: LoanListItem
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: LoanDetailViewModel

    init(loan: LoanListItem) {
        self.loan = loan
        _viewModel = StateObject(wrappedValue: LoanDetailViewModel(loan: loan))
    }

    var body: some View {
        ZStack {
            Color.gradientMintStart
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.xxl + 2) {
                    navigationHeader
                        .padding(.top, Spacing.lg)

                    LoanSummaryCard(
                        detail: viewModel.detail,
                        progress: viewModel.animatedProgress,
                        formatCurrency: viewModel.formatCurrency
                    )

                    CustomLoanSegmentedControl(selection: $viewModel.selectedTab)
                        .padding(.top, Spacing.sm)

                    tabContent
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                .padding(.horizontal, Spacing.xxl)
                .padding(.bottom, Spacing.xxxl + Spacing.sm)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.animateProgress() }
    }

    private var navigationHeader: some View {
        ZStack {
            Text(viewModel.detail.loanName)
                .font(.system(size: 30, weight: .bold, design: .default))
                .foregroundColor(.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .padding(.horizontal, 72)

            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        dismiss()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .frame(width: 58, height: 58)
                        .background(Color.surface.opacity(0.86))
                        .clipShape(Circle())
                }
                .buttonStyle(ScaleButtonStyle())

                Spacer()
            }
        }
        .frame(height: 58)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.selectedTab {
        case .timeline:
            TimelineCard(items: viewModel.detail.timeline)
        case .documents:
            DocumentsList(documents: viewModel.detail.documents)
        case .schedule:
            ScheduleList(schedule: viewModel.detail.schedule, formatCurrency: viewModel.formatCurrency)
        }
    }
}

// MARK: - View Model

private final class LoanDetailViewModel: ObservableObject {
    @Published var selectedTab: LoanDetailTab = .timeline
    @Published var animatedProgress = 0.0

    let detail: LoanDetailMock

    init(loan: LoanListItem) {
        self.detail = LoanDetailMock.make(from: loan)
    }

    func animateProgress() {
        animatedProgress = 0
        withAnimation(.spring(response: 0.7, dampingFraction: 0.88).delay(0.12)) {
            animatedProgress = detail.repaymentProgress
        }
    }

    func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return "₹" + (formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))")
    }
}

// MARK: - Summary

private struct LoanSummaryCard: View {
    let detail: LoanDetailMock
    let progress: Double
    let formatCurrency: (Double) -> String

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Loan ID")
                    .font(.cardTitle)
                    .foregroundColor(.textPrimary)

                Spacer()

                Text(detail.loanNumber)
                    .font(.system(size: 23, weight: .regular))
                    .foregroundColor(.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(.bottom, Spacing.xl)

            Divider()
                .background(Color.border)

            HStack(alignment: .top) {
                LoanAmountColumn(
                    title: "Sanctioned",
                    amount: detail.sanctionedAmount,
                    subtitle: nil,
                    alignment: .leading,
                    formatCurrency: formatCurrency
                )

                Spacer(minLength: Spacing.lg)

                LoanAmountColumn(
                    title: "Monthly EMI",
                    amount: detail.monthlyEMI,
                    subtitle: detail.emiDueText,
                    alignment: .trailing,
                    formatCurrency: formatCurrency
                )
            }
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.xxl)

            HStack(alignment: .top, spacing: Spacing.sm) {
                LoanInfoColumn(title: "Tenure", value: detail.tenureText)
                LoanInfoColumn(title: "Remaining Tenure", value: detail.remainingTenureText)
                LoanInfoColumn(title: "Interest Rate", value: detail.interestRateText)
            }
            .padding(.bottom, Spacing.xxl)

            Divider()
                .background(Color.border)

            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Repayment Progress")
                    .font(.cardTitle)
                    .foregroundColor(.textSecondary)

                HStack(alignment: .firstTextBaseline) {
                    Text(detail.remainingEMIText)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.textPrimary)

                    Spacer()

                    Text(detail.progressText)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.accentGreen)
                }

                LoanProgressBar(progress: progress, color: .accentGreen)
                    .frame(height: 17)
                    .padding(.horizontal, Spacing.xs)
            }
            .padding(.top, Spacing.xxl)
        }
        .padding(.horizontal, Spacing.xxl)
        .padding(.vertical, Spacing.xxxl)
        .background(Color.surface.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 10, x: 0, y: 7)
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.8), lineWidth: 1)
        )
    }
}

private struct LoanAmountColumn: View {
    let title: String
    let amount: Double
    let subtitle: String?
    let alignment: HorizontalAlignment
    let formatCurrency: (Double) -> String

    var body: some View {
        VStack(alignment: alignment, spacing: Spacing.sm) {
            Text(title)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.textSecondary)

            Text(formatCurrency(amount))
                .font(.system(size: 30, weight: .bold, design: .default))
                .foregroundColor(.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            if let subtitle {
                Text(subtitle)
                    .font(.bodyRegular)
                    .foregroundColor(.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
            }
        }
    }
}

private struct LoanInfoColumn: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.accentGreen)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(value)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Segmented Control

private struct CustomLoanSegmentedControl: View {
    @Binding var selection: LoanDetailTab
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(LoanDetailTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                        selection = tab
                    }
                } label: {
                    Text(tab.title)
                        .font(.system(size: 19, weight: .medium))
                        .foregroundColor(.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm + 2)
                        .background {
                            if selection == tab {
                                Capsule()
                                    .fill(Color.surface.opacity(0.98))
                                    .matchedGeometryEffect(id: "selectedLoanDetailTab", in: namespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.black.opacity(0.07))
        .clipShape(Capsule())
    }
}

// MARK: - Timeline

private struct TimelineCard: View {
    let items: [LoanTimelineItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                TimelineItemView(item: item, isLast: index == items.count - 1)
            }
        }
        .padding(.horizontal, Spacing.xxxl + 4)
        .padding(.vertical, Spacing.xxxl - 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surface.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 10, x: 0, y: 7)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.8), lineWidth: 1)
        )
    }
}

private struct TimelineItemView: View {
    let item: LoanTimelineItem
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.xxxl + 2) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Color.accentGreen)
                        .frame(width: 34, height: 34)

                    Image(systemName: "checkmark")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundColor(.white)
                }

                if !isLast {
                    Rectangle()
                        .fill(Color.accentGreen.opacity(0.62))
                        .frame(width: 3, height: 54)
                }
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(item.title)
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundColor(.textPrimary)

                Text(item.date)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.textTertiary)
            }
            .padding(.top, Spacing.xs)

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Documents

private struct DocumentsList: View {
    let documents: [LoanDocumentItem]

    var body: some View {
        VStack(spacing: Spacing.md) {
            ForEach(documents) { document in
                LoanDocumentRowView(document: document)
            }
        }
        .padding(Spacing.lg + 2)
        .background(Color.surface.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 10, x: 0, y: 7)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.8), lineWidth: 1)
        )
    }
}

private struct LoanDocumentRowView: View {
    let document: LoanDocumentItem

    var body: some View {
        HStack(spacing: Spacing.md + 2) {
            Image(systemName: document.icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(.accentGreen)
                .frame(width: 40, height: 40)
                .background(Color.accentGreenBg)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(document.title)
                    .font(.bodyLarge)
                    .foregroundColor(.textPrimary)
                Text(document.uploadDate)
                    .font(.caption2)
                    .foregroundColor(.textTertiary)
            }

            Spacer()

            Button { } label: {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.accentGreen)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(Spacing.lg)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Corner.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Corner.lg, style: .continuous)
                .stroke(Color.border, lineWidth: 0.6)
        )
    }
}

// MARK: - Schedule

private struct ScheduleList: View {
    let schedule: [LoanEMIItem]
    let formatCurrency: (Double) -> String

    var body: some View {
        VStack(spacing: Spacing.md) {
            ForEach(schedule) { emi in
                EMIScheduleRowView(emi: emi, formatCurrency: formatCurrency)
            }
        }
        .padding(Spacing.lg + 2)
        .background(Color.surface.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 10, x: 0, y: 7)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.8), lineWidth: 1)
        )
    }
}

private struct EMIScheduleRowView: View {
    let emi: LoanEMIItem
    let formatCurrency: (Double) -> String

    var body: some View {
        HStack(spacing: Spacing.md + 2) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Due Date")
                    .font(.caption2)
                    .foregroundColor(.textTertiary)
                Text(emi.dueDate)
                    .font(.bodyLarge)
                    .foregroundColor(.textPrimary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: Spacing.xs) {
                Text("EMI Amount")
                    .font(.caption2)
                    .foregroundColor(.textTertiary)
                Text(formatCurrency(emi.amount))
                    .font(.bodyLarge)
                    .foregroundColor(.textPrimary)
            }

            StatusBadge(status: emi.status.rawValue)
        }
        .padding(Spacing.lg)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Corner.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Corner.lg, style: .continuous)
                .stroke(Color.border, lineWidth: 0.6)
        )
    }
}

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Mock Models

private enum LoanDetailTab: String, CaseIterable, Identifiable {
    case timeline
    case documents
    case schedule

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timeline: return "Timeline"
        case .documents: return "Documents"
        case .schedule: return "Schedule"
        }
    }
}

private struct LoanDetailMock {
    let loanName: String
    let loanNumber: String
    let sanctionedAmount: Double
    let monthlyEMI: Double
    let emiDueText: String
    let tenureText: String
    let remainingTenureText: String
    let interestRateText: String
    let remainingEMIText: String
    let repaymentProgress: Double
    let progressText: String
    let timeline: [LoanTimelineItem]
    let documents: [LoanDocumentItem]
    let schedule: [LoanEMIItem]

    static func make(from loan: LoanListItem) -> LoanDetailMock {
        let sanctionedAmount = loan.amount > 0 ? loan.amount : 800_000
        let emiAmount = loan.emiAmount > 0 ? loan.emiAmount : 20_000
        let interestRate = loan.interestRate > 0 ? loan.interestRate : 7.85

        return LoanDetailMock(
            loanName: loan.name.isEmpty ? "Premium Home Loan" : loan.name,
            loanNumber: loan.loanNumber.isEmpty ? "HL-2026-00895672" : loan.loanNumber,
            sanctionedAmount: sanctionedAmount,
            monthlyEMI: emiAmount,
            emiDueText: "15th of every month",
            tenureText: "12 months",
            remainingTenureText: "11 months",
            interestRateText: String(format: "%.2f%% p.a.", interestRate),
            remainingEMIText: "11 EMIs left",
            repaymentProgress: 0.10,
            progressText: "10% repaid",
            timeline: [
                LoanTimelineItem(title: "Applied", date: "5 July 2026"),
                LoanTimelineItem(title: "Approved", date: "12 July 2026"),
                LoanTimelineItem(title: "Disbursed", date: "18 July 2026")
            ],
            documents: [
                LoanDocumentItem(title: "Loan Agreement", uploadDate: "Uploaded 18 July 2026", icon: "doc.text.fill"),
                LoanDocumentItem(title: "Sanction Letter", uploadDate: "Uploaded 12 July 2026", icon: "doc.richtext.fill"),
                LoanDocumentItem(title: "Repayment Schedule", uploadDate: "Uploaded 18 July 2026", icon: "calendar.badge.clock")
            ],
            schedule: [
                LoanEMIItem(dueDate: "15 Aug 2026", amount: emiAmount, status: .paid),
                LoanEMIItem(dueDate: "15 Sep 2026", amount: emiAmount, status: .upcoming),
                LoanEMIItem(dueDate: "15 Oct 2026", amount: emiAmount, status: .upcoming),
                LoanEMIItem(dueDate: "15 Nov 2026", amount: emiAmount, status: .overdue)
            ]
        )
    }
}

private struct LoanTimelineItem: Identifiable {
    let id = UUID()
    let title: String
    let date: String
}

private struct LoanDocumentItem: Identifiable {
    let id = UUID()
    let title: String
    let uploadDate: String
    let icon: String
}

private struct LoanEMIItem: Identifiable {
    let id = UUID()
    let dueDate: String
    let amount: Double
    let status: LoanEMIStatus
}

private enum LoanEMIStatus: String {
    case paid = "Paid"
    case upcoming = "Upcoming"
    case overdue = "Overdue"
}
