 import SwiftUI

/// Main Tab View — 3 tabs: Home, My Loans, Schedule
struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                HomeDashboardView()
                    .environmentObject(authViewModel)
            }

            Tab("My Loans", systemImage: "indianrupeesign.circle.fill") {
                LoansListView()
                    .environmentObject(authViewModel)
            }
            
            Tab("Products", systemImage: "list.bullet.rectangle.portrait.fill") {
                LoanProductsCatalogView()
            }

            Tab("Schedule", systemImage: "calendar") {
                ScheduleOverviewView()
                    .environmentObject(authViewModel)
            }
        }
        .tint(.accentGreen)
        .onAppear {
            NotificationService.shared.subscribeToNotifications()
        }
        .onDisappear {
            NotificationService.shared.unsubscribe()
        }
    }
}
