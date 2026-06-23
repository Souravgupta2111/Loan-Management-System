//
//  LMSApp.swift
//  LMS
//
//  Created by Apple on 22/06/26.
//

import SwiftUI

@main
struct LMSApp: App {

    // Initialize Supabase on app launch
    private let supabase = SupabaseManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
