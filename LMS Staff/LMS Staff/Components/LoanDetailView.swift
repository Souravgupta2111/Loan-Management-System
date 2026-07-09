//
//  LoanDetailView.swift
//  LMS Staff
//
//  Detailed inspector view for an active loan account.
//

import SwiftUI

struct LoanDetailView: View {
    let loanWithDetails: LoanWithDetails
    
    @StateObject private var vm: LoanDetailViewModel
    @State private var activeTab: InspectorTab = .overview
    @State private var logFilter: LogFilter = .all
    
    enum InspectorTab: String, CaseIterable {
        case overview = "Overview"
        case emi = "Repayments (EMI)"
        case payments = "Payments"
        case logs = "Audit Log"
    }
    
    enum LogFilter: String, CaseIterable, Identifiable {
        case all = "All Feed"
        case audits = "Audit Logs"
        case chats = "Chats"
        
        var id: String { rawValue }
    }
    
    init(loanWithDetails: LoanWithDetails) {
        self.loanWithDetails = loanWithDetails
        _vm = StateObject(wrappedValue: LoanDetailViewModel(loanWithDetails: loanWithDetails))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Info Bar
            HStack(spacing: StaffSpacing.lg) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(loanWithDetails.borrower.fullName)
                            .font(.staffTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.staffTextPrimary)
                        
                        StaffStatusBadge(status: vm.loanWithDetails.loan.status.displayName)
                    }
                    
