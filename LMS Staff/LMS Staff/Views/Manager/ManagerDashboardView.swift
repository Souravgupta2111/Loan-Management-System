//
//  ManagerDashboardView.swift
//  LMS Staff
//
//  Manager Dashboard for reviewing recommendations, checking KPIs, and managing approvals.
//

import SwiftUI

enum ManagerDashboardMode {
    case standard
    case recommendations
}

struct ManagerDashboardView: View {
    var preselectedView: ManagerDashboardMode = .standard
    
    @StateObject private var vm = ManagerDashboardViewModel()
    @State private var selectedApp: ApplicationWithBorrower?
    
    // Approval terms state
    @State private var showApprovalSheet: Bool = false
    @State private var approvedAmount: Double = 0.0
    @State private var approvedTenure: Int = 12
    @State private var approvedRate: Double = 10.0
    
    // Reject & Send back modals
    @State private var showRejectSheet: Bool = false
    @State private var showSendBackSheet: Bool = false
    @State private var showReassignSheet: Bool = false
    @State private var selectedOfficerId: UUID? = nil
    @State private var remarks: String = ""
    
    var body: some View {
        HStack(spacing: 0) {
            // Left column: Queue list and metrics
            VStack(alignment: .leading, spacing: 0) {
                Text("Manager Console")
                    .font(.staffTitle)
                    .foregroundColor(.staffTextPrimary)
                    .padding(.horizontal, StaffSpacing.lg)
                    .padding(.top, StaffSpacing.lg)
                
                // KPI summary widgets
                VStack(spacing: StaffSpacing.sm) {
                    HStack(spacing: StaffSpacing.sm) {
                        MiniStatCard(title: "Active Portfolio", value: "INR \(String(format: "%.0f", vm.totalDisbursed))", icon: "briefcase.fill", color: .staffAccent)
                        MiniStatCard(title: "Active Loans", value: "\(vm.activeLoansCount)", icon: "person.2.fill", color: .staffAmber)
                    }
                    HStack(spacing: StaffSpacing.sm) {
                        MiniStatCard(title: "Collection Eff.", value: String(format: "%.1f%%", vm.collectionEfficiency), icon: "chart.bar.fill", color: .staffGreen)
                        MiniStatCard(title: "NPA Ratio", value: String(format: "%.1f%%", vm.npaRatio), icon: "exclamationmark.triangle.fill", color: .staffRed)
                    }
                }
                .padding(StaffSpacing.lg)
                
                Text("Recommended Queue")
                    .font(.staffBody)
                    .fontWeight(.bold)
                    .foregroundColor(.staffTextSecondary)
                    .padding(.horizontal, StaffSpacing.lg)
                    .padding(.bottom, StaffSpacing.xs)
                
                Divider()
                    .background(Color.staffBorder)
                
                if vm.isLoading {
                    Spacer()
                    ProgressView()
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else if vm.recommendedApplications.isEmpty {
                    Spacer()
                    EmptyStateView(
                        icon: "checkmark.shield",
                        title: "Queue Clean",
                        message: "No applications are currently awaiting manager approval."
                    )
                    Spacer()
                } else {
                    List(vm.recommendedApplications, selection: $selectedApp) { app in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(app.borrower.fullName)
                                    .font(.staffBody)
                                    .fontWeight(.bold)
                                    .foregroundColor(.staffTextPrimary)
                                Spacer()
                                Text("INR \(String(format: "%.0f", app.application.requestedAmount))")
                                    .font(.staffCaption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.staffAccent)
                            }
                            
                            HStack {
                                Text(app.application.applicationNumber ?? "APP-NEW")
                                    .font(.staffCaption)
                                    .foregroundColor(.staffTextSecondary)
                                Spacer()
                                Text("Tenure: \(app.application.requestedTenureMonths)m")
                                    .font(.system(size: 10))
                                    .foregroundColor(.staffTextSecondary)
                            }
                        }
                        .padding(.vertical, 6)
                        .tag(app)
                        .listRowBackground(Color.staffSurface)
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden)
                    .background(Color.staffBackground)
                }
            }
            .frame(width: 360)
            .background(Color.staffBackground)
            
            Divider()
                .background(Color.staffBorder)
            
            // Right column: Detailed decision pane
            if let app = selectedApp {
                recommendationInspectorSection(app)
            } else {
                VStack(spacing: StaffSpacing.md) {
                    Image(systemName: "hand.thumbsup.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.staffTextSecondary.opacity(0.3))
                    Text("Select a Recommended Application")
                        .font(.staffTitle)
                        .foregroundColor(.staffTextSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.staffSurface.opacity(0.1))
            }
        }
        .background(Color.staffBackground)
        .onAppear {
            Task {
                await vm.loadDashboard()
            }
        }
        .sheet(isPresented: $showApprovalSheet) {
            approvalTermsSheet
        }
        .sheet(isPresented: $showRejectSheet) {
            rejectionRemarksSheet
        }
        .sheet(isPresented: $showSendBackSheet) {
            sendBackRemarksSheet
        }
        .sheet(isPresented: $showReassignSheet) {
            reassignOfficerSheet
        }
    }
    
    // MARK: - Inspection Panel Subviews
    
    @ViewBuilder
    private func recommendationInspectorSection(_ item: ApplicationWithBorrower) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.borrower.fullName)
                        .font(.staffTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.staffTextPrimary)
                    Text("App Number: \(item.application.applicationNumber ?? "N/A") | Product: \(item.product.name)")
                        .font(.staffCaption)
                        .foregroundColor(.staffTextSecondary)
                }
                Spacer()
            }
            .padding(StaffSpacing.lg)
            .background(Color.staffSurface)
            
            ScrollView {
                VStack(alignment: .leading, spacing: StaffSpacing.lg) {
                    // Application particulars
                    StaffCard {
                        VStack(alignment: .leading, spacing: StaffSpacing.md) {
                            Text("Proposal Particulars")
                                .font(.staffTitle)
                                .foregroundColor(.staffTextPrimary)
                            
                            Divider()
                            
                            KYCRow(label: "Requested Amount", value: "INR \(String(format: "%.2f", item.application.requestedAmount))")
                            KYCRow(label: "Requested Tenure", value: "\(item.application.requestedTenureMonths) Months")
                            KYCRow(label: "Purpose", value: item.application.purpose ?? "N/A")
                            KYCRow(label: "Borrower Monthly Income", value: item.profile?.monthlyIncome != nil ? "INR \(String(format: "%.2f", item.profile!.monthlyIncome!))" : "N/A")
                            KYCRow(label: "Borrower Credit Score", value: item.profile?.creditScore != nil ? "\(item.profile!.creditScore!)" : "N/A")
                        }
                    }
                    
                    // Product specifics guidelines
                    StaffCard {
                        VStack(alignment: .leading, spacing: StaffSpacing.md) {
                            Text("Loan Product Constraints")
                                .font(.staffTitle)
                                .foregroundColor(.staffTextPrimary)
                            
                            Divider()
                            
                            KYCRow(label: "Rate Limits", value: item.product.formattedRateRange)
                            KYCRow(label: "Tenure limits", value: item.product.formattedTenureRange)
                            KYCRow(label: "Processing Fee Pct", value: "\(item.product.processingFeePct)%")
                        }
                    }
                }
                .padding(StaffSpacing.lg)
            }
            
            Divider()
                .background(Color.staffBorder)
            
            // Bottom Action Bar
            HStack(spacing: StaffSpacing.md) {
                StaffButton(title: "Reassign", style: .outline, icon: "person.badge.plus") {
                    showReassignSheet = true
                }
                
                StaffButton(title: "Send Back", style: .outline, icon: "arrow.uturn.left") {
                    showSendBackSheet = true
                }
                
                StaffButton(title: "Reject", style: .destructive, icon: "xmark.circle") {
                    showRejectSheet = true
                }
                
                Spacer()
                
                StaffButton(title: "Verify & Approve", style: .success, icon: "checkmark.seal.fill") {
                    // Prepopulate sliders
                    approvedAmount = item.application.requestedAmount
                    approvedTenure = item.application.requestedTenureMonths
                    approvedRate = item.product.minInterestRate
                    showApprovalSheet = true
                }
                .frame(width: 240)
            }
            .padding(StaffSpacing.lg)
            .background(Color.staffSurface)
        }
    }
    
    // MARK: - Action Sheets
    
    private var approvalTermsSheet: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.lg) {
            Text("Sanction Terms Configuration")
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
            
            if let item = selectedApp {
                VStack(alignment: .leading, spacing: StaffSpacing.md) {
                    Text("Approved Amount: INR \(String(format: "%.2f", approvedAmount))")
                        .font(.staffBody)
                        .foregroundColor(.staffTextPrimary)
                    Slider(value: $approvedAmount, in: item.product.minAmount...item.product.maxAmount, step: 10000)
                    
                    Text("Approved Tenure: \(approvedTenure) Months")
                        .font(.staffBody)
                        .foregroundColor(.staffTextPrimary)
                    Stepper("\(approvedTenure) Months", value: $approvedTenure, in: item.product.minTenureMonths...item.product.maxTenureMonths, step: 1)
                    
                    Text("Approved Interest Rate: \(String(format: "%.2f", approvedRate))% Per Annum")
                        .font(.staffBody)
                        .foregroundColor(.staffTextPrimary)
                    Slider(value: $approvedRate, in: item.product.minInterestRate...item.product.maxInterestRate, step: 0.25)
                }
                .padding()
                .background(Color.staffSurface)
                .cornerRadius(StaffCorner.md)
            }
            
            HStack {
                Button("Cancel") { showApprovalSheet = false }
                    .foregroundColor(.staffTextSecondary)
                Spacer()
                Button("Sanction Approval") {
                    if let app = selectedApp?.application {
                        Task {
                            if await vm.approveApplication(applicationId: app.id, approvedAmount: approvedAmount, tenureMonths: approvedTenure, interestRate: approvedRate) {
                                showApprovalSheet = false
                                selectedApp = nil
                            }
                        }
                    }
                }
                .foregroundColor(.staffGreen)
                .fontWeight(.bold)
            }
        }
        .padding(30)
        .background(Color.staffBackground.ignoresSafeArea())
    }
    
    private var rejectionRemarksSheet: some View {
        VStack(spacing: StaffSpacing.lg) {
            Text("Rejection Reason")
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
                Button("Reject Proposal") {
                    if let app = selectedApp?.application {
                        Task {
                            if await vm.rejectApplication(applicationId: app.id, reason: remarks) {
                                showRejectSheet = false
                                remarks = ""
                                selectedApp = nil
                            }
                        }
                    }
                }
                .foregroundColor(.staffRed)
                .fontWeight(.bold)
                .disabled(remarks.isEmpty)
            }
        }
        .padding(30)
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
                Button("Send Back to Officer") {
                    if let app = selectedApp?.application {
                        Task {
                            if await vm.sendBackApplication(applicationId: app.id, remarks: remarks) {
                                showSendBackSheet = false
                                remarks = ""
                                selectedApp = nil
                            }
                        }
                    }
                }
                .foregroundColor(.staffAmber)
                .fontWeight(.bold)
                .disabled(remarks.isEmpty)
            }
        }
        .padding(30)
        .background(Color.staffBackground.ignoresSafeArea())
    }
    
    private var reassignOfficerSheet: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.lg) {
            Text("Reassign Officer")
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
            
            Text("Select an officer to handle this application instead of the current one.")
                .font(.staffCaption)
                .foregroundColor(.staffTextSecondary)
            
            List(vm.availableOfficers, selection: $selectedOfficerId) { staffWithUser in
                HStack {
                    Text(staffWithUser.staff.employeeId)
                        .font(.staffCaption)
                        .foregroundColor(.staffTextSecondary)
                        .frame(width: 80, alignment: .leading)
                    
                    Text(staffWithUser.user.fullName)
                        .font(.staffBody)
                        .foregroundColor(.staffTextPrimary)
                        
                    Spacer()
                    
                    if selectedOfficerId == staffWithUser.user.id {
                        Image(systemName: "checkmark")
                            .foregroundColor(.staffAccent)
                    }
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedOfficerId = staffWithUser.user.id
                }
                .listRowBackground(Color.staffSurface)
            }
            .listStyle(PlainListStyle())
            .frame(height: 250)
            .background(Color.staffSurface)
            .cornerRadius(StaffCorner.md)
            
            HStack {
                Button("Cancel") { showReassignSheet = false }
                    .foregroundColor(.staffTextSecondary)
                Spacer()
                Button("Reassign Application") {
                    if let app = selectedApp?.application, let newOfficerId = selectedOfficerId {
                        Task {
                            if await vm.reassignOfficer(applicationId: app.id, newOfficerId: newOfficerId) {
                                showReassignSheet = false
                                selectedOfficerId = nil
                                selectedApp = nil
                            }
                        }
                    }
                }
                .foregroundColor(.staffAccent)
                .fontWeight(.bold)
                .disabled(selectedOfficerId == nil)
            }
        }
        .padding(30)
        .background(Color.staffBackground.ignoresSafeArea())
    }
}
