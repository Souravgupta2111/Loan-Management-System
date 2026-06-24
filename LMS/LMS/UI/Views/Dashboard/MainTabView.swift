import SwiftUI

/// Main Tab View — 3 tabs: Home, Loans, EMI Calculator
struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                HomeDashboardView()
                    .environmentObject(authViewModel)
            }

            Tab("Loans", systemImage: "indianrupeesign.circle.fill") {
                LoansListView()
                    .environmentObject(authViewModel)
            }

            Tab("EMI Calc", systemImage: "function") {
                EMICalculatorView()
            }
        }
        .tint(.accentDark)
        .onAppear {
            NotificationService.shared.subscribeToNotifications()
        }
        .onDisappear {
            NotificationService.shared.unsubscribe()
        }
    }
}
