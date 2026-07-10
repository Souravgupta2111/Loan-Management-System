import Foundation
import WidgetKit
import Supabase

enum StaffWidgetKeys {
    static let appGroupID = "group.com.sourav.hi123.LMS"
    static let snapshot = "staffwidget.snapshot"
}

struct StaffAuditEntryDTO: Codable, Identifiable {
    var id: String
    var action: String
    var actor: String
    var role: String?
    var date: Date
}

struct StaffWidgetSnapshotDTO: Codable {
    var role: String

    var officerPending: Int
    var officerSubmitted: Int
    var officerUnderReview: Int
    var officerSentBack: Int
    var oldestName: String?
    var oldestDays: Int?

    var activeLoans: Int
    var totalDisbursed: Double
    var npaPercentage: Double
    var collectionEfficiency: Double
    var pendingApprovals: Int
    var pendingDisbursements: Int
    var overdueEmis: Int
    var npaCount: Int

    var totalBorrowers: Int
    var staffCount: Int
    var branchCount: Int
    var auditAlerts24h: Int
    var auditEntries: [StaffAuditEntryDTO]

    var generated: Date

    static func empty(role: String) -> StaffWidgetSnapshotDTO {
        StaffWidgetSnapshotDTO(
            role: role, officerPending: 0, officerSubmitted: 0, officerUnderReview: 0,
            officerSentBack: 0,
            oldestName: nil, oldestDays: nil, activeLoans: 0, totalDisbursed: 0,
            npaPercentage: 0, collectionEfficiency: 0, pendingApprovals: 0, pendingDisbursements: 0, overdueEmis: 0,
            npaCount: 0, totalBorrowers: 0, staffCount: 0, branchCount: 0, auditAlerts24h: 0,
            auditEntries: [],
            generated: Date()
        )
    }
}

@MainActor
enum StaffWidgetDataProvider {
    private static var defaults: UserDefaults? { UserDefaults(suiteName: StaffWidgetKeys.appGroupID) }
    private static var supabase: SupabaseManager { SupabaseManager.shared }

    static func refresh(role: UserRole) async {
        guard defaults != nil else { return } // App Group not configured yet.
        var snap = StaffWidgetSnapshotDTO.empty(role: role.rawValue)
        do {
            switch role {
            case .officer:
                try await fillOfficer(&snap)
            case .manager:
                try await fillPortfolio(&snap)
            case .admin:
                try await fillPortfolio(&snap)
                try await fillAdmin(&snap)
            case .borrower:
                break
            }
            write(snap)
        } catch {
            print("StaffWidget refresh error: \(error)")
        }
    }

