//
//  SupabaseManager.swift
//  LMS
//
//  Singleton managing the Supabase client connection.
//  Reads URL and anon key from Config/Supabase.plist.
//

import Foundation
import Supabase

@MainActor
final class SupabaseManager {

    // MARK: - Singleton

    static let shared = SupabaseManager()

    // MARK: - Client

    let client: SupabaseClient

    // MARK: - Init

    private init() {
        guard let path = Bundle.main.path(forResource: "Supabase", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: path),
              let urlString = config["SUPABASE_URL"] as? String,
              let anonKey = config["SUPABASE_ANON_KEY"] as? String,
              let url = URL(string: urlString) else {
            fatalError("Missing or invalid Supabase.plist configuration. Ensure SUPABASE_URL and SUPABASE_ANON_KEY are set.")
        }

        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey
        )
    }

    // MARK: - Convenience Accessors

    var auth: AuthClient {
        client.auth
    }

    var storage: SupabaseStorageClient {
        client.storage
    }

    // MARK: - Current User

    var currentUser: User? {
        client.auth.currentUser
    }

    var currentUserId: UUID? {
        currentUser?.id
    }

    var isAuthenticated: Bool {
        currentUser != nil
    }
}
