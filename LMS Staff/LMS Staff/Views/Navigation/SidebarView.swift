//
//  SidebarView.swift
//  LMS Staff
//
//  iPad navigation sidebar with role-specific menu options and user info header.
//

import SwiftUI

struct SidebarView: View {
    let role: UserRole
    @Binding var selectedItem: SidebarItem?
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showLogoutAlert: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // User Header
            if let user = authViewModel.currentUser, let profile = authViewModel.currentStaff {
                VStack(alignment: .leading, spacing: StaffSpacing.xs) {
                    HStack(spacing: StaffSpacing.md) {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 48, height: 48)
                            .foregroundColor(.staffAccent)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.fullName)
                                .font(.staffBody)
                                .fontWeight(.bold)
                                .foregroundColor(.staffTextPrimary)
                            
                            Text(profile.employeeId)
                                .font(.staffCaption)
                                .foregroundColor(.staffTextSecondary)
                        }
                    }
                    .padding(.bottom, StaffSpacing.xs)
                    
                    // Role Badge
                    HStack {
                        Image(systemName: roleIcon(role))
                        Text(role.displayName)
                    }
                    .font(.caption.weight(.bold))
                    .foregroundColor(roleColor(role))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(roleColor(role).opacity(0.15))
                    .cornerRadius(StaffCorner.sm)
                }
                .padding(StaffSpacing.lg)
                .background(Color.staffSurface.opacity(0.3))
            }
            
            Divider()
                .background(Color.staffBorder)
                .padding(.bottom, 12)
            
            // Menu Items List
            List(menuItems(for: role), id: \.self, selection: $selectedItem) { item in
                NavigationLink(value: item) {
                    HStack(spacing: StaffSpacing.md) {
                        Image(systemName: item.icon)
                            .foregroundColor(selectedItem == item ? .staffAccent : .staffTextSecondary)
                            .frame(width: 24)
                        
                        Text(item.title)
                            .font(.staffBody)
                            .foregroundColor(selectedItem == item ? .staffTextPrimary : .staffTextSecondary)
                    }
                    .padding(.vertical, 6)
                }
            }
            .listStyle(SidebarListStyle())
            
            Spacer()
            
            Divider()
                .background(Color.staffBorder)
            
            // Footer: Logout
            Button(action: {
                showLogoutAlert = true
            }) {
                HStack(spacing: StaffSpacing.md) {
                    Image(systemName: "power")
                        .foregroundColor(.staffRed)
                    Text("Log Out")
                        .font(.staffBody)
                        .fontWeight(.medium)
                        .foregroundColor(.staffTextPrimary)
                }
                .padding(StaffSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.staffSurface.opacity(0.2))
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.staffSurface.ignoresSafeArea())
        .onAppear {
            // Auto-select first item
            if selectedItem == nil {
                selectedItem = menuItems(for: role).first
            }
        }
        .alert(isPresented: $showLogoutAlert) {
            Alert(
                title: Text("Confirm Log Out"),
                message: Text("Are you sure you want to end your active session?"),
                primaryButton: .destructive(Text("Log Out")) {
                    Task {
                        await authViewModel.logout()
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func menuItems(for role: UserRole) -> [SidebarItem] {
        switch role {
        case .officer:
            return [.officerDashboard, .officerPortfolio, .officerMessages, .officerAIChat]
            // Hidden: .officerApplications, .officerNotifications
        case .manager:
            return [.managerDashboard, .managerBranchLoans, .managerReports, .managerAI, .managerAIChat]
            // Hidden: .managerPortfolio, .managerNpa, .managerReports
        case .admin:
            return [.adminDashboard, .adminStaff, .adminBranches, .adminProducts, .adminNotifications, .adminAudit, .adminChecklist]
            // Hidden: .adminBorrowers
        case .borrower:
            return []
        }
    }
    
    private func roleIcon(_ role: UserRole) -> String {
        switch role {
        case .admin: return "shield.fill"
        case .manager: return "briefcase.fill"
        case .officer: return "doc.text.magnifyingglass"
        case .borrower: return "person.fill"
        }
    }
    
    private func roleColor(_ role: UserRole) -> Color {
        switch role {
        case .admin: return .staffGreen
        case .manager: return .staffAccent
        case .officer: return .staffAmber
        case .borrower: return .staffTextSecondary
        }
    }
}
