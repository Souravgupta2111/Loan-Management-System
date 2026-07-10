import Foundation
import Supabase

struct OfficerWorkload: Identifiable {
    let id: UUID  // staff_profile id
    let userId: UUID
    let officerName: String
    let activeApplications: Int
}

@MainActor
class BranchAssignmentService {

    static let shared = BranchAssignmentService()
    private let supabase = SupabaseManager.shared

    private init() {}

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

    func findLeastLoadedOfficer(branchId: UUID) async throws -> OfficerWorkload? {
        let workload = try await fetchOfficerWorkload(branchId: branchId)
        return workload.first // Already sorted ASC by the RPC
    }
}

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
