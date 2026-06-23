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

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
