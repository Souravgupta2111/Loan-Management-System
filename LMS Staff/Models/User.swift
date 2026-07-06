//
//  User.swift
//  LMS
//
//  Data model for the `users` table.
//

import Foundation

// MARK: - Role Enum

enum UserRole: String, Codable, CaseIterable, Identifiable {
    case borrower
    case officer
    case manager
    case admin

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .borrower: return "Borrower"
        case .officer:  return "Officer"
        case .manager:  return "Manager"
        case .admin:    return "Admin"
        }
    }
}

// MARK: - User Model

struct AppUser: Codable, Identifiable, Hashable {
    let id: UUID
    var fullName: String
    var phone: String?
    var email: String?
    var role: UserRole
    var avatarUrl: String?
    var isActive: Bool
    var isVerified: Bool
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case phone
        case email
        case role
        case avatarUrl = "avatar_url"
        case isActive = "is_active"
        case isVerified = "is_verified"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
