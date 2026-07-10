import Foundation
import CoreLocation
import Supabase

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

struct AssignedOfficerInfo: Codable {
    let officerName: String
    let officerEmail: String?
    let officerUserId: UUID
    let branchName: String
    let branchCity: String?
}

@MainActor
class BranchAssignmentService {

    static let shared = BranchAssignmentService()

    private init() {}

    func autoAssign(applicationId: UUID) async -> BranchAssignmentResult? {
        var lat: Double? = nil
        var lon: Double? = nil

        if let gpsCoords = await LocationService.shared.fetchCurrentLocation() {
            lat = gpsCoords.latitude
            lon = gpsCoords.longitude
        } else {
            if let pincode = await fetchBorrowerPincode(applicationId: applicationId) {
                if let geocoded = await GeocodingService.shared.geocodePincode(pincode) {
                    lat = geocoded.latitude
                    lon = geocoded.longitude
                }
            }
        }

        return await callAutoAssignRPC(applicationId: applicationId, lat: lat, lon: lon)
    }

    func fetchAssignedOfficerInfo(applicationId: UUID) async -> AssignedOfficerInfo? {
        struct AppRow: Decodable {
            let assigned_officer_id: UUID?
            let branch_id: UUID?
        }

        do {
            let app: AppRow = try await SupabaseManager.shared.client
                .from("loan_applications")
                .select("assigned_officer_id, branch_id")
                .eq("id", value: applicationId)
                .single()
                .execute()
                .value

            guard let officerProfileId = app.assigned_officer_id else { return nil }

            struct StaffRow: Decodable { let user_id: UUID }
            let staffRow: StaffRow = try await SupabaseManager.shared.client
                .from("staff_profiles")
                .select("user_id")
                .eq("id", value: officerProfileId)
                .single()
                .execute()
                .value

            struct UserRow: Decodable {
                let full_name: String
                let email: String?
            }
            let officer: UserRow = try await SupabaseManager.shared.client
                .from("users")
                .select("full_name, email")
                .eq("id", value: staffRow.user_id)
                .single()
                .execute()
                .value

            var branchName = "Unknown Branch"
            var branchCity: String? = nil
            if let branchId = app.branch_id {
                struct BranchRow: Decodable {
                    let name: String
                    let city: String?
                }
                if let branch: BranchRow = try? await SupabaseManager.shared.client
                    .from("branches")
                    .select("name, city")
                    .eq("id", value: branchId)
                    .single()
                    .execute()
                    .value {
                    branchName = branch.name
                    branchCity = branch.city
                }
            }

            return AssignedOfficerInfo(
                officerName: officer.full_name,
                officerEmail: officer.email,
                officerUserId: staffRow.user_id,
                branchName: branchName,
                branchCity: branchCity
            )
        } catch {
            print("[BranchAssignmentService] Failed to fetch officer info: \(error)")
            return nil
        }
    }

    private func fetchBorrowerPincode(applicationId: UUID) async -> String? {
        struct AppBorrower: Decodable { let borrower_id: UUID }
        do {
            let app: AppBorrower = try await SupabaseManager.shared.client
                .from("loan_applications")
                .select("borrower_id")
                .eq("id", value: applicationId)
                .single()
                .execute()
                .value

            struct ProfileRow: Decodable { let pincode: String? }
            let profile: ProfileRow = try await SupabaseManager.shared.client
                .from("borrower_profiles")
                .select("pincode")
                .eq("user_id", value: app.borrower_id)
                .single()
                .execute()
                .value

            return profile.pincode
        } catch {
            return nil
        }
    }

    private func callAutoAssignRPC(applicationId: UUID, lat: Double?, lon: Double?) async -> BranchAssignmentResult? {
        struct Params: Encodable {
            let p_application_id: UUID
            let p_lat: Double?
            let p_lon: Double?
        }

        do {
            let result: BranchAssignmentResult = try await SupabaseManager.shared.client
                .rpc("auto_assign_branch_and_officer", params: Params(
                    p_application_id: applicationId,
                    p_lat: lat,
                    p_lon: lon
                ))
                .execute()
                .value

            print("[BranchAssignment] Assigned to branch: \(result.branchName), officer: \(result.officerName)")
            return result
        } catch {
            print("[BranchAssignment] Auto-assign RPC failed: \(error)")
            return nil
        }
    }
}
