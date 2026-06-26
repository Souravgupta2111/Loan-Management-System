//
//  AuditService.swift
//  LMS Staff
//
//  Service for managing and querying the read-only system audit trail.
//

import Foundation
import Supabase

class AuditService {
    
    static let shared = AuditService()
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    /// Writes an audit record to the `audit_log` table
    func logAction(
        action: String,
        tableName: String,
        recordId: UUID?,
        summary: String,
        oldValue: [String: String]? = nil,
        newValue: [String: String]? = nil
    ) async throws {
        guard let currentUserId = supabase.currentUserId else { return }
        
        // Fetch current user role
        let role = AuthService.shared.parseRole(from: supabase.currentUser?.email ?? "") ?? .officer
        
        let payload: [String: AnyEncodable] = [
            "actor_id": AnyEncodable(currentUserId),
            "actor_role": AnyEncodable(role.rawValue),
            "table_name": AnyEncodable(tableName),
            "record_id": AnyEncodable(recordId?.uuidString ?? ""),
            "action": AnyEncodable(action),
            "change_summary": AnyEncodable(summary),
            "old_value": AnyEncodable(oldValue ?? [:]),
            "new_value": AnyEncodable(newValue ?? [:]),
            "ip_address": AnyEncodable("127.0.0.1"),
            "user_agent": AnyEncodable("iOS/iPadOS Staff App")
        ]
        
        // Use try? because audit logging should fail-safe and not block critical transaction flows
        _ = try? await supabase.database
            .from("audit_log")
            .insert(payload)
            .execute()
    }
    
    /// Fetches audit logs with simple pagination.
    func fetchAuditLogs(limit: Int = 100) async throws -> [AuditLog] {
        let logs: [AuditLog] = try await supabase.database
            .from("audit_log")
            .select()
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return logs
    }
}
