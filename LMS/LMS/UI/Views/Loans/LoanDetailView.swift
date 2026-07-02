import SwiftUI
import Combine
import PhotosUI
import Supabase
import Auth

/// Loan Detail View
/// Compact, glass-themed loan detail screen matching Schedule tab aesthetic.
struct LoanDetailView: View {
    let loan: LoanListItem
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel: LoanDetailViewModel

    init(loan: LoanListItem) {
        self.loan = loan
        _viewModel = StateObject(wrappedValue: LoanDetailViewModel(loan: loan))
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#E7EFE5"), Color(hex: "#EFF4EA"), Color(hex: "#E7EFE5")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    navigationHeader
                        .padding(.top, 8)

                    LoanSummaryCard(
                        detail: viewModel.detail,
                        progress: viewModel.animatedProgress,
                        formatCurrency: viewModel.formatCurrency
                    )

                    CustomLoanSegmentedControl(selection: $viewModel.selectedTab, loanStatus: loan.status)

                    tabContent
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
            
            // Chat FAB
            if let officerInfo = viewModel.assignedOfficer, let appId = viewModel.detail.applicationId, let currentUserId = authViewModel.currentUser?.id {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        NavigationLink {
                            MessageView(applicationId: appId, receiverId: officerInfo.officerUserId)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                                Text("Message Officer")
                            }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(Color(hex: "#2D8B4E"))
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.animateProgress() }
        .task { await viewModel.loadOfficerInfo() }
        .sheet(item: $viewModel.previewURLItem) { item in
            DocumentPreview(url: item.url)
        }
    }

    private var navigationHeader: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    dismiss()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "#2D8B4E"))
                    .frame(width: 36, height: 36)
                    .background(Color(hex: "#E8F5EC"))
                    .clipShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle())

            Text(viewModel.detail.loanName)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#1A1A1A"))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer()
        }
        .frame(height: 36)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.selectedTab {
        case .timeline:
            TimelineCard(loan: loan)
        case .documents:
            DocumentsList(loan: loan, documents: viewModel.detail.documents, borrowerName: "Borrower") { data, title in
                guard let userId = authViewModel.currentUser?.id, let appId = loan.applicationId else { return }
                
                viewModel.addUploadedDocument(title: title)
                
                Task {
                    try? await LoanService.shared.uploadAdditionalDocument(applicationId: appId, userId: userId, data: data, title: title)
                    NotificationCenter.default.post(name: .loanDataDidChange, object: nil)
                }
            } onPreview: { url in
                viewModel.previewURLItem = PreviewItem(url: url)
            }
        case .schedule:
            if ["active", "npa", "restructured"].contains(loan.status.lowercased()) {
                ScheduleList(schedule: viewModel.detail.schedule, formatCurrency: viewModel.formatCurrency)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 32))
                        .foregroundColor(Color(hex: "#C8E6D0"))
                    Text("Schedule Not Generated")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#1A1A1A"))
                    Text("EMI schedule will be available once your application is approved and disbursed.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color(hex: "#6B6B6B"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.vertical, 40)
            }
        }
    }
}

// MARK: - View Model

struct PreviewItem: Identifiable {
    let id = UUID()
    let url: URL
}

private final class LoanDetailViewModel: ObservableObject {
    @Published var selectedTab: LoanDetailTab = .timeline
    @Published var animatedProgress = 0.0
    @Published var previewURLItem: PreviewItem?
    @Published var assignedOfficer: AssignedOfficerInfo?

    @Published var detail: LoanDetailMock

    init(loan: LoanListItem) {
        self.detail = LoanDetailMock.make(from: loan)
    }

    func animateProgress() {
        animatedProgress = 0
        withAnimation(.spring(response: 0.7, dampingFraction: 0.88).delay(0.12)) {
            animatedProgress = detail.repaymentProgress
        }
    }
    
    func addUploadedDocument(title: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "d MMM yyyy"
        let dateStr = "Uploaded \(dateFormatter.string(from: Date()))"
        
        let newDoc = LoanDocumentItem(
            title: title.capitalized,
            uploadDate: dateStr,
            icon: "doc.text.fill",
            storagePath: nil
        )
        
        detail.documents.append(newDoc)
    }
    
