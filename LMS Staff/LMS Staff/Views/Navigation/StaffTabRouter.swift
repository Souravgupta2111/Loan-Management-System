//
//  StaffTabRouter.swift
//  LMS Staff
//
//  Main navigation router mapping sidebar selection to role-specific detailed views.
//

import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case officerDashboard
    case officerApplications
    case officerPortfolio
    case officerMessages
    case officerNotifications
    case officerAIChat
    
    case managerDashboard
    case managerBranchLoans
    case managerPortfolio
    case managerNpa
    case managerReports
    case managerMessages
    case managerAI
    case managerAIChat
    
    case adminDashboard
    case adminStaff
    case adminBranches
    case adminProducts
    case adminBorrowers
    case adminAudit
    case adminNotifications
    case adminChecklist
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .officerDashboard: return "Dashboard"
        case .officerApplications: return "My Applications"
        case .officerPortfolio: return "Active Loans"
        case .officerMessages: return "Chats"
        case .officerNotifications: return "Alert Notifications"
        case .officerAIChat: return "AI Assistant"
        
        case .managerDashboard: return "Overview Dashboard"
        case .managerBranchLoans: return "Branch Loans"
        case .managerPortfolio: return "Portfolio Analytics"
        case .managerNpa: return "NPA & Recoveries"
        case .managerReports: return "Reports"
        case .managerMessages: return "Chats"
        case .managerAI: return "AI Analytics"
        case .managerAIChat: return "AI Assistant"
        
        case .adminDashboard: return "System Overview"
        case .adminStaff: return "Staff Accounts"
        case .adminBranches: return "Branch Management"
        case .adminProducts: return "Loan Catalog"
        case .adminBorrowers: return "Borrower Database"
        case .adminAudit: return "Audit Trail Log"
        case .adminNotifications: return "Alert Templates"
        case .adminChecklist: return "File Checklists"
        }
    }
    
    var icon: String {
        switch self {
        case .officerDashboard, .managerDashboard, .adminDashboard:
            return "square.grid.2x2.fill"
        case .officerApplications:
            return "doc.on.doc.fill"
        case .officerPortfolio:
            return "briefcase.fill"
        case .officerMessages, .managerMessages:
            return "bubble.left.and.bubble.right.fill"
        case .managerAI:
            return "chart.bar.xaxis"
        case .officerAIChat, .managerAIChat:
            return "sparkles"
        case .officerNotifications:
            return "bell.fill"
            
        case .managerBranchLoans:
            return "building.2.crop.circle"
        case .managerPortfolio:
            return "chart.pie.fill"
        case .managerNpa:
            return "exclamationmark.triangle.fill"
        case .managerReports:
            return "chart.bar.doc.horizontal.fill"
            
        case .adminStaff:
            return "person.3.fill"
        case .adminBranches:
            return "building.2.fill"
        case .adminProducts:
            return "scroll.fill"
        case .adminBorrowers:
            return "person.text.rectangle.fill"
        case .adminAudit:
            return "clock.arrow.circlepath"
        case .adminNotifications:
            return "envelope.fill"
        case .adminChecklist:
            return "checkmark.square.fill"
        }
    }
}

struct StaffTabRouter: View {
    let role: UserRole
    @State private var selectedItem: SidebarItem?
    
    var body: some View {
        NavigationSplitView {
            SidebarView(role: role, selectedItem: $selectedItem)
                .navigationTitle("LMS Portal")
        } detail: {
            if let item = selectedItem {
                detailView(for: item)
            } else {
                VStack(spacing: StaffSpacing.md) {
                    Image(systemName: "building.columns.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.staffTextSecondary.opacity(0.3))
                    Text("Select a Workspace Item")
                        .font(.staffTitle)
                        .foregroundColor(.staffTextSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.staffBackground)
            }
        }
        .accentColor(.staffAccent)
        .onAppear {
            Task {
                try? await NotificationService.shared.requestPermission()
            }
            NotificationService.shared.subscribeToNotifications()
        }
        .onDisappear {
            NotificationService.shared.unsubscribe()
        }
    }
    
    @ViewBuilder
    private func detailView(for item: SidebarItem) -> some View {
        switch item {
        // MARK: - Officer Views
        case .officerDashboard:
            OfficerDashboardView()
        case .officerApplications:
            OfficerDashboardView(preselectedFilter: "Under Review")
        case .officerPortfolio:
            ActivePortfolioView()
        case .officerMessages:
            OfficerMessagesView()
        case .officerNotifications:
            OfficerNotificationsView()
        case .officerAIChat:
            StaffAIChatView()
            
        // MARK: - Manager Views
        case .managerDashboard:
            ManagerDashboardView()
        case .managerBranchLoans:
            BranchLoansView()
        case .managerPortfolio:
            PortfolioDashboardView()
        case .managerNpa:
            OverdueLoansView()
        case .managerReports:
            ReportsView()
        case .managerMessages:
            ManagerMessagesView()
        case .managerAI:
            AIAnalyticsView()
        case .managerAIChat:
            StaffAIChatView()
            
        // MARK: - Admin Views
        case .adminDashboard:
            AdminDashboardView()
        case .adminStaff:
            StaffManagementView()
        case .adminBranches:
            BranchManagementView()
        case .adminProducts:
            LoanProductListView()
        case .adminBorrowers:
            BorrowerSearchView()
        case .adminAudit:
            AuditTrailView()
        case .adminNotifications:
            NotificationTemplatesView()
        case .adminChecklist:
            DocumentChecklistView()
        }
    }
}
