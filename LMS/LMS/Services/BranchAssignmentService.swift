//
//  BranchAssignmentService.swift
//  LMS
//
//  Handles automatic branch and officer assignment for loan applications.
//  Strategy:
//    1. Exact pincode match from branch_pincodes
//    2. 3-digit prefix match (same postal zone)
//    3. Nearest branch by GPS coordinates (user location or geocoded pincode)
//    4. Fallback to first active branch
//  Then assigns the least-loaded loan officer from the matched branch.
//

import Foundation
import CoreLocation
import Supabase

// MARK: - Assignment Result

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

// MARK: - Assigned Officer Info (for display in borrower app)

struct AssignedOfficerInfo: Codable {
    let officerName: String
    let officerEmail: String?
    let officerUserId: UUID
    let branchName: String
    let branchCity: String?
}

// MARK: - Service

@MainActor
class BranchAssignmentService {

    static let shared = BranchAssignmentService()

    private init() {}

    // MARK: - Auto-Assign (called after loan submission)

    /// Automatically assigns a branch and least-loaded officer to a loan application.
    /// Uses the borrower's GPS location if available, otherwise geocodes their pincode.
    /// This is a best-effort operation — if it fails, the application remains unassigned
    /// and staff can manually assign later.
    func autoAssign(applicationId: UUID) async -> BranchAssignmentResult? {
        // Step 1: Try to get user's GPS coordinates
        var lat: Double? = nil
        var lon: Double? = nil

        if let gpsCoords = await LocationService.shared.fetchCurrentLocation() {
            lat = gpsCoords.latitude
            lon = gpsCoords.longitude
        } else {
            // Step 2: Fallback — geocode borrower's pincode from profile
            if let pincode = await fetchBorrowerPincode(applicationId: applicationId) {
                if let geocoded = await GeocodingService.shared.geocodePincode(pincode) {
                    lat = geocoded.latitude
                    lon = geocoded.longitude
                }
            }
        }

        // Step 3: Call the Postgres RPC (handles pincode → prefix → geo → fallback chain)
        return await callAutoAssignRPC(applicationId: applicationId, lat: lat, lon: lon)
    }

    // MARK: - Fetch Assigned Officer Info

    /// Fetches the assigned officer and branch details for display in the borrower app.
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

            // Get officer's user_id from staff_profiles
            struct StaffRow: Decodable { let user_id: UUID }
            let staffRow: StaffRow = try await SupabaseManager.shared.client
                .from("staff_profiles")
                .select("user_id")
                .eq("id", value: officerProfileId)
                .single()
                .execute()
                .value

            // Get officer's name and email
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

            // Get branch info
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

    // MARK: - Private Helpers

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
