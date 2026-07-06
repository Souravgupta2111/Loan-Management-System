//
//  AuditLog.swift
//  LMS
//
//  Data model for the `audit_log` table.
//

import Foundation

struct AuditLog: Codable, Identifiable, Hashable {
    let id: UUID
    var actorId: UUID?
    var actorRole: UserRole?
    var tableName: String
    var recordId: UUID?
    var action: String  // INSERT, UPDATE, DELETE
    var changeSummary: String?
    var ipAddress: String?
    var userAgent: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case actorId = "actor_id"
        case actorRole = "actor_role"
        case tableName = "table_name"
        case recordId = "record_id"
        case action
        case changeSummary = "change_summary"
        case ipAddress = "ip_address"
        case userAgent = "user_agent"
        case createdAt = "created_at"
    }
}