                    Text("Loan No: \(vm.loanWithDetails.loan.loanNumber ?? "N/A") | Product: \(vm.loanWithDetails.product.name)")
                        .font(.staffCaption)
                        .foregroundColor(.staffTextSecondary)
                }
                
                Spacer()
                
                // Primary Application metrics
                HStack(spacing: StaffSpacing.xl) {
                    if let app = vm.application {
                        DetailMetric(label: "Asked", value: "INR \(String(format: "%.2f", app.requestedAmount))")
                    } else {
                        DetailMetric(label: "Asked", value: "INR --")
                    }
                    DetailMetric(label: "Disbursed", value: "INR \(String(format: "%.2f", vm.loanWithDetails.loan.principalAmount))")
                    DetailMetric(label: "Interest Rate", value: vm.loanWithDetails.loan.formattedRate)
                    DetailMetric(label: "Tenure", value: "\(vm.loanWithDetails.loan.tenureMonths) Months")
                    DetailMetric(label: "Outstanding", value: "INR \(String(format: "%.2f", vm.loanWithDetails.loan.outstandingPrincipal))")
                }
            }
            .padding(StaffSpacing.lg)
            .background(Color.staffSurface)
            
            // Tab Selector bar
            HStack(spacing: 0) {
                ForEach(InspectorTab.allCases, id: \.self) { tab in
                    Button(action: { activeTab = tab }) {
                        VStack(spacing: 0) {
                            Text(tab.rawValue)
                                .font(.staffBody)
                                .fontWeight(activeTab == tab ? .bold : .regular)
                                .foregroundColor(activeTab == tab ? .staffAccent : .staffTextSecondary)
                                .padding(.vertical, 12)
                            
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
            if vm.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: StaffSpacing.xl) {
                        switch activeTab {
                        case .overview:
                            overviewSection
                        case .emi:
                            emiSection
                        case .payments:
                            paymentsSection
                        case .logs:
                            logsSection
                        }
                    }
                    .padding(StaffSpacing.lg)
                }
                .background(Color.staffBackground)
            }
        }
        .task {
            await vm.loadAllDetails()
        }
        .navigationBarHidden(false)
    }
    
    // MARK: - Subviews
    
    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.lg) {
            StaffCard {
                VStack(alignment: .leading, spacing: StaffSpacing.md) {
                    Text("Loan Metadata")
                        .font(.staffTitle)
                        .foregroundColor(.staffTextPrimary)
                    
                    Divider()
                    
                    KYCRow(label: "Disbursement Date", value: vm.loanWithDetails.loan.disbursementDate ?? "N/A")
                    KYCRow(label: "First EMI Date", value: vm.loanWithDetails.loan.firstEmiDate ?? "N/A")
                    KYCRow(label: "Maturity Date", value: vm.loanWithDetails.loan.maturityDate ?? "N/A")
                    KYCRow(label: "Tenure", value: "\(vm.loanWithDetails.loan.tenureMonths) Months")
                    KYCRow(label: "Processing Fee", value: "INR \(String(format: "%.2f", vm.loanWithDetails.loan.processingFee))")
                    KYCRow(label: "Repayment Mode", value: vm.loanWithDetails.loan.repaymentMode.displayName)
                }
            }
            
            StaffCard {
                VStack(alignment: .leading, spacing: StaffSpacing.md) {
                    Text("Financial Summary")
                        .font(.staffTitle)
                        .foregroundColor(.staffTextPrimary)
                    
                    Divider()
                    
                    KYCRow(label: "Total Payable", value: "INR \(String(format: "%.2f", vm.loanWithDetails.loan.totalPayable))")
                    KYCRow(label: "Outstanding Interest", value: "INR \(String(format: "%.2f", vm.loanWithDetails.loan.outstandingInterest))")
                    KYCRow(label: "Total Overdue", value: "INR \(String(format: "%.2f", vm.loanWithDetails.loan.totalOverdue))")
                    KYCRow(label: "Overdue Days", value: "\(vm.loanWithDetails.loan.overdueDays)")
                    if let rateBreakdown = vm.loanWithDetails.loan.rateBreakdown {
                        KYCRow(label: "Rate Breakdown", value: rateBreakdown)
                    }
                }
            }
        }
    }
    
    private var emiSection: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.md) {
            Text("EMI Schedule")
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
            
            if vm.emiSchedule.isEmpty {
                Text("No EMI schedule found.")
                    .font(.staffBody)
                    .foregroundColor(.staffTextSecondary)
            } else {
                ForEach(vm.emiSchedule) { emi in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Installment \(emi.installmentNumber)")
                                .font(.staffBody)
                                .fontWeight(.bold)
                            Text("Due: \(emi.dueDate)")
                                .font(.staffCaption)
                                .foregroundColor(.staffTextSecondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("INR \(String(format: "%.2f", emi.totalEmi))")
                                .font(.staffBody)
                                .fontWeight(.medium)
                            Text("P: \(String(format: "%.2f", emi.principalComponent)) | I: \(String(format: "%.2f", emi.interestComponent))")
                                .font(.staffCaption)
                                .foregroundColor(.staffTextSecondary)
                        }
                        
                        StaffStatusBadge(status: emi.status.rawValue.capitalized)
                    }
                    .padding(StaffSpacing.md)
                    .background(Color.staffSurface)
                    .cornerRadius(StaffCorner.md)
                }
            }
        }
    }
    
    private var paymentsSection: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.md) {
            Text("Transaction History")
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
            
            if vm.payments.isEmpty {
                Text("No payments found.")
                    .font(.staffBody)
                    .foregroundColor(.staffTextSecondary)
            } else {
                ForEach(vm.payments) { payment in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("INR \(String(format: "%.2f", payment.amount))")
                                .font(.staffBody)
                                .fontWeight(.bold)
                            if let ref = payment.transactionReference {
                                Text("Ref: \(ref)")
                                    .font(.staffCaption)
                                    .foregroundColor(.staffTextSecondary)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(payment.initiatedAt?.formatted() ?? "Unknown Date")
                                .font(.staffCaption)
                                .foregroundColor(.staffTextSecondary)
                            StaffStatusBadge(status: payment.status.rawValue.capitalized)
                        }
                    }
                    .padding(StaffSpacing.md)
                    .background(Color.staffSurface)
                    .cornerRadius(StaffCorner.md)
                }
            }
        }
    }
    
    struct UnifiedTimelineItem: Identifiable, Hashable {
        let id: UUID
        let timestamp: Date
        let type: ItemType
        let title: String
        let description: String
        let actor: String
        let role: String
        let meta: String?
        
        enum ItemType: String {
            case audit = "Audit Log"
            case borrowerChat = "Borrower Chat"
            case internalChat = "Internal Chat"
            case systemChat = "System Event"
        }
    }
    
    private var timelineItems: [UnifiedTimelineItem] {
        var items: [UnifiedTimelineItem] = []
        
        // Add audit logs
        for log in vm.auditLogs {
            let desc = log.changeSummary ?? "Action: \(log.action)"
            let roleName = log.actorRole?.displayName ?? "System"
            items.append(UnifiedTimelineItem(
                id: log.id,
                timestamp: log.createdAt ?? Date(),
                type: .audit,
                title: log.action,
                description: desc,
                actor: roleName == "System" ? "System Auto" : "User (\(roleName))",
                role: roleName,
                meta: log.ipAddress != nil ? "IP: \(log.ipAddress ?? "")" : nil
            ))
        }
        
        // Add chats/messages
        let borrower = loanWithDetails.borrower
        for msg in vm.messages {
            let isBorrowerMessage = msg.senderId == borrower.id || msg.receiverId == borrower.id
            let itemType: UnifiedTimelineItem.ItemType
            let title: String
            
            if msg.messageType == .system {
                itemType = .systemChat
                title = "System Chat Notice"
            } else if isBorrowerMessage {
                itemType = .borrowerChat
                title = "Chat with Borrower"
            } else {
                itemType = .internalChat
                title = "Internal Staff Discussion"
            }
            
            // Format sender name
            let senderName: String
            let senderRole: String
            if msg.senderId == borrower.id {
                senderName = borrower.fullName
                senderRole = "Borrower"
            } else {
                senderName = "Staff Officer"
                senderRole = itemType == .internalChat ? "Internal Staff" : "Officer"
            }
            
            items.append(UnifiedTimelineItem(
                id: msg.id,
                timestamp: msg.sentAt ?? Date(),
                type: itemType,
                title: title,
                description: msg.content,
                actor: senderName,
                role: senderRole,
                meta: nil
            ))
        }
        
        let sorted = items.sorted(by: { $0.timestamp > $1.timestamp })
        
        switch logFilter {
        case .all:
            return sorted
        case .audits:
            return sorted.filter { $0.type == .audit }
        case .chats:
            return sorted.filter { $0.type == .borrowerChat || $0.type == .internalChat || $0.type == .systemChat }
        }
    }
    
    private var logsSection: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.md) {
            HStack {
                Text("Chronological Audit & Chat Feed")
                    .font(.staffTitle)
                    .foregroundColor(.staffTextPrimary)
                
                Spacer()
                
                Picker("Filter", selection: $logFilter) {
                    ForEach(LogFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(maxWidth: 300)
            }
            .padding(.bottom, 4)
            
            if timelineItems.isEmpty {
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: "Feed Empty",
                    message: "No log items found matching the selected filter."
                )
                .padding(.vertical, 40)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(timelineItems.enumerated()), id: \.element.id) { index, item in
                        HStack(alignment: .top, spacing: 12) {
                            // Left Node Column
                            VStack(spacing: 0) {
                                // Icon Node
                                ZStack {
                                    Circle()
                                        .fill(timelineIconBgColor(for: item.type))
                                        .frame(width: 32, height: 32)
                                    
                                    Image(systemName: timelineIconName(for: item.type))
                                        .font(.subheadline.weight(.bold))
                                        .foregroundColor(timelineAccentColor(for: item.type))
                                }
                                
                                // Line connecting to next
                                if index < timelineItems.count - 1 {
                                    Rectangle()
                                        .fill(Color.staffBorder)
                                        .frame(width: 2, height: 44)
                                }
                            }
                            
                            // Text Details Card
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                            .font(.staffBody)
                                            .fontWeight(.bold)
                                            .foregroundColor(timelineAccentColor(for: item.type))
                                        
                                        Text("By: \(item.actor) (\(item.role))")
                                            .font(.staffCaption)
                                            .foregroundColor(.staffTextSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(item.timestamp.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundColor(.staffTextSecondary)
                                }
                                
                                Text(item.description)
                                    .font(.staffBody)
                                    .foregroundColor(.staffTextPrimary)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(timelineContentBgColor(for: item.type))
                                    .cornerRadius(StaffCorner.sm)
                                
                                if let meta = item.meta {
                                    Text(meta)
                                        .font(.system(.caption, design: .monospaced).weight(.regular))
                                        .foregroundColor(.staffTextSecondary)
                                }
                            }
                            .padding(.bottom, index == timelineItems.count - 1 ? 0 : 16)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Timeline Design Helpers
    
    private func timelineIconName(for type: UnifiedTimelineItem.ItemType) -> String {
        switch type {
        case .audit: return "shield.fill"
        case .borrowerChat: return "bubble.left.and.bubble.right.fill"
        case .internalChat: return "lock.bubble.fill"
        case .systemChat: return "info.circle.fill"
        }
    }
    
    private func timelineAccentColor(for type: UnifiedTimelineItem.ItemType) -> Color {
        switch type {
        case .audit: return .staffAccent
        case .borrowerChat: return .staffGreen
        case .internalChat: return .staffAmber
        case .systemChat: return .secondary
        }
    }
    
    private func timelineIconBgColor(for type: UnifiedTimelineItem.ItemType) -> Color {
        switch type {
        case .audit: return .staffAccent.opacity(0.12)
        case .borrowerChat: return .staffGreen.opacity(0.12)
        case .internalChat: return .staffAmber.opacity(0.12)
        case .systemChat: return Color.gray.opacity(0.12)
        }
    }
    
    private func timelineContentBgColor(for type: UnifiedTimelineItem.ItemType) -> Color {
        switch type {
        case .audit: return Color.staffSurface
        case .borrowerChat: return Color.staffSurface
        case .internalChat: return .staffAmber.opacity(0.06)
        case .systemChat: return Color.staffSurface
        }
    }
}
