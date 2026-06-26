//
//  OverdueLoansView.swift
//  LMS Staff
//
//  Overdue Loan collection center for tracking buckets, log attempts, restructuring, and write-offs.
//

import SwiftUI

struct OverdueLoansView: View {
    @StateObject private var vm = NPAViewModel()
    @State private var selectedLoan: LoanWithDetails?
    
    // Tab bucket selection
    @State private var activeBucket: OverdueBucket = .tier30
    
    // Action sheets state
    @State private var showRestructureSheet: Bool = false
    @State private var showWriteOffSheet: Bool = false
    @State private var showEscalateSheet: Bool = false
    @State private var showContactHistorySheet: Bool = false
    
    // Form fields
    @State private var restructureRate: Double = 12.0
    @State private var restructureTenure: Int = 12
    @State private var waivedPenalty: Double = 0.0
    @State private var remarksText: String = ""
    
    // Contact attempts log
    @State private var contactHistoryLogs: [String] = [
        "2026-06-10: Left message on voicemail. No response.",
        "2026-06-15: Spoke to borrower. Promised to clear overdue EMI by next week."
    ]
    @State private var newContactAttemptText: String = ""
    
    enum OverdueBucket: String, CaseIterable {
        case tier30 = "30-59 Days"
        case tier60 = "60-89 Days"
        case tier90 = "90+ Days (NPA)"
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left list of bucket items
            VStack(alignment: .leading, spacing: 0) {
                Text("NPA Recovery Hub")
                    .font(.staffTitle)
                    .foregroundColor(.staffTextPrimary)
                    .padding(.horizontal, StaffSpacing.lg)
                    .padding(.top, StaffSpacing.lg)
                
                // Bucket selectors
                HStack(spacing: 0) {
                    ForEach(OverdueBucket.allCases, id: \.self) { bucket in
                        Button(action: { activeBucket = bucket }) {
                            VStack(spacing: 6) {
                                Text(bucket.rawValue)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(activeBucket == bucket ? .staffAccent : .staffTextSecondary)
                                Rectangle()
                                    .fill(activeBucket == bucket ? Color.staffAccent : Color.clear)
                                    .frame(height: 2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, StaffSpacing.md)
                
                Divider()
                    .background(Color.staffBorder)
                
                // Render selected bucket list
                let list = bucketList(activeBucket)
                
                if vm.isLoading {
                    Spacer()
                    ProgressView()
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else if list.isEmpty {
                    Spacer()
                    EmptyStateView(
                        icon: "checkmark.shield.fill",
                        title: "Bucket Clean",
                        message: "No delinquent loans fall in this overdue duration bucket."
                    )
                    Spacer()
                } else {
                    List(list, selection: $selectedLoan) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.loan.loanNumber ?? "LMS-XXXX")
                                    .font(.staffBody)
                                    .fontWeight(.bold)
                                    .foregroundColor(.staffTextPrimary)
                                Spacer()
                                Text("\(item.loan.overdueDays) Days")
                                    .font(.staffCaption)
                                    .foregroundColor(.staffRed)
                            }
                            
                            HStack {
                                Text(item.borrower.fullName)
                                    .font(.staffCaption)
                                    .foregroundColor(.staffTextSecondary)
                                Spacer()
                                Text("O/S: INR \(String(format: "%.0f", item.loan.outstandingPrincipal))")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.staffTextPrimary)
                            }
                        }
                        .padding(.vertical, 4)
                        .tag(item)
                        .listRowBackground(Color.staffSurface)
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden)
                    .background(Color.staffBackground)
                }
            }
            .frame(width: 320)
            .background(Color.staffBackground)
            
            Divider()
                .background(Color.staffBorder)
            
