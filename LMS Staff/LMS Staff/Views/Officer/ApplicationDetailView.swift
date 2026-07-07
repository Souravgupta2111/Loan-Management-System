//
//  ApplicationDetailView.swift
//  LMS Staff
//
//  Detailed inspector view for a single loan application.
//

import SwiftUI

struct ApplicationDetailView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    let appWithBorrower: ApplicationWithBorrower
    let onStatusUpdated: () -> Void
    
    @StateObject private var vm: ApplicationDetailViewModel
    @Environment(\.openURL) private var openURL
    
    @State private var activeTab: InspectorTab = .profile
    
    // Bottom Action Sheets
    @State private var showRejectSheet: Bool = false
    @State private var showRecommendSheet: Bool = false
    @State private var showSendBackSheet: Bool = false
    
    // Modals data
    @State private var remarks: String = ""

    @State private var showShareSheet = false
    @State private var pdfShareURL: URL? = nil
    @State private var showIncomeVerification = false
    
    // Manager action states
    @State private var showManagerApprovalSheet: Bool = false
    @State private var showManagerRejectSheet: Bool = false
    @State private var showManagerSendBackSheet: Bool = false
    @State private var mgrApprovedAmount: Double = 0.0
    @State private var mgrApprovedTenure: Int = 12
    @State private var mgrApprovedRate: Double = 10.0
    @State private var mgrRemarks: String = ""

    enum InspectorTab: String, CaseIterable {
        case profile = "KYC & Credit"
        case documents = "Documents"
        case chat = "Chat History"
        case timeline = "Timeline Log"
        case emiSchedule = "EMI Schedule"
    }
    
    init(appWithBorrower: ApplicationWithBorrower, onStatusUpdated: @escaping () -> Void) {
        self.appWithBorrower = appWithBorrower
        self.onStatusUpdated = onStatusUpdated
        
        // Initialize viewmodel
        _vm = StateObject(wrappedValue: ApplicationDetailViewModel(
            application: appWithBorrower.application,
            borrower: appWithBorrower.borrower,
            profile: appWithBorrower.profile,
            product: appWithBorrower.product
        ))
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
            // Header Info Bar
            HStack(spacing: StaffSpacing.lg) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(appWithBorrower.borrower.fullName)
                            .font(.staffTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.staffTextPrimary)
                        
                        StaffStatusBadge(status: vm.application.status.officerDisplayName)
                    }
                    
                    Text("App ID: \(vm.application.id.uuidString.prefix(8)) | Product: \(vm.product.name)")
                        .font(.staffCaption)
                        .foregroundColor(.staffTextSecondary)
                }
                
                Spacer()
                
                // Primary Application metrics
                HStack(spacing: StaffSpacing.xl) {
                    DetailMetric(label: "Requested Amount", value: "INR \(String(format: "%.2f", vm.application.requestedAmount))")
                    DetailMetric(label: "Tenure", value: "\(vm.application.requestedTenureMonths) Months")
                    DetailMetric(label: "Branch", value: "HQ - Main Branch")
                }
            }
            .padding(StaffSpacing.lg)
            .background(Color.staffBackground)
            
            // Tab Selector bar
            HStack(spacing: 0) {
                ForEach(InspectorTab.allCases.filter { tab in
                    if tab == .emiSchedule {
                        return vm.application.status == .disbursed || vm.application.status == .pendingDisbursal || vm.activeLoan != nil
                    }
                    return true
                }, id: \.self) { tab in
                    Button(action: { activeTab = tab }) {
                        VStack(spacing: 8) {
                            Text(tab.rawValue)
                                .font(.staffBody)
                                .fontWeight(activeTab == tab ? .bold : .regular)
                                .foregroundColor(activeTab == tab ? .staffAccent : .staffTextSecondary)
                            
                            // Indicator line
                            Rectangle()
                                .fill(activeTab == tab ? Color.staffAccent : Color.clear)
                                .frame(height: 3)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .background(Color.staffSurface.opacity(0.5))
            
            // Content Body based on selected Tab
            if activeTab == .chat {
                ChatSupportConsole(appWithBorrower: appWithBorrower, forceInternalOnly: authViewModel.currentUser?.role == .manager)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: StaffSpacing.xl) {
                        switch activeTab {
                        case .profile:
                            kycAndCreditSection
                        case .documents:
                            documentsSection
                        case .chat:
                            EmptyView()
                        case .timeline:
                            timelineSection
                        case .emiSchedule:
                            emiScheduleSection
                        }
                    }
                    .padding(StaffSpacing.lg)
                }
                .background(Color.staffBackground)
            }
            
            if activeTab != .chat && activeTab != .timeline {
                if vm.application.status == .approved || vm.application.status == .disbursed || vm.application.status == .rejected || ((vm.application.status == .submitted || vm.application.status == .underReview || vm.application.status == .sentBack) && authViewModel.currentUser?.role != .admin) {
                    Divider()
                        .background(Color.staffBorder)
                    actionButtonBar
                }
            }

        }
        }
        .task {
            await vm.loadAllDetails()
        }
        .onChange(of: appWithBorrower) { newValue in
            vm.application = newValue.application
            vm.borrower = newValue.borrower
            vm.borrowerProfile = newValue.profile
            vm.product = newValue.product
            Task {
                await vm.loadAllDetails()
            }
        }
        .navigationBarHidden(false)
        // MODALS/SHEETS LIST
        .background(EmptyView().sheet(isPresented: $showRejectSheet) {
            rejectionRemarksSheet
                .presentationBackground(Color.staffBackground)
        })
        .background(EmptyView().sheet(isPresented: $showRecommendSheet) {
            recommendChecklistSheet
                .presentationBackground(Color.staffBackground)
        })
        .background(EmptyView().sheet(isPresented: $showSendBackSheet) {
            sendBackRemarksSheet
                .presentationBackground(Color.staffBackground)
        })
        .background(EmptyView().sheet(isPresented: $showShareSheet) {
            if let url = pdfShareURL {
                ShareSheet(activityItems: [url])
            }
        })
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { isPresented in if !isPresented { vm.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "An unknown error occurred.")
        }
        .background(EmptyView().sheet(isPresented: $showIncomeVerification) {
            IncomeVerificationView(
                consentId: vm.borrowerProfile?.aaConsentId,
                consentStatus: vm.borrowerProfile?.aaConsentStatus,
                onVerificationComplete: { analyzedData in
                    Task {
                        await vm.saveVerifiedIncome(analyzedData)
                    }
                }
            )
            .presentationBackground(Color.staffBackground)
        })
        // Manager Action Sheets
        .background(EmptyView().sheet(isPresented: $showManagerApprovalSheet) {
            managerApprovalTermsSheet
                .presentationBackground(Color.staffBackground)
        })
        .background(EmptyView().sheet(isPresented: $showManagerRejectSheet) {
            managerRejectionSheet
                .presentationBackground(Color.staffBackground)
        })
        .background(EmptyView().sheet(isPresented: $showManagerSendBackSheet) {
            managerSendBackSheet
                .presentationBackground(Color.staffBackground)
        })
    }
    
    // MARK: - Subviews
    
    private var kycAndCreditSection: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.lg) {
            HStack(spacing: StaffSpacing.lg) {
                // Personal KYC info
                StaffCard {
                    VStack(alignment: .leading, spacing: StaffSpacing.md) {
                        Text("KYC Verification Details")
                            .font(.staffTitle)
                            .foregroundColor(.staffTextPrimary)
                        
                        Divider()
                        
                        KYCRow(label: "Full Name", value: vm.borrower.fullName)
                        KYCRow(label: "Email", value: vm.borrower.email ?? "N/A")
                        KYCRow(label: "Phone", value: vm.borrower.phone ?? "N/A")
                        KYCRow(label: "PAN ID", value: vm.borrowerProfile?.panNumber ?? "N/A")
                        KYCRow(label: "Aadhaar Card", value: vm.borrowerProfile?.aadhaarNumber ?? "N/A")
                        
                        if let verifiedAnnual = vm.borrowerProfile?.verifiedAnnualIncome {
                            KYCRow(label: "Verified Monthly", value: "INR \(String(format: "%.2f", verifiedAnnual / 12))")
                        } else {
                            KYCRow(label: "Declared Monthly", value: vm.borrowerProfile?.monthlyIncome != nil ? "INR \(String(format: "%.2f", vm.borrowerProfile!.monthlyIncome!))" : "N/A")
                        }
                        
                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Credit Bureau Score Gauge
                StaffCard {
                    VStack(spacing: StaffSpacing.md) {
                        Text("Credit Bureau Rating")
                            .font(.staffTitle)
                            .foregroundColor(.staffTextPrimary)
                        
                        Divider()
                        
                        Spacer(minLength: 0)
                        
                        CreditScoreGauge(score: vm.borrowerProfile?.creditScore ?? 300)
                        
                        Spacer(minLength: 0)
                    }
                }
                .frame(width: 320)
                .frame(maxHeight: .infinity)
            }
            .fixedSize(horizontal: false, vertical: true)
            
            // Underwriting Analysis Card
            if let suggestion = vm.underwritingSuggestion {
                StaffCard {
                    VStack(alignment: .leading, spacing: StaffSpacing.md) {
                        HStack {
                            Text("Loan Eligibility Analysis")
                                .font(.staffTitle)
                                .foregroundColor(.staffTextPrimary)
                            
                            Spacer()
                            
                            if suggestion.incomeVerified {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(.staffGreen)
                                    Text("Income AA Verified")
                                        .font(.staffCaption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.staffGreen)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.staffGreen.opacity(0.15))
                                .cornerRadius(12)
                            } else {
                                Button(action: {
                                    showIncomeVerification = true
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "banknote.fill")
                                        Text("Verify via AA")
                                    }
                                    .font(.staffCaption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.staffAccent)
                                    .cornerRadius(12)
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Eligibility Checklist (shown for all roles)
                        VStack(spacing: 16) {
                            eligibilityCheckRow(title: "Account Aggregator Income Verification", isPassed: suggestion.incomeVerified)
                            eligibilityCheckRow(title: "Credit Bureau Minimum Score Requirement", isPassed: (vm.borrowerProfile?.creditScore ?? 0) >= 600)
                            eligibilityCheckRow(title: "FOIR (Debt-to-Income) Capacity Check", isPassed: !suggestion.rejectionReasons.contains(where: { $0.contains("FOIR") }))
                            eligibilityCheckRow(title: "Product Minimum Limit Check", isPassed: !suggestion.rejectionReasons.contains(where: { $0.contains("product minimum") }))
                            
                            Divider()
                                .padding(.vertical, 4)
                            
                            HStack {
                                Text("Overall System Decision")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.staffTextPrimary)
                                Spacer()
                                HStack(spacing: 6) {
                                    Image(systemName: suggestion.isEligible ? "checkmark.seal.fill" : "xmark.seal.fill")
                                    Text(suggestion.isEligible ? "ELIGIBLE" : "NOT ELIGIBLE")
                                }
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundColor(suggestion.isEligible ? .staffGreen : .staffRed)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(suggestion.isEligible ? Color.staffGreen.opacity(0.15) : Color.staffRed.opacity(0.15))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.vertical, 8)
                        
                        // Financial Predictions (Manager & Admin only)
                        if authViewModel.currentUser?.role == .manager || authViewModel.currentUser?.role == .admin {
                            Divider()
                            
                            Text("Financial Analysis & Recommendations")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.staffTextPrimary)
                                .padding(.top, 4)
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Max Eligible")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.staffTextSecondary)
                                    Text("INR \(String(format: "%.0f", suggestion.maxEligibleAmount))")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.staffTextPrimary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                
                                Spacer(minLength: 8)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Suggested")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.staffTextSecondary)
                                    Text("INR \(String(format: "%.0f", suggestion.suggestedAmount))")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.staffGreen)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                
                                Spacer(minLength: 8)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Rate / Tenure")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.staffTextSecondary)
                                    Text("\(String(format: "%.1f", suggestion.suggestedInterestRate))% / \(suggestion.suggestedTenureMonths)m")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.staffTextPrimary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                
                                Spacer(minLength: 8)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("FOIR Ratio")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.staffTextSecondary)
                                    Text("\(String(format: "%.1f", suggestion.foirRatio * 100))%")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(suggestion.foirRatio > 0.5 ? .staffAmber : .staffTextPrimary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                
                                Spacer(minLength: 8)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Monthly EMI")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.staffTextSecondary)
                                    Text("INR \(String(format: "%.0f", suggestion.monthlyEMI))")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.staffTextPrimary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                
                                Spacer(minLength: 8)
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Risk Grade")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.staffTextSecondary)
                                    Text(suggestion.riskGrade)
                                        .font(.system(size: 20, weight: .heavy))
                                        .foregroundColor(gradeColor(for: suggestion.riskGrade))
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.top, 4)
                            
                            // Rejection reasons if any
                            if !suggestion.rejectionReasons.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Risk Flags")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.staffRed)
                                    ForEach(suggestion.rejectionReasons, id: \.self) { reason in
                                        HStack(spacing: 6) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .font(.system(size: 11))
                                                .foregroundColor(.staffAmber)
                                            Text(reason)
                                                .font(.system(size: 13))
                                                .foregroundColor(.staffTextSecondary)
                                        }
                                    }
                                }
                                .padding(12)
                                .background(Color.staffRed.opacity(0.05))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func eligibilityCheckRow(title: String, isPassed: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isPassed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isPassed ? .staffGreen : .staffRed)
                .font(.system(size: 18))
            
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.staffTextPrimary)
            
            Spacer()
            
            Text(isPassed ? "Passed" : "Failed")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(isPassed ? .staffGreen : .staffRed)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isPassed ? Color.staffGreen.opacity(0.1) : Color.staffRed.opacity(0.1))
                .cornerRadius(6)
        }
    }
    
    private func gradeColor(for grade: String) -> Color {
        switch grade {
        case "A": return .staffGreen
        case "B": return Color(hex: "#8BC34A")
        case "C": return .staffAmber
        case "D": return .staffOrange
        case "E": return .staffRed
        default: return .staffTextPrimary
        }
    }
    
    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.md) {
            Text("Verification Checklist & Files")
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
            
            if vm.documents.isEmpty {
                EmptyStateView(
                    icon: "doc.badge.plus",
                    title: "No Documents Uploaded",
                    message: "The borrower has not uploaded files yet, or you haven't requested any."
                )
            } else {
                ForEach(vm.documents) { doc in
                    HStack(spacing: StaffSpacing.md) {
                        Image(systemName: "doc.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                            .foregroundColor(.staffAccent)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(doc.documentType)
                                .font(.staffBody)
                                .fontWeight(.bold)
                                .foregroundColor(.staffTextPrimary)
                            
                            Text(doc.fileName)
                                .font(.staffCaption)
                                .foregroundColor(.staffTextSecondary)
                        }
                        
                        Spacer()
                        
                        // Action buttons
                        if authViewModel.currentUser?.role != .admin {
                            Button(action: {
                                Task {
                                    if let url = await vm.getDocumentUrl(for: doc) {
                                        openURL(url)
                                    }
                                }
                            }) {
                                Text("View")
                                    .font(.staffCaption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.staffAccent)
                                    .cornerRadius(StaffCorner.sm)
                                    .shadow(color: Color.staffAccent.opacity(0.3), radius: 2, x: 0, y: 1)
                            }
                        }
                        
                        if doc.isVerified {
                            Text("Verified")
                                .font(.staffCaption)
                                .fontWeight(.bold)
                                .foregroundColor(.staffGreen)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.staffGreen.opacity(0.15))
                                .cornerRadius(StaffCorner.sm)
                                
                            if authViewModel.currentUser?.role == .officer {
                                Button(action: {
                                    Task {
                                        await vm.verifyDocument(documentId: doc.id, isVerified: false, reason: nil)
                                    }
                                }) {
                                    Text("Unverify")
                                        .font(.staffCaption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.staffAmber)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.staffAmber.opacity(0.15))
                                        .cornerRadius(StaffCorner.sm)
                                }
                            }
                        } else {
                            if authViewModel.currentUser?.role == .officer {
                                Button(action: {
                                    Task {
                                        await vm.verifyDocument(documentId: doc.id, isVerified: true)
                                    }
                                }) {
                                    Text("Verify")
                                        .font(.staffCaption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.staffGreen)
                                        .cornerRadius(StaffCorner.sm)
                                }
                                
                                Button(action: {
                                    Task {
                                        await vm.verifyDocument(documentId: doc.id, isVerified: false, reason: "Illegible document scan.")
                                    }
                                }) {
                                    Text("Reject")
                                        .font(.staffCaption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.staffRed)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: StaffCorner.sm)
                                                .stroke(Color.staffRed, lineWidth: 1)
                                        )
                                }
                            } else {
                                Text("Not Verified")
                                    .font(.staffCaption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.staffAmber)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.staffAmber.opacity(0.15))
                                    .cornerRadius(StaffCorner.sm)
                            }
                        }
                    }
                    .padding(StaffSpacing.md)
                    .background(Color.staffSurface)
                    .cornerRadius(StaffCorner.md)
                }
            }
            
            if vm.application.status == .disbursed {
                Divider()
                    .background(Color.staffBorder)
                    .padding(.vertical, StaffSpacing.md)
                
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.staffGreen)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Application Approved")
                            .font(.staffBody)
                            .fontWeight(.bold)
                            .foregroundColor(.staffTextPrimary)
                        Text("Sanction letter has been automatically generated.")
                            .font(.staffCaption)
                            .foregroundColor(.staffTextSecondary)
                    }
                    
                    Spacer()
                    
                    if authViewModel.currentUser?.role != .admin {
                        StaffButton(title: "Download Sanction Letter", style: .primary, icon: "doc.text.fill") {
                            generateAndShareSanctionLetter()
                        }
                        .frame(width: 250)
                    }
                }
                .padding(StaffSpacing.lg)
                .background(Color.staffGreen.opacity(0.1))
                .cornerRadius(StaffCorner.md)
                .overlay(
                    RoundedRectangle(cornerRadius: StaffCorner.md)
                        .stroke(Color.staffGreen.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
    

    
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.md) {
            Text("Application Pipeline")
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
            
            StaffLoanPipelineView(stages: vm.pipelineStages)
        }
    }
    
    private var actionButtonBar: some View {
        Group {
            if authViewModel.currentUser?.role == .manager && vm.application.status == .underReview {
                GeometryReader { geometry in
                    let totalWidth = geometry.size.width
                    let sidePadding = totalWidth * 0.03
                    let spacingBetween = totalWidth * 0.02
                    let buttonWidth = totalWidth * 0.30
                    
                    HStack(spacing: spacingBetween) {
                        StaffButton(title: "Send Back", style: .outline, icon: "arrow.uturn.left") {
                            showManagerSendBackSheet = true
                        }
                        .frame(width: buttonWidth)
                        
                        StaffButton(title: "Reject", style: .destructive, icon: "xmark.circle") {
                            showManagerRejectSheet = true
                        }
                        .frame(width: buttonWidth)
                        
                        StaffButton(title: "Verify & Approve", style: .success, icon: "checkmark.seal.fill") {
                            if let suggestion = vm.underwritingSuggestion {
                                mgrApprovedAmount = max(vm.product.minAmount, min(suggestion.suggestedAmount > 0 ? suggestion.suggestedAmount : vm.application.requestedAmount, vm.product.maxAmount))
                                mgrApprovedTenure = max(vm.product.minTenureMonths, min(suggestion.suggestedTenureMonths > 0 ? suggestion.suggestedTenureMonths : vm.application.requestedTenureMonths, vm.product.maxTenureMonths))
                                mgrApprovedRate = max(vm.product.minInterestRate, min(suggestion.suggestedInterestRate > 0 ? suggestion.suggestedInterestRate : vm.product.minInterestRate, vm.product.maxInterestRate))
                            } else {
                                mgrApprovedAmount = vm.application.requestedAmount
                                mgrApprovedTenure = vm.application.requestedTenureMonths
                                mgrApprovedRate = vm.product.minInterestRate
                            }
                            showManagerApprovalSheet = true
                        }
                        .frame(width: buttonWidth)
                    }
                    .padding(.horizontal, sidePadding)
                    .frame(width: totalWidth, height: geometry.size.height, alignment: .center)
                }
                .frame(height: 76)
                .background(Color.staffSurface)
            } else {
                HStack(spacing: StaffSpacing.md) {
                    if vm.application.status == .approved || vm.application.status == .disbursed {
                        Spacer()
                    } else if vm.application.status == .rejected {
                        Spacer()
                        Text("Application Rejected")
                            .font(.staffTitle)
                            .foregroundColor(.staffRed)
                        Spacer()
                    } else {
                        if authViewModel.currentUser?.role == .officer {
                            if vm.application.status == .submitted || vm.application.status == .sentBack {
                                StaffButton(title: "Reject", style: .destructive, icon: "xmark.circle") {
                                    showRejectSheet = true
                                }
                                
                                Spacer(minLength: 20)
                                
                                let allVerified = vm.documents.allSatisfy { $0.isVerified } && !vm.documents.isEmpty
                                StaffButton(
                                    title: vm.application.status == .sentBack ? "Resubmit to Manager" : "Recommend to Manager",
                                    style: .primary,
                                    icon: "hand.thumbsup.fill"
                                ) {
                                    showRecommendSheet = true
                                }
                                .frame(minWidth: 240)
                                .disabled(!allVerified)
                                .opacity(allVerified ? 1.0 : 0.5)
                            } else if vm.application.status == .underReview {
                                Spacer()
                                Text("Escalated to Manager")
                                    .font(.staffTitle)
                                    .foregroundColor(.staffAmber)
                                Spacer()
                            }
                        }
                    }
                }
                .padding(StaffSpacing.lg)
                .background(Color.staffSurface)
            }
        }
    }
    
    private func generateAndShareSanctionLetter() {
        let pdfData = SanctionLetterService.shared.generateSanctionLetterPDF(
            borrowerName: vm.borrower.fullName,
            applicationNo: vm.application.applicationNumber ?? "APP-000",
            approvedAmount: vm.application.requestedAmount,
            interestRate: 12.5, // Mocked for UI
            tenureMonths: 24, // Mocked for UI
            emiAmount: (vm.application.requestedAmount / 24) * 1.05, // Mocked for UI
            branchName: "Main Branch" // Mocked for UI
        )
        
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "Sanction_Letter_\(vm.application.applicationNumber ?? "APP").pdf"
        let fileURL = tempDir.appendingPathComponent(filename)
        
        do {
            try pdfData.write(to: fileURL)
            self.pdfShareURL = fileURL
            self.showShareSheet = true
        } catch {
            print("Failed to save PDF: \(error)")
        }
    }
    
    private var emiScheduleSection: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.md) {
            Text("EMI Repayment Schedule")
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
            
            if vm.emiSchedule.isEmpty {
                EmptyStateView(
                    icon: "clock.badge.exclamationmark",
                    title: "No Schedule Found",
                    message: "The EMI schedule has not been generated for this loan yet."
                )
            } else {
                StaffCard {
                    VStack(spacing: 0) {
                        // Header row
                        HStack {
                            Text("Month")
                                .font(.staffCaption)
                                .fontWeight(.bold)
                                .foregroundColor(.staffTextSecondary)
                                .frame(width: 50, alignment: .leading)
                            
                            Text("Principal")
                                .font(.staffCaption)
                                .fontWeight(.bold)
                                .foregroundColor(.staffTextSecondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            
                            Text("Interest")
                                .font(.staffCaption)
                                .fontWeight(.bold)
                                .foregroundColor(.staffTextSecondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            
                            Text("Total EMI")
                                .font(.staffCaption)
                                .fontWeight(.bold)
                                .foregroundColor(.staffTextSecondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            
                            Text("Status")
                                .font(.staffCaption)
                                .fontWeight(.bold)
                                .foregroundColor(.staffTextSecondary)
                                .frame(width: 75, alignment: .trailing)
                        }
                        .padding(.vertical, StaffSpacing.md)
                        .padding(.horizontal, StaffSpacing.md)
                        .background(Color.staffBackground)
                        
                        // Schedule rows
                        ForEach(vm.emiSchedule.sorted(by: { $0.installmentNumber < $1.installmentNumber })) { emi in
                            Divider()
                            
                            HStack {
                                Text("\(emi.installmentNumber)")
                                    .font(.staffBody)
                                    .fontWeight(.medium)
                                    .foregroundColor(.staffTextPrimary)
                                    .frame(width: 50, alignment: .leading)
                                
                                Text("₹\(String(format: "%.0f", emi.principalComponent))")
                                    .font(.staffBody)
                                    .foregroundColor(.staffTextPrimary)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                
                                Text("₹\(String(format: "%.0f", emi.interestComponent))")
                                    .font(.staffBody)
                                    .foregroundColor(.staffTextPrimary)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                
                                Text("₹\(String(format: "%.0f", emi.totalEmi))")
                                    .font(.staffBody)
                                    .fontWeight(.bold)
                                    .foregroundColor(.staffTextPrimary)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                
                                Text(emi.status.displayName)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(emiStatusColor(emi.status))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(emiStatusColor(emi.status).opacity(0.1))
                                    .cornerRadius(4)
                                    .frame(width: 75, alignment: .trailing)
                            }
                            .padding(.vertical, StaffSpacing.md)
                            .padding(.horizontal, StaffSpacing.md)
                            .background(emi.status == .paid ? Color.staffGreen.opacity(0.05) : (emi.status == .overdue ? Color.staffRed.opacity(0.05) : Color.clear))
                        }
                    }
                }
            }
        }
    }
    
    private func emiStatusColor(_ status: EMIStatus) -> Color {
        switch status {
        case .upcoming: return .staffAccent
        case .due: return .staffOrange
        case .paid: return .staffGreen
        case .overdue: return .staffRed
        case .partiallyPaid: return .staffAmber
        }
    }
    
    // MARK: - Modals Content Sheets
    
    private var rejectionRemarksSheet: some View {
        VStack(spacing: StaffSpacing.lg) {
            Text("Rejection Remarks")
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
            
            TextEditor(text: $remarks)
                .frame(height: 120)
                .padding(8)
                .background(Color.staffSurface)
                .cornerRadius(StaffCorner.md)
                .foregroundColor(.staffTextPrimary)
            
            HStack {
                Button("Cancel") { showRejectSheet = false }
                    .foregroundColor(.staffTextSecondary)
                Spacer()
                Button("Reject Application") {
                    Task {
                        if await vm.rejectApplication(reason: remarks) {
                            showRejectSheet = false
                            onStatusUpdated()
                        }
                    }
                }
                .foregroundColor(.staffRed)
                .fontWeight(.bold)
                .disabled(remarks.isEmpty)
            }
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.staffBackground.ignoresSafeArea())
    }
    
    private var sendBackRemarksSheet: some View {
        VStack(spacing: StaffSpacing.lg) {
            Text("Send Back Remarks")
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
            
            TextEditor(text: $remarks)
                .frame(height: 120)
                .padding(8)
                .background(Color.staffSurface)
                .cornerRadius(StaffCorner.md)
                .foregroundColor(.staffTextPrimary)
            
            HStack {
                Button("Cancel") { showSendBackSheet = false }
                    .foregroundColor(.staffTextSecondary)
                Spacer()
                Button("Send Back") {
                    Task {
                        if await vm.sendBackToBorrower(reason: remarks) {
                            showSendBackSheet = false
                            onStatusUpdated()
                        }
                    }
                }
                .foregroundColor(.staffAmber)
                .fontWeight(.bold)
                .disabled(remarks.isEmpty)
            }
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.staffBackground.ignoresSafeArea())
    }
    

    
    private var recommendChecklistSheet: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.lg) {
            Text("Officer Checklist Audit")
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
            
            Text("Verify requirements checklist before sending to manager:")
                .font(.staffCaption)
                .foregroundColor(.staffTextSecondary)
            
            VStack(alignment: .leading, spacing: StaffSpacing.md) {
                ChecklistItem(text: "KYC Details matched with original scans")
                ChecklistItem(text: "Bank Details exist and confirmed")
                ChecklistItem(text: "Credit score conforms to rules guidelines")
                ChecklistItem(text: "Income verification files confirmed valid")
            }
            
            HStack {
                Button("Cancel") { showRecommendSheet = false }
                    .foregroundColor(.staffTextSecondary)
                Spacer()
                Button("Confirm & Recommend") {
                    Task {
                        if await vm.recommendToManager() {
                            showRecommendSheet = false
                            onStatusUpdated()
                        }
                    }
                }
                .foregroundColor(.staffGreen)
                .fontWeight(.bold)
            }
            .padding(.top, StaffSpacing.lg)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.staffBackground.ignoresSafeArea())
    }
    
    // MARK: - Manager Action Sheets
    
    private var managerApprovalTermsSheet: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.lg) {
            Text("Sanction Terms Configuration")
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
            
            VStack(alignment: .leading, spacing: StaffSpacing.lg) {
                VStack(alignment: .leading, spacing: StaffSpacing.sm) {
                    Text("Approved Amount: ₹\(String(format: "%.2f", mgrApprovedAmount))")
                        .font(.staffBody)
                        .fontWeight(.medium)
                        .foregroundColor(.staffTextPrimary)
                    Slider(value: $mgrApprovedAmount, in: vm.product.minAmount...vm.product.maxAmount, step: 10000)
                        .tint(.staffAccent)
                }
                
                Divider().background(Color.staffBorder)
                
                VStack(alignment: .leading, spacing: StaffSpacing.sm) {
                    Text("Approved Tenure: \(mgrApprovedTenure) Months")
                        .font(.staffBody)
                        .fontWeight(.medium)
                        .foregroundColor(.staffTextPrimary)
                    Stepper("\(mgrApprovedTenure) Months", value: $mgrApprovedTenure, in: vm.product.minTenureMonths...vm.product.maxTenureMonths, step: 1)
                        .foregroundColor(.staffTextSecondary)
                }
                
                Divider().background(Color.staffBorder)
                
                VStack(alignment: .leading, spacing: StaffSpacing.sm) {
                    Text("Approved Interest Rate: \(String(format: "%.2f", mgrApprovedRate))% Per Annum")
                        .font(.staffBody)
                        .fontWeight(.medium)
                        .foregroundColor(.staffTextPrimary)
                    Slider(value: $mgrApprovedRate, in: vm.product.minInterestRate...vm.product.maxInterestRate, step: 0.25)
                        .tint(.staffAccent)
                }
            }
            .padding(.vertical, StaffSpacing.lg)
            
            HStack(spacing: StaffSpacing.md) {
                StaffButton(title: "Cancel", style: .outline, icon: "xmark", isFullWidth: false) {
                    showManagerApprovalSheet = false
                }
                
                Spacer()
                
                StaffButton(title: "Sanction Approval", style: .primary, icon: "checkmark.seal.fill", isFullWidth: true) {
                    Task {
                        if await vm.managerApprove(approvedAmount: mgrApprovedAmount, tenureMonths: mgrApprovedTenure, interestRate: mgrApprovedRate) {
                            showManagerApprovalSheet = false
                            onStatusUpdated()
                        }
                    }
                }
            }
        }
        .padding(StaffSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Color.staffBackground.ignoresSafeArea())
    }
    
    private var managerRejectionSheet: some View {
        VStack(spacing: StaffSpacing.lg) {
            Text("Rejection Reason")
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
            
            TextEditor(text: $mgrRemarks)
                .frame(height: 120)
                .padding(8)
                .background(Color.staffSurface)
                .cornerRadius(StaffCorner.md)
                .foregroundColor(.staffTextPrimary)
            
            HStack {
                Button("Cancel") {
                    showManagerRejectSheet = false
                    mgrRemarks = ""
                }
                .foregroundColor(.staffTextSecondary)
                Spacer()
                Button("Reject Proposal") {
                    Task {
                        if await vm.managerReject(reason: mgrRemarks) {
                            showManagerRejectSheet = false
                            mgrRemarks = ""
                            onStatusUpdated()
                        }
                    }
                }
                .foregroundColor(.staffRed)
                .fontWeight(.bold)
                .disabled(mgrRemarks.isEmpty)
            }
        }
        .padding(StaffSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.staffBackground.ignoresSafeArea())
    }
    
    private var managerSendBackSheet: some View {
        VStack(spacing: StaffSpacing.lg) {
            Text("Send Back Remarks")
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
            
            TextEditor(text: $mgrRemarks)
                .frame(height: 120)
                .padding(8)
                .background(Color.staffSurface)
                .cornerRadius(StaffCorner.md)
                .foregroundColor(.staffTextPrimary)
            
            HStack {
                Button("Cancel") {
                    showManagerSendBackSheet = false
                    mgrRemarks = ""
                }
                .foregroundColor(.staffTextSecondary)
                Spacer()
                Button("Send Back to Officer") {
                    Task {
                        if await vm.managerSendBack(remarks: mgrRemarks) {
                            showManagerSendBackSheet = false
                            mgrRemarks = ""
                            onStatusUpdated()
                        }
                    }
                }
                .foregroundColor(.staffAmber)
                .fontWeight(.bold)
                .disabled(mgrRemarks.isEmpty)
            }
        }
        .padding(StaffSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.staffBackground.ignoresSafeArea())
    }
}

// MARK: - Detail Helpers

struct DetailMetric: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(label)
                .font(.staffCaption)
                .foregroundColor(.staffTextSecondary)
            Text(value)
                .font(.staffBody)
                .fontWeight(.bold)
                .foregroundColor(.staffAccent)
        }
    }
}

struct KYCRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.staffBody)
                .foregroundColor(.staffTextSecondary)
            Spacer()
            Text(value)
                .font(.staffBody)
                .fontWeight(.medium)
                .foregroundColor(.staffTextPrimary)
        }
    }
}

struct ChecklistItem: View {
    let text: String
    @State private var isChecked: Bool = false
    
    var body: some View {
        Button(action: { isChecked.toggle() }) {
            HStack(spacing: StaffSpacing.md) {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .foregroundColor(isChecked ? .staffGreen : .staffBorder)
                Text(text)
                    .font(.staffBody)
                    .foregroundColor(.staffTextPrimary)
            }
        }
    }
}
