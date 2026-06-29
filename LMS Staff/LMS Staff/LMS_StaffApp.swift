//
//  LMS_StaffApp.swift
//  LMS Staff
//
//  Created for Staff/Admin portal.
//

import SwiftUI

@main
struct LMS_StaffApp: App {
    // Initialize Supabase on app launch
    private let supabase = SupabaseManager.shared
    @StateObject private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
                .tint(.staffAccent)
                .environmentObject(authViewModel)
                .onAppear {
                    // Start global activity monitoring on the window
                    NotificationCenter.default.addObserver(
                        forName: NSNotification.Name("UserDidInteract"),
                        object: nil,
                        queue: .main
                    ) { _ in
                        Task { @MainActor in
                            authViewModel.resetActivity()
                        }
                    }
                }
        }
    }
}