    @MainActor
    func loadOfficerInfo() async {
        guard let appId = detail.applicationId else { return }
        do {
            assignedOfficer = try await BranchAssignmentService.shared.fetchAssignedOfficerInfo(applicationId: appId)
        } catch {
            print("Failed to load officer info: \(error)")
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
            // Loan ID row
            HStack(alignment: .firstTextBaseline) {
                Text("Loan ID")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#1A1A1A"))

                Spacer()

                Text(detail.loanNumber)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color(hex: "#9E9E9E"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(.bottom, 12)

            Divider()
                .background(Color.white.opacity(0.3))

            if ["active", "npa", "restructured"].contains(detail.loanStatus.lowercased()) {
                // Sanctioned / Monthly EMI
                HStack(alignment: .top) {
                    LoanAmountColumn(
                        title: "Outstanding",
                        amount: detail.remainingAmount,
                        subtitle: EmptyView(),
                        alignment: .leading,
                        formatCurrency: formatCurrency
                    )

                    Spacer(minLength: 12)

                    LoanAmountColumn(
                        title: "Monthly EMI",
                        amount: detail.monthlyEMI,
                        subtitle: detail.emiDueView,
                        alignment: .trailing,
                        formatCurrency: formatCurrency
                    )
                }
                .padding(.top, 12)
                .padding(.bottom, 18)

                // Tenure / Remaining / Interest
                HStack(alignment: .top) {
                    LoanInfoColumn(title: "Tenure", value: detail.tenureText, alignment: .leading)
                    Spacer()
                    LoanInfoColumn(title: "Remaining", value: detail.remainingTenureText, alignment: .center)
                    Spacer()
                    LoanInfoColumn(title: "Interest", value: detail.interestRateText, alignment: .trailing)
                }
                .padding(.bottom, 18)

                Divider()
                    .background(Color.white.opacity(0.3))

                // Repayment Progress
                VStack(alignment: .leading, spacing: 8) {
                    Text("Repayment Progress")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "#6B6B6B"))
                        .textCase(.uppercase)
                        .tracking(0.5)

                    HStack(alignment: .firstTextBaseline) {
                        Text(detail.remainingEMIText)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color(hex: "#1A1A1A"))

                        Spacer()

                        Text(detail.progressText)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#2D8B4E"))
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(hex: "#C8E6D0").opacity(0.5))
                                .frame(height: 6)
                            Capsule()
                                .fill(Color(hex: "#2D8B4E"))
                                .frame(width: geo.size.width * CGFloat(min(max(progress, 0), 1)), height: 6)
                                .animation(.spring(response: 0.6), value: progress)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(.top, 12)
            } else {
                // Pending Application Info
                HStack(alignment: .top) {
                    LoanAmountColumn(
                        title: "Requested Amount",
                        amount: detail.remainingAmount,
                        subtitle: EmptyView(),
                        alignment: .leading,
                        formatCurrency: formatCurrency
                    )
                    
                    Spacer(minLength: 12)
                    
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("Status")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "#6B6B6B"))
                        Text(detail.loanStatus.capitalized.replacingOccurrences(of: "_", with: " "))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "#2D8B4E"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 18)
                
                HStack(alignment: .top) {
                    LoanInfoColumn(title: "Requested Tenure", value: detail.tenureText, alignment: .leading)
                    Spacer()
                    LoanInfoColumn(title: "Est. Interest", value: detail.interestRateText, alignment: .trailing)
                }
                .padding(.bottom, 18)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .liquidGlass(cornerRadius: 22, tint: Color(hex: "#2D8B4E"), tintOpacity: 0.04)
    }
}

private struct LoanAmountColumn<Subtitle: View>: View {
    let title: String
    let amount: Double
    let subtitle: Subtitle?
    let alignment: HorizontalAlignment
    let formatCurrency: (Double) -> String

    init(title: String, amount: Double, subtitle: Subtitle? = nil, alignment: HorizontalAlignment, formatCurrency: @escaping (Double) -> String) {
        self.title = title
        self.amount = amount
        self.subtitle = subtitle
        self.alignment = alignment
        self.formatCurrency = formatCurrency
    }

