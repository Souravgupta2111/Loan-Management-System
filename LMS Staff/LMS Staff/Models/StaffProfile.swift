//
//  StaffProfile.swift
//  LMS
//
//  Data model for the `staff_profiles` table.
//

import Foundation

struct StaffProfile: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    var employeeId: String
    var designation: String?
    var department: String?
    var branchId: UUID?
    var reportsTo: UUID?
    var maxLoanApprovalLimit: Double?
    var canDisburse: Bool
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case employeeId = "employee_id"
        case designation
        case department
        case branchId = "branch_id"
        case reportsTo = "reports_to"
        case maxLoanApprovalLimit = "max_loan_approval_limit"
        case canDisburse = "can_disburse"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