            // Right detailed recovery panel
            if let loanWithDetails = selectedLoan {
                recoveryInspectorSection(loanWithDetails)
            } else {
                VStack(spacing: StaffSpacing.md) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.staffTextSecondary.opacity(0.3))
                    Text("Select Delinquent Account to Inspect Recovery Actions")
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
                await vm.loadOverdueAccounts()
            }
        }
        .sheet(isPresented: $showRestructureSheet) {
            restructureSheet
        }
        .sheet(isPresented: $showWriteOffSheet) {
            writeOffSheet
        }
        .sheet(isPresented: $showEscalateSheet) {
            escalateSheet
        }
        .sheet(isPresented: $showContactHistorySheet) {
            contactLogsSheet
        }
    }
    
    // MARK: - Recovery Inspector Panel
    
    @ViewBuilder
    private func recoveryInspectorSection(_ item: LoanWithDetails) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.borrower.fullName)
                        .font(.staffTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.staffTextPrimary)
                    Text("Account No: \(item.loan.loanNumber ?? "LMS-XXXX") | Overdue Days: \(item.loan.overdueDays)")
                        .font(.staffCaption)
                        .foregroundColor(.staffTextSecondary)
                }
                
                Spacer()
                
                StaffStatusBadge(status: item.loan.status.displayName)
            }
            .padding(StaffSpacing.lg)
            .background(Color.staffSurface)
            
            ScrollView {
                VStack(alignment: .leading, spacing: StaffSpacing.lg) {
                    // Summary particulars
                    HStack(spacing: StaffSpacing.lg) {
                        StaffCard {
                            VStack(alignment: .leading, spacing: StaffSpacing.md) {
                                Text("Balance Breakdown")
                                    .font(.staffTitle)
                                    .foregroundColor(.staffTextPrimary)
                                
                                Divider()
                                
                                InfoRow(label: "Outstanding Principal", value: "INR \(String(format: "%.2f", item.loan.outstandingPrincipal))")
                                InfoRow(label: "Outstanding Interest", value: "INR \(String(format: "%.2f", item.loan.outstandingInterest))")
                                InfoRow(label: "Accrued Penalty Due", value: "INR \(String(format: "%.2f", item.loan.totalOverdue))", isUrgent: true)
                            }
                        }
                        
                        StaffCard {
                            VStack(alignment: .leading, spacing: StaffSpacing.md) {
                                Text("Delinquency Metrics")
                                    .font(.staffTitle)
                                    .foregroundColor(.staffTextPrimary)
                                
                                Divider()
                                
                                InfoRow(label: "Overdue Days Count", value: "\(item.loan.overdueDays) Days", isUrgent: true)
                                InfoRow(label: "Active Restructured", value: item.loan.status == .restructured ? "YES" : "NO")
                                InfoRow(label: "Maturity Ending Date", value: item.loan.maturityDate ?? "N/A")
                            }
                        }
                    }
                    
                    // Contact attempts card
                    StaffCard {
                        VStack(alignment: .leading, spacing: StaffSpacing.md) {
                            HStack {
                                Text("Contact Collection History")
                                    .font(.staffTitle)
                                    .foregroundColor(.staffTextPrimary)
                                Spacer()
                                Button("Log Attempt") { showContactHistorySheet = true }
                                    .font(.staffCaption)
                                    .foregroundColor(.staffAccent)
                            }
                            
                            Divider()
                            
                            ForEach(contactHistoryLogs, id: \.self) { log in
                                Text(log)
                                    .font(.staffCaption)
                                    .foregroundColor(.staffTextPrimary)
                                    .padding(.vertical, 2)
                            }
                        }
                    }
                }
                .padding(StaffSpacing.lg)
            }
            
            Divider()
                .background(Color.staffBorder)
            
            // Recovery action buttons footer
            HStack(spacing: StaffSpacing.md) {
                StaffButton(title: "Escalate to Admin", style: .outline, icon: "arrow.up.circle") {
                    showEscalateSheet = true
                }
                
                StaffButton(title: "Restructure Loan", style: .outline, icon: "arrow.triangle.2.circlepath") {
                    restructureRate = item.loan.interestRate
                    restructureTenure = item.loan.tenureMonths
                    waivedPenalty = item.loan.totalOverdue
                    showRestructureSheet = true
                }
                
                Spacer()
                
                StaffButton(title: "Permanent Write-Off", style: .destructive, icon: "xmark.bin.fill") {
                    showWriteOffSheet = true
                }
                .frame(width: 240)
            }
            .padding(StaffSpacing.lg)
            .background(Color.staffSurface)
        }
        .onChange(of: item) { _ in
            contactHistoryLogs = [
                "2026-06-10: Left message on voicemail. No response.",
                "2026-06-15: Spoke to borrower. Promised to clear overdue EMI by next week."
            ]
        }
    }
    
    // MARK: - Action Sheets
    
    private var restructureSheet: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.lg) {
            Text("Restructure Overdue Terms")
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
            
            if let item = selectedLoan {
                VStack(alignment: .leading, spacing: StaffSpacing.md) {
                    Text("Waive Accumulated Penalty: INR \(String(format: "%.2f", waivedPenalty))")
                        .font(.staffBody)
                    Slider(value: $waivedPenalty, in: 0...item.loan.totalOverdue, step: 100)
                    
                    Text("Revised Interest Rate: \(String(format: "%.2f", restructureRate))%")
                        .font(.staffBody)
                    Slider(value: $restructureRate, in: 5...25, step: 0.25)
                    
                    Text("Extend Tenure Months: \(restructureTenure) Months")
                        .font(.staffBody)
                    Stepper("\(restructureTenure) Months", value: $restructureTenure, in: 6...120)
                    
                    TextField("Enter restructuring reason justification...", text: $remarksText)
                        .padding(12)
                        .background(Color.staffSurface)
                        .cornerRadius(StaffCorner.md)
                        .foregroundColor(.staffTextPrimary)
                }
                .padding()
                .background(Color.staffSurface)
                .cornerRadius(StaffCorner.md)
            }
            
            HStack {
                Button("Cancel") { showRestructureSheet = false }
                    .foregroundColor(.staffTextSecondary)
                Spacer()
                Button("Apply Restructure") {
                    if let loan = selectedLoan?.loan {
                        Task {
                            if await vm.restructureLoan(loan: loan, revisedRate: restructureRate, revisedTenure: restructureTenure, waivedPenalty: waivedPenalty, reason: remarksText) {
                                showRestructureSheet = false
                                remarksText = ""
                                selectedLoan = nil
                            }
                        }
                    }
                }
                .foregroundColor(.staffAccent)
                .fontWeight(.bold)
                .disabled(remarksText.isEmpty)
            }
        }
        .padding(30)
        .background(Color.staffBackground.ignoresSafeArea())
    }
    
    private var writeOffSheet: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.lg) {
            Text("Irreversibly Write-Off Balance")
                .font(.staffTitle)
                .foregroundColor(.staffRed)
            
            Text("WARNING: Writing off this account is permanent and irreversible. All outstanding principal and interest balances will be cleared to zero (0) and marked as loss in system reports.")
                .font(.staffCaption)
                .foregroundColor(.staffRed)
            
            TextField("Mandatory reason remarks for credit audit...", text: $remarksText)
                .padding(12)
                .background(Color.staffSurface)
                .cornerRadius(StaffCorner.md)
                .foregroundColor(.staffTextPrimary)
            
            HStack {
                Button("Cancel") { showWriteOffSheet = false }
                    .foregroundColor(.staffTextSecondary)
                Spacer()
                Button("Permanently Write-Off") {
                    if let loan = selectedLoan?.loan {
                        Task {
                            if await vm.writeOffLoan(loan: loan, reason: remarksText) {
                                showWriteOffSheet = false
                                remarksText = ""
                                selectedLoan = nil
                            }
                        }
                    }
                }
                .foregroundColor(.staffRed)
                .fontWeight(.bold)
                .disabled(remarksText.isEmpty)
            }
        }
        .padding(30)
        .background(Color.staffBackground.ignoresSafeArea())
    }
    
    private var escalateSheet: some View {
        VStack(spacing: StaffSpacing.lg) {
            Text("Escalate Loan Recovery")
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
            
            Text("Enter reason for escalating recovery steps directly to system administrators:")
                .font(.staffCaption)
                .foregroundColor(.staffTextSecondary)
            
            TextEditor(text: $remarksText)
                .frame(height: 120)
                .padding(8)
                .background(Color.staffSurface)
                .cornerRadius(StaffCorner.md)
                .foregroundColor(.staffTextPrimary)
            
            HStack {
                Button("Cancel") { showEscalateSheet = false }
                    .foregroundColor(.staffTextSecondary)
                Spacer()
                Button("Send Escalation Alert") {
                    if let loan = selectedLoan?.loan {
                        Task {
                            if await vm.escalateLoan(loan: loan, reason: remarksText) {
                                showEscalateSheet = false
                                remarksText = ""
                            }
                        }
                    }
                }
                .foregroundColor(.staffAccent)
                .fontWeight(.bold)
                .disabled(remarksText.isEmpty)
            }
        }
        .padding(30)
        .background(Color.staffBackground.ignoresSafeArea())
    }
    
    private var contactLogsSheet: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.lg) {
            Text("Log Contact Attempt")
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
            
            TextField("Enter call/visit details summary...", text: $newContactAttemptText)
                .padding(12)
                .background(Color.staffSurface)
                .cornerRadius(StaffCorner.md)
                .foregroundColor(.staffTextPrimary)
            
            HStack {
                Button("Cancel") { showContactHistorySheet = false }
                    .foregroundColor(.staffTextSecondary)
                Spacer()
                Button("Save Log") {
                    let now = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
                    contactHistoryLogs.append("\(now): \(newContactAttemptText)")
                    newContactAttemptText = ""
                    showContactHistorySheet = false
                }
                .foregroundColor(.staffAccent)
                .fontWeight(.bold)
                .disabled(newContactAttemptText.isEmpty)
            }
        }
        .padding(30)
        .background(Color.staffBackground.ignoresSafeArea())
    }
    
    // MARK: - Helpers
    
    private func bucketList(_ bucket: OverdueBucket) -> [LoanWithDetails] {
        switch bucket {
        case .tier30:
            return vm.tier30To59
        case .tier60:
            return vm.tier60To89
        case .tier90:
            return vm.tier90PlusNPA
        }
    }
}
