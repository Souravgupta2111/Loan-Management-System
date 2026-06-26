import SwiftUI

/// Main Tab View — tab bar is a pinned VStack row at the bottom,
/// NOT a floating ZStack overlay. This ensures NavigationLink
/// destinations (like SelectLoanTypeView) have their content
/// naturally bounded above the bar — no button overlap.
struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedTab: TabType = .home

    enum TabType: CaseIterable {
        case home, loans, schedule

        var label: String {
            switch self {
            case .home:     return "Home"
            case .loans:    return "My Loans"
            case .schedule: return "Schedule"
            }
        }

        var icon: String {
            switch self {
            case .home:     return "house"
            case .loans:    return "indianrupeesign.circle"
            case .schedule: return "calendar"
            }
        }

        var activeIcon: String {
            switch self {
            case .home:     return "house.fill"
            case .loans:    return "indianrupeesign.circle.fill"
            case .schedule: return "calendar"
            }
        }
    }

    var body: some View {
        // VStack — NOT ZStack — so the tab bar sits below the content,
        // never overlapping NavigationLink destinations.
        VStack(spacing: 0) {
            // Tab content fills all remaining space
            Group {
                switch selectedTab {
                case .home:
                    HomeDashboardView()
                        .environmentObject(authViewModel)
                case .loans:
                    LoansListView()
                        .environmentObject(authViewModel)
                case .schedule:
                    ScheduleOverviewView()
                        .environmentObject(authViewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Tab bar — pinned below content, above safe area
            tabBar
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear  { NotificationService.shared.subscribeToNotifications() }
        .onDisappear { NotificationService.shared.unsubscribe() }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(TabType.allCases, id: \.label) { tab in
                tabButton(tab)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 28) // accounts for home indicator
        .background(Color.white)
        .overlay(
            Rectangle()
                .fill(Color(hex: "#89DBA6").opacity(0.30))
                .frame(height: 1),
            alignment: .top
        )
    }

    private func tabButton(_ tab: TabType) -> some View {
        let isActive = selectedTab == tab

        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: isActive ? tab.activeIcon : tab.icon)
                    .font(.system(size: 22, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? Color(hex: "#2D8B4E") : Color(hex: "#9E9E9E"))

                Text(tab.label)
                    .font(.system(size: 10, weight: isActive ? .bold : .regular, design: .rounded))
                    .foregroundColor(isActive ? Color(hex: "#2D8B4E") : Color(hex: "#9E9E9E"))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
