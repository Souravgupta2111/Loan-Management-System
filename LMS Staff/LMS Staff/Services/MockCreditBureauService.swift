import Foundation
import Supabase

final class MockCreditBureauService {
    static let shared = MockCreditBureauService()
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    func fetchAndSaveCreditScore(userId: UUID, panNumber: String?) async throws -> Int {
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        let generatedScore: Int
        if let pan = panNumber, !pan.isEmpty {
            let hash = pan.hashValue
            generatedScore = 600 + (abs(hash) % 251)
        } else {
            generatedScore = Int.random(in: 650...800)
        }
        
        struct CreditScoreUpdate: Encodable {
            let credit_score: Int
        }
        
        try await supabase.client
            .from("borrower_profiles")
            .update(CreditScoreUpdate(credit_score: generatedScore))
            .eq("user_id", value: userId)
            .execute()
        
        return generatedScore
    }
}
