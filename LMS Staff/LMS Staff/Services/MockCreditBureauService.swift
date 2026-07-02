import Foundation
import Supabase

final class MockCreditBureauService {
    static let shared = MockCreditBureauService()
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    /// Simulates an API call to a credit bureau (e.g., CIBIL or Experian) and saves the result to the borrower's profile.
    func fetchAndSaveCreditScore(userId: UUID, panNumber: String?) async throws -> Int {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        // Generate a deterministic but realistic credit score based on the PAN number.
        // If no PAN is provided, default to a random score between 650 and 800.
        let generatedScore: Int
        if let pan = panNumber, !pan.isEmpty {
            let hash = pan.hashValue
            // Map the hash to a score between 600 and 850
            generatedScore = 600 + (abs(hash) % 251)
        } else {
            generatedScore = Int.random(in: 650...800)
        }
        
        // Save the generated score to the database
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
