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
    
    /// Fetches audit logs with pagination and optional search.
    func fetchAuditLogs(offset: Int = 0, limit: Int = 50, searchQuery: String? = nil) async throws -> [AuditLog] {
        var query = supabase.database
            .from("audit_log")
            .select()
            
        if let search = searchQuery, !search.isEmpty {
            let term = "%\(search)%"
            query = query.or("action.ilike.\(term),table_name.ilike.\(term),change_summary.ilike.\(term)")
        }
            
        let logs: [AuditLog] = try await query
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
        return logs
    }
    
    /// Fetches audit logs specific to a given record ID.
    func fetchAuditLogs(forRecordId recordId: UUID, limit: Int = 100) async throws -> [AuditLog] {
        let logs: [AuditLog] = try await supabase.database
            .from("audit_log")
            .select()
            .eq("record_id", value: recordId.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return logs
    }
    
    /// Seeds the audit_log table with initial data if it's currently empty
    func seedAuditLogsIfEmpty() async {
        do {
            let logs: [AuditLog] = try await fetchAuditLogs(limit: 1)
            guard logs.isEmpty else { return } // Already seeded
            
            let mockLogs: [[String: AnyEncodable]] = [
                [
                    "actor_id": AnyEncodable(UUID().uuidString),
                    "actor_role": AnyEncodable(UserRole.admin.rawValue),
                    "table_name": AnyEncodable("system"),
                    "record_id": AnyEncodable(UUID().uuidString),
                    "action": AnyEncodable("SYSTEM_INIT"),
                    "change_summary": AnyEncodable("System initialized and core services started."),
                    "ip_address": AnyEncodable("127.0.0.1"),
                    "user_agent": AnyEncodable("System/1.0")
                ],
                [
                    "actor_id": AnyEncodable(UUID().uuidString),
                    "actor_role": AnyEncodable(UserRole.manager.rawValue),
                    "table_name": AnyEncodable("loans"),
                    "record_id": AnyEncodable(UUID().uuidString),
                    "action": AnyEncodable("LOAN_APPROVED"),
                    "change_summary": AnyEncodable("Manager approved loan application after credit check."),
                    "ip_address": AnyEncodable("192.168.1.105"),
                    "user_agent": AnyEncodable("iOS/iPadOS Staff App")
                ],
                [
                    "actor_id": AnyEncodable(UUID().uuidString),
                    "actor_role": AnyEncodable(UserRole.officer.rawValue),
                    "table_name": AnyEncodable("documents"),
                    "record_id": AnyEncodable(UUID().uuidString),
                    "action": AnyEncodable("DOC_VERIFIED"),
                    "change_summary": AnyEncodable("Officer verified KYC documents (Aadhaar, PAN)."),
                    "ip_address": AnyEncodable("192.168.1.110"),
                    "user_agent": AnyEncodable("iOS/iPadOS Staff App")
                ],
                [
                    "actor_id": AnyEncodable(UUID().uuidString),
                    "actor_role": AnyEncodable(UserRole.admin.rawValue),
                    "table_name": AnyEncodable("payments"),
                    "record_id": AnyEncodable(UUID().uuidString),
                    "action": AnyEncodable("PAYMENT_RECEIVED"),
                    "change_summary": AnyEncodable("Automated Razorpay webhook triggered for successful EMI repayment."),
                    "ip_address": AnyEncodable("10.0.0.5"),
                    "user_agent": AnyEncodable("Razorpay Webhook")
                ],
                [
                    "actor_id": AnyEncodable(UUID().uuidString),
                    "actor_role": AnyEncodable(UserRole.admin.rawValue),
                    "table_name": AnyEncodable("settings"),
                    "record_id": AnyEncodable(UUID().uuidString),
                    "action": AnyEncodable("POLICY_UPDATE"),
                    "change_summary": AnyEncodable("Admin updated global interest rate policy from 12% to 11.5%."),
                    "ip_address": AnyEncodable("192.168.1.50"),
                    "user_agent": AnyEncodable("Web/Dashboard")
                ]
            ]
            
            _ = try await supabase.database
                .from("audit_log")
                .insert(mockLogs)
                .execute()
            
            print("Successfully seeded audit logs.")
            
        } catch {
            print("Failed to seed audit logs: \(error)")
        }
    }
}
