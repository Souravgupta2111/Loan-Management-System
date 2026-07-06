//
//  NotificationTemplate.swift
//  LMS Staff
//
//  Data model for the notification_templates table.
//

import Foundation

struct NotificationTemplate: Codable, Identifiable, Hashable {
    let id: UUID
    var eventName: String
    var templateText: String
    var description: String?
    var supportedPlaceholders: [String]?
    var isActive: Bool
    
    let createdAt: Date?
    var updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case eventName = "event_name"
        case templateText = "template_text"
        case description
        case supportedPlaceholders = "supported_placeholders"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
