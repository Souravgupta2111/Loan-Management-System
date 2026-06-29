//
//  BranchPincode.swift
//  LMS Staff
//
//  Data model for the `branch_pincodes` table.
//  Maps pincodes to branches for proximity-based loan assignment.
//

import Foundation

struct BranchPincode: Codable, Identifiable, Hashable {
    let id: UUID
    let branchId: UUID
    var pincode: String
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case branchId = "branch_id"
        case pincode
        case createdAt = "created_at"
    }
}
