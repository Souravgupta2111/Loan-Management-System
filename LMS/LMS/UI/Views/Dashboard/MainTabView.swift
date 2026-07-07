import SwiftUI
import UIKit

/// Main Tab View — uses the native iOS tab bar with a translucent glass appearance.
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

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterial)
        appearance.backgroundColor = UIColor.white.withAlphaComponent(0.42)
        appearance.shadowColor = UIColor.black.withAlphaComponent(0.08)

        let selectedColor = UIColor(Color.accentGreen)
        let normalColor = UIColor.secondaryLabel
        let appearances = [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance
        ]

        appearances.forEach { itemAppearance in
            itemAppearance.selected.iconColor = selectedColor
            itemAppearance.selected.titleTextAttributes = [
                .foregroundColor: selectedColor,
                .font: UIFont.systemFont(ofSize: 11, weight: .semibold)
            ]
            itemAppearance.normal.iconColor = normalColor
            itemAppearance.normal.titleTextAttributes = [
                .foregroundColor: normalColor,
                .font: UIFont.systemFont(ofSize: 11, weight: .medium)
            ]
        }

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().isTranslucent = true
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeDashboardView()
                .environmentObject(authViewModel)
                .tabItem {
                    Label(TabType.home.label, systemImage: selectedTab == .home ? TabType.home.activeIcon : TabType.home.icon)
                }
                .tag(TabType.home)

            LoansListView()
                .environmentObject(authViewModel)
                .tabItem {
                    Label(TabType.loans.label, systemImage: selectedTab == .loans ? TabType.loans.activeIcon : TabType.loans.icon)
                }
                .tag(TabType.loans)

            ScheduleOverviewView()
                .environmentObject(authViewModel)
                .tabItem {
                    Label(TabType.schedule.label, systemImage: selectedTab == .schedule ? TabType.schedule.activeIcon : TabType.schedule.icon)
                }
                .tag(TabType.schedule)
            }
        .tint(.accentGreen)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            Task {
                // Ask for notification permission (first launch) before subscribing,
                // then start listening for realtime notification inserts.
                try? await NotificationService.shared.requestPermission()
                NotificationService.shared.subscribeToNotifications()
            }
        }
    }
}
