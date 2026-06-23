//
//  Branch.swift
//  LMS
//
//  Data model for the `branches` table.
//

import Foundation

struct Branch: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var code: String
    var address: String?
    var city: String?
    var state: String?
    var pincode: String?
    var ifscPrefix: String?
    var isActive: Bool
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case code
        case address
        case city
        case state
        case pincode
        case ifscPrefix = "ifsc_prefix"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
