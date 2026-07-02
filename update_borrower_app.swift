import Foundation

let sourcePath = "/Users/apple/Desktop/Sprint 1/LMS/LMS/Services/SetuAAService.swift"
let content = try! String(contentsOfFile: sourcePath, encoding: .utf8)

if !content.contains("func completeVerification") {
    let completeVerFunc = """

    // MARK: - Full Verification Flow (Convenience)
    
    func completeVerification(consentId: String) async throws -> AnalyzedIncome {
        // Check consent status
        let status = try await getConsentStatus(consentId: consentId)
        guard status.status.uppercased() == "APPROVED" || status.status.uppercased() == "ACTIVE" else {
            throw SetuError.consentNotApproved("Consent status: \\(status.status). User must approve first.")
        }
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var toDate = Date()
        if let startString = status.detail?.consentStart {
            if let parsed = isoFormatter.date(from: startString) {
                toDate = parsed
            } else {
                let formatterWithoutFractional = ISO8601DateFormatter()
                formatterWithoutFractional.formatOptions = [.withInternetDateTime]
                if let parsed = formatterWithoutFractional.date(from: startString) {
                    toDate = parsed
                }
            }
        }
        
        // Safe to use 1 day before consentStart to ensure it's strictly within the consent's dataRange!
        let safeToDate = Calendar.current.date(byAdding: .day, value: -1, to: toDate)!
        // Safe to use 11 months before safeToDate to ensure it's after the consent's 1-year start bound
        let safeFromDate = Calendar.current.date(byAdding: .month, value: -11, to: safeToDate)!
        
        let formatterForSession = ISO8601DateFormatter()
        formatterForSession.formatOptions = [.withInternetDateTime]
        
        let fromDateStr = formatterForSession.string(from: safeFromDate)
        let toDateStr = formatterForSession.string(from: safeToDate)
        
        // Create data session
        let session = try await createDataSession(consentId: consentId) // Wait, borrower app createDataSession only takes consentId!
        // Let's modify the createDataSession in Borrower app if needed, or just use it.
        // Actually, borrower app createDataSession hardcodes the date range internally.
        // So we can just call:
        // let session = try await createDataSession(consentId: consentId)
"""
}