    static func clearSnapshot() {
        guard let defaults else { return }
        var empty = StaffWidgetSnapshotDTO.empty(role: "none")
        empty.generated = Date()
        if let data = try? JSONEncoder().encode(empty) {
            defaults.set(data, forKey: StaffWidgetKeys.snapshot)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func write(_ snap: StaffWidgetSnapshotDTO) {
        guard let defaults else { return }
        if let data = try? JSONEncoder().encode(snap) {
            defaults.set(data, forKey: StaffWidgetKeys.snapshot)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private struct AppRow: Decodable {
        let id: UUID
        let application_number: String?
        let borrower_id: UUID
        let created_at: Date?
        let status: String
        let assigned_officer_id: UUID?
    }

    private static func fillOfficer(_ snap: inout StaffWidgetSnapshotDTO) async throws {
        guard let userId = supabase.currentUserId else { return }

        struct ProfileRow: Decodable { 
            let id: UUID
            let branch_id: UUID?
        }
        let profile: ProfileRow? = try? await supabase.database
            .from("staff_profiles")
            .select("id, branch_id")
            .eq("user_id", value: userId.uuidString)
            .single()
            .execute()
            .value
        guard let profileId = profile?.id else { return }

        let appsQuery = supabase.database
            .from("loan_applications")
            .select("id, application_number, borrower_id, created_at, status, assigned_officer_id")
            
        let apps: [AppRow]
        if let branchId = profile?.branch_id {
            apps = try await appsQuery
                .or("assigned_officer_id.eq.\(profileId.uuidString),and(status.eq.submitted,branch_id.eq.\(branchId.uuidString))")
                .order("created_at", ascending: true)
                .execute()
                .value
        } else {
            apps = try await appsQuery
                .eq("assigned_officer_id", value: profileId.uuidString)
                .order("created_at", ascending: true)
                .execute()
                .value
        }

        struct HistoryID: Codable {
            let application_id: UUID
        }
        let historyLogs: [HistoryID] = (try? await supabase.database
            .from("approval_history")
            .select("application_id")
            .eq("actor_id", value: userId.uuidString)
            .execute()
            .value) ?? []
        let actionedAppIds = Array(Set(historyLogs.map { $0.application_id }))

        var allApps = apps
        if !actionedAppIds.isEmpty {
            let additionalApps: [AppRow] = (try? await supabase.database
                .from("loan_applications")
                .select("id, application_number, borrower_id, created_at, status, assigned_officer_id")
                .in("id", values: actionedAppIds)
                .execute()
                .value) ?? []
            
            var seenIds = Set(allApps.map { $0.id })
            for app in additionalApps {
                if !seenIds.contains(app.id) {
                    allApps.append(app)
                    seenIds.insert(app.id)
                }
            }
        }

        let activeApps = allApps.filter { $0.status != "disbursed" }
        snap.officerPending = activeApps.filter { $0.status == "submitted" }.count
        snap.officerSubmitted = activeApps.filter { $0.status == "under_review" }.count
        snap.officerUnderReview = snap.officerPending
        snap.officerSentBack = activeApps.filter { $0.status == "sent_back" }.count

        if let oldest = allApps.first(where: { $0.status == "submitted" }) {
            snap.oldestDays = oldest.created_at.map {
                Calendar.current.dateComponents([.day], from: $0, to: Date()).day ?? 0
            }
            struct NameRow: Decodable { let full_name: String }
            let name: NameRow? = try? await supabase.database
                .from("users")
                .select("full_name")
                .eq("id", value: oldest.borrower_id.uuidString)
                .single()
                .execute()
                .value
            snap.oldestName = name?.full_name
        }
    }

    private static func fillPortfolio(_ snap: inout StaffWidgetSnapshotDTO) async throws {
        struct LoanRow: Decodable { let principal_amount: Double? }
        let active: [LoanRow] = try await supabase.client
            .from("loans").select("principal_amount").eq("status", value: "active").execute().value
        snap.activeLoans = active.count
        snap.totalDisbursed = active.reduce(0) { $0 + ($1.principal_amount ?? 0) }

        snap.npaCount = (try? await count("loans", eq: ("status", "npa"))) ?? 0
        snap.pendingApprovals = (try? await count("loan_applications", eq: ("status", "under_review"))) ?? 0
        snap.pendingDisbursements = (try? await count("loan_applications", eq: ("status", "pending_disbursal"))) ?? 0
        snap.overdueEmis = (try? await count("emi_schedule", eq: ("status", "overdue"))) ?? 0
        let paid = (try? await count("emi_schedule", eq: ("status", "paid"))) ?? 0

        let settled = paid + snap.overdueEmis
        snap.collectionEfficiency = settled == 0 ? 100 : (Double(paid) / Double(settled) * 100).rounded()
        let denom = snap.activeLoans + snap.npaCount
        snap.npaPercentage = denom == 0 ? 0 : (Double(snap.npaCount) / Double(denom) * 100 * 10).rounded() / 10
    }

    private static func fillAdmin(_ snap: inout StaffWidgetSnapshotDTO) async throws {
        snap.totalBorrowers = (try? await count("users", eq: ("role", "borrower"))) ?? 0
        snap.staffCount = (try? await countAll("staff_profiles")) ?? 0
        snap.branchCount = (try? await countAll("branches")) ?? 0

        let since = ISO8601DateFormatter().string(from: Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date())
        let resp = try await supabase.client
            .from("audit_log").select("id", head: true, count: .exact)
            .gte("created_at", value: since).execute()
        snap.auditAlerts24h = resp.count ?? 0

        snap.auditEntries = (try? await fetchRecentAudit()) ?? []
    }

    private struct AuditLogRow: Decodable {
        let id: UUID
        let action: String
        let actor_id: UUID?
        let actor_role: String?
        let created_at: Date?
    }

    private static func fetchRecentAudit() async throws -> [StaffAuditEntryDTO] {
        let rows: [AuditLogRow] = try await supabase.client
            .from("audit_log")
            .select("id, action, actor_id, actor_role, created_at")
            .order("created_at", ascending: false)
            .limit(10)
            .execute().value

        let ids = Array(Set(rows.compactMap { $0.actor_id }))
        var names: [UUID: String] = [:]
        if !ids.isEmpty {
            struct NameRow: Decodable { let id: UUID; let full_name: String }
            let people: [NameRow] = (try? await supabase.client
                .from("users").select("id, full_name")
                .in("id", values: ids.map { $0.uuidString })
                .execute().value) ?? []
            for p in people { names[p.id] = p.full_name }
        }

        return rows.map { row in
            let actor = row.actor_id.flatMap { names[$0] } ?? "System"
            return StaffAuditEntryDTO(
                id: row.id.uuidString,
                action: row.action,
                actor: actor,
                role: row.actor_role,
                date: row.created_at ?? Date()
            )
        }
    }

    private static func count(_ table: String, eq: (String, String)) async throws -> Int {
        let resp = try await supabase.client
            .from(table).select("id", head: true, count: .exact).eq(eq.0, value: eq.1).execute()
        return resp.count ?? 0
    }

    private static func countIn(_ table: String, _ column: String, _ values: [String]) async throws -> Int {
        let resp = try await supabase.client
            .from(table).select("id", head: true, count: .exact).in(column, values: values).execute()
        return resp.count ?? 0
    }

    private static func countAll(_ table: String) async throws -> Int {
        let resp = try await supabase.client
            .from(table).select("id", head: true, count: .exact).execute()
        return resp.count ?? 0
    }
}
