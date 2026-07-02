//
//  BranchAssignmentService.swift
//  LMS Staff
//
//  Service for automated and manual branch/officer assignment.
//  Provides workload visibility for managers and manual assignment triggers.
//

import Foundation
import Supabase

// MARK: - Officer Workload Model

struct OfficerWorkload: Identifiable {
    let id: UUID  // staff_profile id
    let userId: UUID
    let officerName: String
    let activeApplications: Int
}

// MARK: - Service

@MainActor
class BranchAssignmentService {

    static let shared = BranchAssignmentService()
    private let supabase = SupabaseManager.shared

    private init() {}

    // MARK: - Auto-Assign via RPC

    /// Triggers auto-assignment for a specific application.
    /// Calls the Postgres RPC that handles pincode → geo → fallback chain.
    func autoAssign(applicationId: UUID) async throws -> BranchAssignmentResult {
        struct Params: Encodable {
            let p_application_id: UUID
            let p_lat: Double?
            let p_lon: Double?
        }

        let result: BranchAssignmentResult = try await supabase.database
            .rpc("auto_assign_branch_and_officer", params: Params(
                p_application_id: applicationId,
                p_lat: nil,
                p_lon: nil
            ))
            .execute()
            .value

        try await AuditService.shared.logAction(
            action: "AUTO_ASSIGN_BRANCH_OFFICER",
            tableName: "loan_applications",
            recordId: applicationId,
            summary: "Auto-assigned branch: \(result.branchName), officer: \(result.officerName)"
        )

        return result
    }

    // MARK: - Officer Workload Query

    /// Fetches the workload (active application count) for all officers in a branch.
    /// Uses the Postgres RPC for efficient server-side computation.
    func fetchOfficerWorkload(branchId: UUID) async throws -> [OfficerWorkload] {
        struct Params: Encodable {
            let p_branch_id: UUID
        }

        struct WorkloadRow: Decodable {
            let officer_profile_id: UUID
            let officer_user_id: UUID
            let officer_name: String
            let active_applications: Int
        }

        let rows: [WorkloadRow] = try await supabase.database
            .rpc("get_officer_workload", params: Params(p_branch_id: branchId))
            .execute()
            .value

        return rows.map {
            OfficerWorkload(
                id: $0.officer_profile_id,
                userId: $0.officer_user_id,
                officerName: $0.officer_name,
                activeApplications: $0.active_applications
            )
        }
    }

    // MARK: - Batch Auto-Assign Unassigned Applications

    /// Finds all unassigned applications and triggers auto-assignment for each.
    /// Returns the number of successfully assigned applications.
    func autoAssignAllUnassigned() async throws -> Int {
        let applications: [LoanApplication] = try await supabase.database
            .from("loan_applications")
            .select()
            .is("branch_id", value: nil)
            .neq("status", value: "draft")
            .execute()
            .value

        if applications.isEmpty { return 0 }

        var assignedCount = 0

        for app in applications {
            do {
                let _ = try await autoAssign(applicationId: app.id)
                assignedCount += 1
            } catch {
                print("[BranchAssignment] Failed to assign application \(app.id): \(error)")
            }
        }

        return assignedCount
    }

    // MARK: - Find Least-Loaded Officer (Swift-side helper)

    /// Finds the officer with the fewest active applications in a branch.
    /// Useful for manual reassignment from the manager dashboard.
    func findLeastLoadedOfficer(branchId: UUID) async throws -> OfficerWorkload? {
        let workload = try await fetchOfficerWorkload(branchId: branchId)
        return workload.first // Already sorted ASC by the RPC
    }
}

// MARK: - Assignment Result (shared decode struct)

struct BranchAssignmentResult: Codable {
    let branchId: UUID?
    let branchName: String
    let officerId: UUID?
    let officerUserId: UUID?
    let officerName: String

    enum CodingKeys: String, CodingKey {
        case branchId = "branch_id"
        case branchName = "branch_name"
        case officerId = "officer_id"
        case officerUserId = "officer_user_id"
        case officerName = "officer_name"
    }
}