    var body: some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "#6B6B6B"))

            Text(formatCurrency(amount))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#1A1A1A"))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            if let subtitle {
                subtitle
            }
        }
    }
}

private struct LoanInfoColumn: View {
    let title: String
    let value: String
    var alignment: HorizontalAlignment = .center

    var body: some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "#2D8B4E"))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "#1A1A1A"))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }
}

// MARK: - Segmented Control

private struct CustomLoanSegmentedControl: View {
    @Binding var selection: LoanDetailTab
    let loanStatus: String
    @Namespace private var namespace

    var visibleTabs: [LoanDetailTab] {
        if loanStatus.lowercased() == "active" {
            return LoanDetailTab.allCases
        } else {
            return [.timeline, .documents]
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(visibleTabs) { tab in
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                        selection = tab
                    }
                } label: {
                    Text(tab.title)
                        .font(.system(size: 14, weight: selection == tab ? .semibold : .medium))
                        .foregroundColor(selection == tab ? Color(hex: "#2D8B4E") : Color(hex: "#6B6B6B"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            if selection == tab {
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .matchedGeometryEffect(id: "selectedLoanDetailTab", in: namespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .liquidGlass(cornerRadius: 999)
    }
}

// MARK: - Timeline

private struct TimelineCard: View {
    let loan: LoanListItem
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var animatedProgress: Double = 0.0
    
    // Upload states
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var isUploading = false
    @State private var uploadError: String? = nil
    @State private var uploadSuccess: String? = nil
    
    // Action States
    @State private var isAccepting = false
    @State private var isRejecting = false
    @State private var actionError: String? = nil
    
    struct StandardStep: Identifiable {
        let id = UUID()
        let title: String
        let date: String
        let remarks: String?
        let status: StepStatus
    }
    
    enum StepStatus {
        case completed
        case active
        case pending
    }
    
    var targetProgress: Double {
        switch loan.status.lowercased() {
        case "draft": return 0.0
        case "submitted": return 1.0
        case "under_review": return 1.0
        case "sent_back": return 1.0
        case "approved": return 2.0
        case "pending_acceptance": return 2.5
        case "disbursed", "active", "closed", "overdue": return 3.0
        default: return 0.0
        }
    }
    
    private func getEventDate(for keywords: [String]) -> String? {
        guard let timeline = loan.timeline else { return nil }
        for event in timeline {
            for keyword in keywords {
                if event.title.lowercased().contains(keyword.lowercased()) {
                    return event.date
                }
            }
        }
        return nil
    }
    
    private var steps: [StandardStep] {
        let isSentBack = loan.status.lowercased() == "sent_back"
        let isRejected = loan.status.lowercased() == "rejected"
        
        // Level 3: Disbursed
        let disbursedDate = getEventDate(for: ["Disbursed"]) ?? 
            (["disbursed", "active", "closed", "overdue"].contains(loan.status.lowercased()) ? loan.disbursedDate : "")
        let stepDisbursed = StandardStep(
            title: "Disbursed",
            date: disbursedDate,
            remarks: ["disbursed", "active", "closed", "overdue"].contains(loan.status.lowercased()) ? "Loan funds disbursed to your account." : "",
            status: targetProgress >= 3.0 ? .completed : .pending
        )
        
        // Level 2: Approved
        let approvedDate = getEventDate(for: ["Approved"]) ?? ""
        let stepApproved = StandardStep(
            title: "Approved",
            date: approvedDate,
            remarks: targetProgress >= 2.0 ? "Application approved. Awaiting disbursement." : "",
            status: targetProgress > 2.0 ? .completed : (targetProgress == 2.0 ? .active : .pending)
        )
        
        // Level 1: Under Review / Document Requested / Rejected
        let reviewTitle: String
        let reviewDate: String
        let reviewRemarks: String?
        if isSentBack {
            reviewTitle = "Document Requested"
            reviewDate = getEventDate(for: ["Sent Back"]) ?? ""
            reviewRemarks = loan.sentBackReason ?? "Loan officer has requested additional documents."
        } else if isRejected {
            reviewTitle = "Application Rejected"
            reviewDate = getEventDate(for: ["Rejected"]) ?? ""
            reviewRemarks = loan.rejectionReason ?? "Application did not meet credit criteria."
        } else {
            reviewTitle = "Under Review"
            reviewDate = getEventDate(for: ["Under Review"]) ?? ""
            reviewRemarks = targetProgress >= 1.0 ? "Your application is currently under verification." : ""
        }
        let stepReview = StandardStep(
            title: reviewTitle,
            date: reviewDate,
            remarks: reviewRemarks,
            status: targetProgress > 1.0 ? .completed : (targetProgress == 1.0 ? .active : .pending)
        )
        
        // Level 0: Applied
        let appliedDate = getEventDate(for: ["Applied", "Submitted"]) ?? loan.disbursedDate
        let stepApplied = StandardStep(
            title: "Applied",
            date: appliedDate,
            remarks: "Application successfully submitted.",
            status: targetProgress > 0.0 ? .completed : .active
        )
        
        return [stepDisbursed, stepApproved, stepReview, stepApplied]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                TimelineItemRow(
                    step: step,
                    isLast: index == steps.count - 1,
                    fillFraction: index < steps.count - 1 ? max(0.0, min(1.0, animatedProgress - Double(steps.count - 2 - index))) : 0.0,
                    loan: loan,
                    isUploading: $isUploading,
                    uploadError: $uploadError,
                    uploadSuccess: $uploadSuccess,
                    selectedItem: $selectedItem
                )
            }
            
            if loan.status.lowercased() == "pending_acceptance" {
                VStack(spacing: 12) {
                    Divider().padding(.vertical, 8)
                    
                    if let error = actionError {
                        Text(error)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            guard let appId = loan.applicationId else { return }
                            Task {
                                await MainActor.run { isRejecting = true; actionError = nil }
                                do {
                                    try await LoanService.shared.rejectDisbursement(applicationId: appId)
                                    await MainActor.run {
                                        isRejecting = false
                                        NotificationCenter.default.post(name: .loanDataDidChange, object: nil)
                                    }
                                } catch {
                                    await MainActor.run {
                                        isRejecting = false
                                        actionError = error.localizedDescription
                                    }
                                }
                            }
                        }) {
                            Text(isRejecting ? "Wait..." : "Reject Terms")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                        }
                        .disabled(isAccepting || isRejecting)
                        
                        Button(action: {
                            guard let appId = loan.applicationId else { return }
                            Task {
                                await MainActor.run { isAccepting = true; actionError = nil }
                                do {
                                    try await LoanService.shared.acceptDisbursement(applicationId: appId)
                                    await MainActor.run {
                                        isAccepting = false
                                        NotificationCenter.default.post(name: .loanDataDidChange, object: nil)
                                    }
                                } catch {
                                    await MainActor.run {
                                        isAccepting = false
                                        actionError = error.localizedDescription
                                    }
                                }
                            }
                        }) {
                            Text(isAccepting ? "Wait..." : "Accept Disbursement")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(hex: "#2D8B4E"))
                                .cornerRadius(12)
                        }
                        .disabled(isAccepting || isRejecting)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(cornerRadius: 22)
        .onAppear {
            animatedProgress = 0.0
            withAnimation(.spring(response: 0.84, dampingFraction: 0.85).delay(0.12)) {
                animatedProgress = targetProgress
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let item = newItem else { return }
            isUploading = true
            uploadError = nil
            uploadSuccess = nil
            
            Task {
                do {
                    guard let data = try? await item.loadTransferable(type: Data.self) else {
                        throw NSError(domain: "ImageLoadError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to read image data"])
                    }
                    
                    guard let appId = loan.applicationId else {
                        throw NSError(domain: "AppIdError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Application ID not found"])
                    }
                    
                    guard let userId = authViewModel.currentUser?.id else {
                        throw NSError(domain: "UserIdError", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
                    }
                    
                    try await LoanService.shared.resubmitApplication(
                        applicationId: appId,
                        newDocuments: ["additional_document": data],
                        userId: userId
                    )
                    
                    await MainActor.run {
                        uploadSuccess = "Document uploaded successfully!"
                        isUploading = false
                        NotificationCenter.default.post(name: .loanDataDidChange, object: nil)
                    }
                } catch {
                    await MainActor.run {
                        uploadError = error.localizedDescription
                        isUploading = false
                    }
                }
            }
        }
    }
}

private struct TimelineItemRow: View {
    let step: TimelineCard.StandardStep
    let isLast: Bool
    let fillFraction: Double
    let loan: LoanListItem
    
    @Binding var isUploading: Bool
    @Binding var uploadError: String?
    @Binding var uploadSuccess: String?
    @Binding var selectedItem: PhotosPickerItem?
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                // Circle Node
                nodeView
                
                // Segment Line
                if !isLast {
                    ZStack(alignment: .bottom) {
                        Rectangle()
                            .fill(Color(hex: "#E0E0E0"))
                            .frame(width: 2)
                        
                        Rectangle()
                            .fill(Color(hex: "#2D8B4E"))
                            .frame(width: 2)
                            .scaleEffect(y: fillFraction, anchor: .bottom)
                    }
                    .frame(width: 28) // Center align with circle
                    .frame(maxHeight: .infinity)
                    .minFrameHeight()
                }
            }
            
            // Text Content Column
            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(textColor)
                
                if !step.date.isEmpty {
                    Text(step.date)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(hex: "#9E9E9E"))
                }
                
                if let remarks = step.remarks, !remarks.isEmpty {
                    Text(remarks)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(remarksColor)
                        .padding(.top, 2)
                }
                
                // If it is Document Requested, show inline PhotosPicker
                if step.title == "Document Requested" && step.status == .active {
                    VStack(alignment: .leading, spacing: 8) {
                        if isUploading {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Uploading...")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "#2D8B4E"))
                            }
                            .padding(.top, 4)
                        } else {
                            PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.up.doc.fill")
                                        .font(.system(size: 12))
                                    Text("Upload Document")
                                        .font(.system(size: 13, weight: .bold))
                                        .underline()
                                }
                                .foregroundColor(Color(hex: "#2D8B4E"))
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                        }
                        
                        if let err = uploadError {
                            Text(err)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.red)
                        }
                        if let success = uploadSuccess {
                            Text(success)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(hex: "#2D8B4E"))
                        }
                    }
                }
            }
            .padding(.top, 3)
            .padding(.bottom, isLast ? 0 : 20) // Spacing below content to align with line stretch
            
            Spacer(minLength: 0)
        }
    }
    
    @ViewBuilder
    private var nodeView: some View {
        ZStack {
            switch step.status {
            case .completed:
                Circle()
                    .fill(Color(hex: "#2D8B4E"))
                    .frame(width: 28, height: 28)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                
            case .active:
                if step.title == "Document Requested" {
                    Circle()
                        .stroke(Color(hex: "#E65100"), lineWidth: 2)
                        .background(Circle().fill(Color(hex: "#FFF3E0")))
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "#E65100"))
                } else if step.title == "Application Rejected" {
                    Circle()
                        .stroke(Color(hex: "#D32F2F"), lineWidth: 2)
                        .background(Circle().fill(Color(hex: "#FFEBEE")))
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "#D32F2F"))
                } else {
                    Circle()
                        .stroke(Color(hex: "#2D8B4E"), lineWidth: 2)
                        .background(Circle().fill(Color.white))
                        .frame(width: 28, height: 28)
                    
                    Circle()
                        .fill(Color(hex: "#2D8B4E"))
                        .frame(width: 12, height: 12)
                }
                
            case .pending:
                Circle()
                    .stroke(Color(hex: "#D3D3D3"), lineWidth: 2)
                    .background(Circle().fill(Color.white))
                    .frame(width: 28, height: 28)
                
                Circle()
                    .fill(Color(hex: "#D3D3D3"))
                    .frame(width: 8, height: 8)
            }
        }
    }
    
    private var textColor: Color {
        switch step.status {
        case .completed, .active:
            return Color(hex: "#1A1A1A")
        case .pending:
            return Color(hex: "#9E9E9E")
        }
    }
    
    private var remarksColor: Color {
        if step.title == "Document Requested" && step.status == .active {
            return Color(hex: "#E65100")
        } else if step.title == "Application Rejected" && step.status == .active {
            return Color(hex: "#D32F2F")
        } else {
            return Color(hex: "#2D8B4E")
        }
    }
}

