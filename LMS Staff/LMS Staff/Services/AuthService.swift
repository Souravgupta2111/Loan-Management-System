import Foundation
import Supabase
import Combine

@MainActor
class AuthService: ObservableObject {
    
    static let shared = AuthService()
    
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    nonisolated func resolveEmail(from employeeId: String) -> String {
        let cleanedId = employeeId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleanedId == "ADM-0001" {
            return "guptajaihind786@gmail.com"
        }
        return "\(cleanedId.lowercased())@lms.internal"
    }
    
    func signIn(employeeId: String, password: String) async throws -> (AppUser, StaffProfile) {
        let cleanedId = employeeId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard isValidEmployeeId(cleanedId) else {
            throw NSError(domain: "AuthService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Employee ID format. Must start with ADM-, MGR-, or OFF-."])
        }
        
        let email = resolveEmail(from: cleanedId)
        
        let response = try await supabase.auth.signIn(email: email, password: password)
        let userId = response.user.id
        
        let appUser: AppUser = try await supabase.database
            .from("users")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value
            
        let staffProfile: StaffProfile = try await supabase.database
            .from("staff_profiles")
            .select()
            .eq("user_id", value: userId)
            .single()
            .execute()
            .value
            
        return (appUser, staffProfile)
    }
    
    func signOut() async throws {
        try await supabase.auth.signOut()
    }
    
    func parseRole(from employeeId: String) -> UserRole? {
        let cleanId = employeeId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleanId.hasPrefix("ADM-") {
            return .admin
        } else if cleanId.hasPrefix("MGR-") {
            return .manager
        } else if cleanId.hasPrefix("OFF-") {
            return .officer
        }
        return nil
    }
    
    func isValidEmployeeId(_ employeeId: String) -> Bool {
        let cleanId = employeeId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let regex = "^(ADM|MGR|OFF)-\\d{4}$"
        return cleanId.range(of: regex, options: .regularExpression) != nil
    }
}
