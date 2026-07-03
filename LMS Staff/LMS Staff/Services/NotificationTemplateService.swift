//
//  NotificationTemplateService.swift
//  LMS Staff
//
//  Service for managing notification templates.
//

import Foundation
import Supabase

class NotificationTemplateService {
    
    static let shared = NotificationTemplateService()
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    /// Fetches all notification templates from the database
    func fetchTemplates() async throws -> [NotificationTemplate] {
        let templates: [NotificationTemplate] = try await supabase.database
            .from("notification_templates")
            .select()
            .order("event_name", ascending: true)
            .execute()
            .value
        return templates
    }
    
    /// Updates only the template text (backward-compatible)
    func updateTemplate(id: UUID, templateText: String) async throws -> Bool {
        try await supabase.database
            .from("notification_templates")
            .update([
                "template_text": AnyEncodable(templateText),
                "updated_at": AnyEncodable(ISO8601DateFormatter().string(from: Date()))
            ])
            .eq("id", value: id)
            .execute()
        return true
    }
    
    /// Updates all editable fields of a notification template
    func updateTemplateFull(
        id: UUID,
        eventName: String,
        templateText: String,
        description: String,
        isActive: Bool,
        supportedPlaceholders: [String]
    ) async throws -> Bool {
        let payload: [String: AnyEncodable] = [
            "event_name": AnyEncodable(eventName),
            "template_text": AnyEncodable(templateText),
            "description": AnyEncodable(description),
            "is_active": AnyEncodable(isActive),
            "supported_placeholders": AnyEncodable(supportedPlaceholders),
            "updated_at": AnyEncodable(ISO8601DateFormatter().string(from: Date()))
        ]
        
        try await supabase.database
            .from("notification_templates")
            .update(payload)
            .eq("id", value: id)
            .execute()
        return true
    }
    
    /// Toggles the active status of a template
    func toggleActive(id: UUID, isActive: Bool) async throws {
        try await supabase.database
            .from("notification_templates")
            .update([
                "is_active": AnyEncodable(isActive),
                "updated_at": AnyEncodable(ISO8601DateFormatter().string(from: Date()))
            ])
            .eq("id", value: id)
            .execute()
    }
    
    /// Deletes a notification template
    func deleteTemplate(id: UUID) async throws {
        try await supabase.database
            .from("notification_templates")
            .delete()
            .eq("id", value: id)
            .execute()
    }
    
    /// Creates a new template
    func createTemplate(eventName: String, templateText: String, description: String, placeholders: [String]) async throws -> NotificationTemplate {
        let payload: [String: AnyEncodable] = [
            "event_name": AnyEncodable(eventName),
            "template_text": AnyEncodable(templateText),
            "description": AnyEncodable(description),
            "supported_placeholders": AnyEncodable(placeholders),
            "is_active": AnyEncodable(true)
        ]
        
        let newTemplate: NotificationTemplate = try await supabase.database
            .from("notification_templates")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
            
        return newTemplate
    }
}

