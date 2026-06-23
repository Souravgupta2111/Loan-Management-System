//
//  SystemConfig.swift
//  LMS
//
//  Data model for the `system_configs` table.
//

import Foundation

struct SystemConfig: Codable, Identifiable, Hashable {
    let id: UUID
    var configKey: String
    var configValue: String?
    var valueType: String
    var description: String?
    var isEditable: Bool
    var lastUpdatedBy: UUID?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case configKey = "config_key"
        case configValue = "config_value"
        case valueType = "value_type"
        case description
        case isEditable = "is_editable"
        case lastUpdatedBy = "last_updated_by"
        case updatedAt = "updated_at"
    }
}