// Helper modifier to handle minimum line heights between nodes
private struct MinFrameHeightModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(minHeight: 38)
    }
}

extension View {
    fileprivate func minFrameHeight() -> some View {
        modifier(MinFrameHeightModifier())
    }
}

// MARK: - Documents

private struct DocumentsList: View {
    let loan: LoanListItem
    let documents: [LoanDocumentItem]
    let borrowerName: String
    let onUpload: (Data, String) -> Void
    let onPreview: (URL) -> Void
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var customDocumentName: String = ""

    var body: some View {
        VStack(spacing: 20) {
            
            // Official Documents (Sanction Letter, etc)
            if loan.status.lowercased() == "active" || loan.status.lowercased() == "approved" || loan.status.lowercased() == "disbursed" {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Official Documents")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "#6B6B6B"))
                        .textCase(.uppercase)
                        .padding(.horizontal, 4)
                        
                    Button {
                        isProcessing = true
                        DispatchQueue.global(qos: .userInitiated).async {
                            let pdfData = SanctionLetterService.shared.generateSanctionLetterPDF(
                                borrowerName: borrowerName,
                                applicationNo: loan.loanNumber,
                                approvedAmount: loan.amount,
                                interestRate: loan.interestRate,
                                tenureMonths: loan.emiSchedule?.count ?? (loan.requestedTenure ?? 12),
                                emiAmount: loan.emiAmount > 0 ? loan.emiAmount : (loan.amount / Double(loan.requestedTenure ?? 12)),
                                branchName: "Head Office"
                            )
                            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Sanction_Letter_\(loan.loanNumber).pdf")
                            try? pdfData.write(to: url)
                            DispatchQueue.main.async {
                                isProcessing = false
                                onPreview(url)
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "#E8F5EC"))
                                    .frame(width: 34, height: 34)
                                Image(systemName: "doc.richtext.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(hex: "#2D8B4E"))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sanction Letter")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(hex: "#1A1A1A"))
                                Text("Generated Automatically")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "#9E9E9E"))
                            }

                            Spacer()

                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "#2D8B4E"))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.6))
                        .liquidGlass(cornerRadius: 18)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(isProcessing)
                }
            }

            // Uploaded Documents
            VStack(alignment: .leading, spacing: 8) {
                Text("Uploaded Documents")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "#6B6B6B"))
                    .textCase(.uppercase)
                    .padding(.horizontal, 4)

                ForEach(documents) { document in
                    Button {
                        isProcessing = true
                        Task {
                            defer { isProcessing = false }
                            if let storagePath = document.storagePath {
                                do {
                                    let data = try await SupabaseManager.shared.client.storage
                                        .from("documents")
                                        .download(path: storagePath)
                                    let fileName = storagePath.split(separator: "/").last.map(String.init) ?? "document.jpg"
                                    let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                                    try data.write(to: url)
                                    onPreview(url)
                                } catch {
                                    print("Failed to download document:", error)
                                }
                            }
                        }
                    } label: {
                        LoanDocumentRowView(document: document)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(isProcessing)
                }
                
                if loan.applicationId != nil {
                    VStack(spacing: 12) {
                        TextField("Document Name (e.g. Bank Statement)", text: $customDocumentName)
                            .padding(14)
                            .background(Color.white.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#2D8B4E").opacity(0.3), lineWidth: 1))
                            .foregroundColor(Color(hex: "#1A1A1A"))
                            
                        PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text(customDocumentName.isEmpty ? "Enter Name to Upload" : "Upload \(customDocumentName)")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(customDocumentName.isEmpty ? Color(hex: "#9E9E9E") : Color(hex: "#2D8B4E"))
                            .liquidGlass(cornerRadius: 18)
                        }
                        .disabled(customDocumentName.isEmpty || isProcessing)
                        .buttonStyle(ScaleButtonStyle())
                        
                        .onChange(of: selectedItem) { _, newItem in
                            guard let item = newItem, !customDocumentName.isEmpty else { return }
                            isProcessing = true
                            Task {
                                if let data = try? await item.loadTransferable(type: Data.self) {
                                    onUpload(data, customDocumentName)
                                    customDocumentName = ""
                                }
                                isProcessing = false
                                selectedItem = nil
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
            
            if isProcessing {
                ProgressView()
                    .padding()
            }
        }
    }
}

private struct LoanDocumentRowView: View {
    let document: LoanDocumentItem

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#E8F5EC"))
                    .frame(width: 34, height: 34)
                Image(systemName: document.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#2D8B4E"))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(document.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#1A1A1A"))
                Text(document.uploadDate)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#9E9E9E"))
            }

            Spacer()

            Image(systemName: "chevron.right.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "#2D8B4E"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.6))
        .liquidGlass(cornerRadius: 18)
    }
}

// MARK: - Schedule

private struct ScheduleList: View {
    let schedule: [LoanEMIItem]
    let formatCurrency: (Double) -> String

    var body: some View {
        VStack(spacing: 8) {
            ForEach(schedule) { emi in
                EMIScheduleRowView(emi: emi, formatCurrency: formatCurrency)
            }
        }
    }
}

private struct EMIScheduleRowView: View {
    let emi: LoanEMIItem
    let formatCurrency: (Double) -> String

    private var accentColor: Color {
        switch emi.status {
        case .paid: return Color(hex: "#2D8B4E")
        case .overdue: return Color(hex: "#D94040")
        case .upcoming: return Color(hex: "#2D8B4E")
        }
    }

    private var bgColor: Color {
        switch emi.status {
        case .paid: return Color(hex: "#E8F5EC")
        case .overdue: return Color(hex: "#FDE8E8")
        case .upcoming: return Color.clear
        }
    }

    private var statusTextColor: Color {
        switch emi.status {
        case .paid: return Color(hex: "#2D8B4E")
        case .overdue: return Color(hex: "#D94040")
        case .upcoming: return Color(hex: "#1A1A1A")
        }
    }

    private var statusIcon: String {
        switch emi.status {
        case .paid: return "checkmark.circle.fill"
        case .overdue: return "exclamationmark.triangle.fill"
        case .upcoming: return "clock.fill"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Side accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor)
                .frame(width: 3)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 2) {
                Text("Due Date")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#9E9E9E"))
                Text(emi.dueDate)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#1A1A1A"))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCurrency(emi.amount))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#1A1A1A"))
                HStack(spacing: 3) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 9, weight: .bold))
                    Text(emi.status.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(statusTextColor)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(bgColor)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .liquidGlass(
            cornerRadius: 18,
            borderColor: accentColor,
            borderOpacity: 0.2,
            shadowOpacity: 0.04,
            shadowRadius: 10,
            shadowY: 4
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
    let loanStatus: String
    let loanName: String
    let loanNumber: String
    let remainingAmount: Double
    let monthlyEMI: Double
    let emiDueView: AnyView
    let tenureText: String
    let remainingTenureText: String
    let interestRateText: String
    let remainingEMIText: String
    let repaymentProgress: Double
    let progressText: String
    let timeline: [LoanTimelineItem]
    var documents: [LoanDocumentItem]
    let schedule: [LoanEMIItem]
    let applicationId: UUID?

    static func make(from loan: LoanListItem) -> LoanDetailMock {
        let emiAmount = loan.emiAmount > 0 ? loan.emiAmount : 20_000
        let interestRate = loan.interestRate > 0 ? loan.interestRate : 7.85

        let actualPaidAmount = loan.paidAmount
        let totalEMIs = loan.emiSchedule?.count ?? (loan.requestedTenure ?? 12)
        let paidEMIs = emiAmount > 0 ? Int(actualPaidAmount / emiAmount) : 0
        let remainingEMIs = max(totalEMIs - paidEMIs, 0)
        let progressInt = Int(loan.paidPercent * 100)
        
        let subtitleView: AnyView
        if remainingEMIs == 0 {
            subtitleView = AnyView(
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "#2D8B4E"))
                    Text("Fully Paid")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "#2D8B4E"))
                }
            )
        } else if let nextDueStr = loan.nextDueDate, let date = LoansListView.parseDateString(nextDueStr) {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd MMM yyyy"
            subtitleView = AnyView(
                Text("Due \(formatter.string(from: date))")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Color(hex: "#9E9E9E"))
            )
        } else {
            subtitleView = AnyView(
                Text("As per schedule")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Color(hex: "#9E9E9E"))
            )
        }

        return LoanDetailMock(
            loanStatus: loan.status,
            loanName: loan.name.isEmpty ? "Premium Home Loan" : loan.name,
            loanNumber: loan.loanNumber.isEmpty ? "HL-2026-00895672" : loan.loanNumber,
            remainingAmount: loan.remainingAmount,
            monthlyEMI: emiAmount,
            emiDueView: subtitleView,
            tenureText: "\(totalEMIs) months",
            remainingTenureText: "\(remainingEMIs) months",
            interestRateText: String(format: "%.1f%%", interestRate),
            remainingEMIText: remainingEMIs > 0 ? "\(remainingEMIs) EMIs left" : "All paid",
            repaymentProgress: loan.paidPercent,
            progressText: progressInt > 0 ? "₹\(Int(loan.paidAmount)) paid" : "No EMIs paid",
            timeline: {
                if let backendTimeline = loan.timeline {
                    var uniqueItems: [LoanTimelineItem] = []
                    var seenTitles: Set<String> = []
                    for item in backendTimeline {
                        if !seenTitles.contains(item.title) {
                            seenTitles.insert(item.title)
                            uniqueItems.append(LoanTimelineItem(title: item.title, date: item.date, remarks: item.remarks))
                        }
                    }
                    return uniqueItems
                } else {
                    return [
                        LoanTimelineItem(title: "Applied", date: loan.disbursedDate, remarks: nil),
                        LoanTimelineItem(title: "Approved", date: loan.disbursedDate, remarks: nil),
                        LoanTimelineItem(title: "Disbursed", date: loan.disbursedDate, remarks: nil)
                    ]
                }
            }(),
            documents: loan.documents?.map { LoanDocumentItem(title: $0.title, uploadDate: $0.uploadDate, icon: $0.icon, storagePath: $0.storagePath) } ?? [],
            schedule: buildSchedule(from: loan),
            applicationId: loan.applicationId
        )
    }

    /// Build a realistic schedule based on actual paid amount and backend schedule
    private static func buildSchedule(from loan: LoanListItem) -> [LoanEMIItem] {
        guard let schedule = loan.emiSchedule else { return [] }
        
        let emiAmount = loan.emiAmount > 0 ? loan.emiAmount : (schedule.first?.amount ?? 20_000)
        let paidCount = emiAmount > 0 ? Int(loan.paidAmount / emiAmount) : 0
        let calendar = Calendar.current
        let today = Date()

        return schedule.enumerated().compactMap { index, emi -> LoanEMIItem? in
            guard let date = LoansListView.parseDateString(emi.dueDate) else { return nil }
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM yyyy"
            let dateStr = formatter.string(from: date)

            let status: LoanEMIStatus
            if emi.status.lowercased() == "paid" || index < paidCount {
                status = .paid
            } else {
                let dueDay = calendar.startOfDay(for: date)
                let todayDay = calendar.startOfDay(for: today)
                status = dueDay < todayDay ? .overdue : .upcoming
            }

            return LoanEMIItem(dueDate: dateStr, amount: emi.amount, status: status)
        }
    }
}

private struct LoanTimelineItem: Identifiable {
    let id = UUID()
    let title: String
    let date: String
    let remarks: String?
}

private struct LoanDocumentItem: Identifiable {
    let id = UUID()
    let title: String
    let uploadDate: String
    let icon: String
    let storagePath: String?
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
