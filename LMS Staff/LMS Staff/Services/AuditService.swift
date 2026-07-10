import Foundation
import Supabase

class AuditService {
    
    static let shared = AuditService()
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    func logAction(
        action: String,
        tableName: String,
        recordId: UUID?,
        summary: String,
        oldValue: [String: String]? = nil,
        newValue: [String: String]? = nil
    ) async throws {
        guard let currentUserId = supabase.currentUserId else { return }
        
        struct RoleRow: Decodable { let role: UserRole }
        let roleRow: RoleRow? = try? await supabase.database
            .from("users")
            .select("role")
            .eq("id", value: currentUserId)
            .single()
            .execute()
            .value
        let role = roleRow?.role
            ?? AuthService.shared.parseRole(from: supabase.currentUser?.email ?? "")
            ?? .officer
        
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
        
        _ = try? await supabase.database
            .from("audit_log")
            .insert(payload)
            .execute()
    }
    
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
    
}

