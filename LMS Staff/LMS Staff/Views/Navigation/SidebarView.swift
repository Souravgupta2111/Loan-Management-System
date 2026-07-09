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
    @EnvironmentObject var themeManager: AppThemeManager
    @EnvironmentObject var a11y: AccessibilityManager
    @State private var showLogoutAlert: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // User Header
            if let user = authViewModel.currentUser, let profile = authViewModel.currentStaff {
                HStack(alignment: .center) {
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
                    
                    Spacer()
                    
                    // Role Badge
                    HStack(spacing: 4) {
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

            VStack(alignment: .leading, spacing: 10) {
                // Accessibility toggles — placed above the color palette picker.
                Toggle(isOn: Binding(
                    get: { a11y.isHighContrastEnabled },
                    set: { newValue in
                        a11y.isHighContrastEnabled = newValue
                        HapticManager.shared.impact(style: .medium)
                    }
                )) {
                    HStack(spacing: StaffSpacing.sm) {
                        Image(systemName: "circle.lefthalf.filled")
                            .foregroundColor(.staffAccent)
                            .frame(width: 24)
                        Text("High Contrast")
                            .font(.staffCaption)
                            .fontWeight(.semibold)
                            .foregroundColor(.staffTextSecondary)
                    }
                }
                .tint(.staffAccent)
                .accessibilityLabel("High contrast mode")
                .accessibilityHint("Increases color contrast across the app")

                Toggle(isOn: Binding(
                    get: { a11y.isHapticsEnabled },
                    set: { newValue in
                        a11y.isHapticsEnabled = newValue
                        if newValue { HapticManager.shared.impact(style: .medium) }
                    }
                )) {
                    HStack(spacing: StaffSpacing.sm) {
                        Image(systemName: "hand.tap.fill")
                            .foregroundColor(.staffAccent)
                            .frame(width: 24)
                        Text("Haptics")
                            .font(.staffCaption)
                            .fontWeight(.semibold)
                            .foregroundColor(.staffTextSecondary)
                    }
                }
                .tint(.staffAccent)
                .accessibilityLabel("Haptic feedback")
                .accessibilityHint("Enables vibration feedback for actions")

                HStack(spacing: StaffSpacing.sm) {
                    Image(systemName: "paintpalette.fill")
                        .foregroundColor(.staffAccent)
                        .frame(width: 24)
                    Text("Color Palette")
                        .font(.staffCaption)
                        .fontWeight(.semibold)
                        .foregroundColor(.staffTextSecondary)
                    Spacer()

                    Menu {
                        ForEach(AppColorPalette.allCases) { palette in
                            Button {
                                themeManager.selectedPalette = palette
                            } label: {
                                if themeManager.selectedPalette == palette {
                                    Label(palette.title, systemImage: "checkmark")
                                } else {
                                    Text(palette.title)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(themeManager.selectedPalette.title)
                                .font(.staffCaption)
                                .fontWeight(.semibold)
                                .foregroundColor(.staffAccent)
                            Image(systemName: "chevron.down")
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(.staffTextTertiary)
                        }
                    }
                }
            }
            .padding(.horizontal, StaffSpacing.lg)
            .padding(.vertical, StaffSpacing.md)
            .background(Color.staffSurface.opacity(0.2))

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
            return [.officerDashboard, .officerPortfolio, .officerReports, .officerMessages, .officerAIChat]
            // Hidden: .officerApplications, .officerNotifications
        case .manager:
            return [.managerDashboard, .managerBranchLoans, .managerReports, .managerMessages, .managerAIChat]
            // Hidden: .managerPortfolio, .managerNpa
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
