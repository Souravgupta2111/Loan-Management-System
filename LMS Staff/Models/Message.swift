//
//  Message.swift
//  LMS
//
//  Data model for the `messages` table.
//

import Foundation

// MARK: - Message Type Enum

enum MessageType: String, Codable, CaseIterable, Identifiable {
    case text
    case system
    case attachment

    var id: String { rawValue }
}

// MARK: - Message Model

struct Message: Codable, Identifiable, Hashable {
    let id: UUID
    let applicationId: UUID
    let senderId: UUID
    let receiverId: UUID
    var content: String
    var messageType: MessageType
    var attachmentUrl: String?
    var isRead: Bool
    var readAt: Date?
    let sentAt: Date?
    var isDeletedBySender: Bool
    var isDeletedByReceiver: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case applicationId = "application_id"
        case senderId = "sender_id"
        case receiverId = "receiver_id"
        case content
        case messageType = "message_type"
        case attachmentUrl = "attachment_url"
        case isRead = "is_read"
        case readAt = "read_at"
        case sentAt = "sent_at"
        case isDeletedBySender = "is_deleted_by_sender"
        case isDeletedByReceiver = "is_deleted_by_receiver"
    }
}
