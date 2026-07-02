//
//  SetuAAService.swift
//  LMS Staff
//
//  Setu Account Aggregator integration for income verification.
//  Uses Setu AA v2 APIs to pull bank transaction data.
//

import Foundation

// MARK: - Setu AA Data Models

struct SetuTokenResponse: Decodable {
    let access_token: String
    let token_type: String?
    let expires_in: Int?
}

struct SetuConsentResponse: Decodable {
    let id: String
    let url: String
    let status: String
    
    enum CodingKeys: String, CodingKey {
        case id, url, status
    }
}

struct SetuConsentStatusResponse: Decodable {
    let id: String
    let status: String
    let detail: ConsentDetail?
    
    struct ConsentDetail: Decodable {
        let consentStart: String?
        let consentExpiry: String?
    }
}

struct SetuSessionResponse: Decodable {
    let id: String
    let status: String
    let format: String?
}

struct SetuFIDataResponse: Codable {
    let id: String
    let status: String
    let Payload: [FIPayload]?
    
    struct FIPayload: Codable {
        let data: [FIData]?
        let fipID: String?
        let status: String?
    }
    
    struct FIData: Codable {
        let decryptedFI: DecryptedFI?
    }
    
    struct DecryptedFI: Codable {
        let account: AccountInfo?
    }
    
    struct AccountInfo: Codable {
        let linkedAccRef: String?
        let maskedAccNumber: String?
        let type: String?
        let summary: AccountSummary?
        let transactions: TransactionsWrapper?
        let profile: AccountProfile?
    }
    
    struct AccountSummary: Codable {
        let currentBalance: String?
        let currency: String?
        let branch: String?
        let balanceDateTime: String?
        let currentODLimit: String?
        let drawingLimit: String?
        let status: String?
        let pending: PendingAmount?
        let type: String?
    }
    
    struct PendingAmount: Codable {
        let amount: String?
        let transactionType: String?
    }
    
    struct AccountProfile: Codable {
        let holders: HoldersInfo?
    }
    
    struct HoldersInfo: Codable {
        let holder: [HolderDetail]?
        let type: String?
    }
    
    struct HolderDetail: Codable {
        let name: String?
        let dob: String?
        let mobile: String?
        let nominee: String?
        let landline: String?
        let address: String?
        let email: String?
        let pan: String?
        let ckycCompliance: String?
    }
    
    struct TransactionsWrapper: Codable {
        let transaction: [TransactionEntry]?
        let startDate: String?
        let endDate: String?
    }
    
    struct TransactionEntry: Codable {
        let txnId: String?
        let type: String?         // "CREDIT" or "DEBIT"
        let mode: String?         // "UPI", "NEFT", "SALARY", etc.
        let amount: String?
        let currentBalance: String?
        let transactionTimestamp: String?
        let valueDate: String?
        let narration: String?
        let reference: String?
    }
}

// MARK: - Analyzed Income Result

struct AnalyzedIncome {
    let monthlySalary: Double
    let averageMonthlyIncome: Double
    let averageMonthlyBalance: Double
    let totalCredits: Double
    let totalDebits: Double
    let salaryCreditsCount: Int
    let emiDebitsCount: Int
    let estimatedExistingEMIs: Double
    let bounceCount: Int
    let accountHolderName: String?
    let panNumber: String?
    let monthsAnalyzed: Int
    let incomeStability: IncomeStability
    
    enum IncomeStability: String {
        case stable = "Stable"
        case moderate = "Moderate"
        case unstable = "Unstable"
    }
}

// MARK: - Setu AA Service

@MainActor
class SetuAAService {
    
    static let shared = SetuAAService()
    private init() {}
    
    // MARK: - Setu Sandbox Credentials
    // These are sandbox credentials from the user's Setu Bridge dashboard
    private let clientID = "c611b744-fbbd-42d2-a817-171cbe9b36ac"
    private let clientSecret = "JTbuZo5gMAGukZvRq786LX8hmAcIRywy"
    private let baseURL = "https://orgservice-prod.setu.co"
    private let aaBaseURL = "https://fiu-sandbox.setu.co"  // Sandbox FIU URL
    
    private var accessToken: String?
    private var tokenExpiry: Date?
    
    // MARK: - Step 1: Get Access Token
    
    func getAccessToken() async throws -> String {
        // Return cached token if still valid
        if let token = accessToken, let expiry = tokenExpiry, Date() < expiry {
            return token
        }
        
        let url = URL(string: "\(baseURL)/v1/users/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("bridge", forHTTPHeaderField: "client")
        
        let body: [String: String] = [
            "clientID": clientID,
            "grant_type": "client_credentials",
            "secret": clientSecret
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? "No response"
            throw SetuError.authFailed("Token request failed (\(statusCode)): \(body)")
        }
        
        let tokenResponse = try JSONDecoder().decode(SetuTokenResponse.self, from: data)
        self.accessToken = tokenResponse.access_token
        self.tokenExpiry = Date().addingTimeInterval(Double(tokenResponse.expires_in ?? 1800))
        
        return tokenResponse.access_token
    }
    

    // MARK: - Step 3: Check Consent Status
    
    func getConsentStatus(consentId: String) async throws -> SetuConsentStatusResponse {
        let token = try await getAccessToken()
        
        let url = URL(string: "\(aaBaseURL)/v2/consents/\(consentId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(clientID, forHTTPHeaderField: "x-client-id")
        request.setValue(clientSecret, forHTTPHeaderField: "x-client-secret")
        request.setValue("48a7626f-69dc-47c4-a393-1a297660ac60", forHTTPHeaderField: "x-product-instance-id")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? "No response"
            throw SetuError.statusCheckFailed("Status check failed (\(statusCode)): \(body)")
        }
        
        return try JSONDecoder().decode(SetuConsentStatusResponse.self, from: data)
    }
    
    // MARK: - Step 4: Create Data Session (after consent approved)
    
    func createDataSession(consentId: String, fromDate: String, toDate: String) async throws -> SetuSessionResponse {
        let token = try await getAccessToken()
        
        let url = URL(string: "\(aaBaseURL)/v2/sessions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(clientID, forHTTPHeaderField: "x-client-id")
        request.setValue(clientSecret, forHTTPHeaderField: "x-client-secret")
        request.setValue("48a7626f-69dc-47c4-a393-1a297660ac60", forHTTPHeaderField: "x-product-instance-id")
        
        let sessionBody: [String: Any] = [
            "consentId": consentId,
            "dataRange": [
                "from": fromDate,
                "to": toDate
            ],
            "format": "json"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: sessionBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? "No response"
            throw SetuError.sessionFailed("Session creation failed (\(statusCode)): \(body)")
        }
        
        return try JSONDecoder().decode(SetuSessionResponse.self, from: data)
    }
    
    // MARK: - Step 5: Fetch Financial Data
    
    func fetchFIData(sessionId: String) async throws -> SetuFIDataResponse {
        let token = try await getAccessToken()
        
        let url = URL(string: "\(aaBaseURL)/v2/sessions/\(sessionId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(clientID, forHTTPHeaderField: "x-client-id")
        request.setValue(clientSecret, forHTTPHeaderField: "x-client-secret")
        request.setValue("48a7626f-69dc-47c4-a393-1a297660ac60", forHTTPHeaderField: "x-product-instance-id")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? "No response"
            throw SetuError.fetchFailed("FI data fetch failed (\(statusCode)): \(body)")
        }
        
        return try JSONDecoder().decode(SetuFIDataResponse.self, from: data)
    }
    
    // MARK: - Step 6: Analyze Transactions → Income Metrics
    
    func analyzeTransactions(_ fiData: SetuFIDataResponse) -> AnalyzedIncome {
        var allTransactions: [SetuFIDataResponse.TransactionEntry] = []
        var accountHolderName: String?
        var panNumber: String?
        
        // Extract transactions from all accounts
        for payload in fiData.Payload ?? [] {
            for dataItem in payload.data ?? [] {
                if let account = dataItem.decryptedFI?.account {
                    if let txns = account.transactions?.transaction {
                        allTransactions.append(contentsOf: txns)
                    }
                    if accountHolderName == nil {
                        accountHolderName = account.profile?.holders?.holder?.first?.name
                    }
                    if panNumber == nil {
                        panNumber = account.profile?.holders?.holder?.first?.pan
                    }
                }
            }
        }
        
        // Classify transactions
        let salaryKeywords = ["salary", "sal", "payroll", "wages", "stipend", "income"]
        let emiKeywords = ["emi", "loan", "instalment", "installment", "repayment"]
        let bounceKeywords = ["bounce", "return", "dishonour", "insufficient", "reversed"]
        
        var monthlySalaries: [String: Double] = [:]  // "YYYY-MM" -> salary
        var monthlyCredits: [String: Double] = [:]
        var totalCredits: Double = 0
        var totalDebits: Double = 0
        var salaryCount = 0
        var emiCount = 0
        var emiTotal: Double = 0
        var bounceCount = 0
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        for txn in allTransactions {
            let amount = Double(txn.amount ?? "0") ?? 0
            let narration = (txn.narration ?? "").lowercased()
            let txnType = (txn.type ?? "").uppercased()
            let timestamp = txn.transactionTimestamp ?? ""
            
            // Extract month key
            let monthKey = String(timestamp.prefix(7)) // "YYYY-MM"
            
            if txnType == "CREDIT" {
                totalCredits += amount
                monthlyCredits[monthKey, default: 0] += amount
                
                // Detect salary
                if salaryKeywords.contains(where: { narration.contains($0) }) || amount > 15000 {
                    salaryCount += 1
                    monthlySalaries[monthKey, default: 0] += amount
                }
            } else {
                totalDebits += amount
                
                // Detect EMIs
                if emiKeywords.contains(where: { narration.contains($0) }) {
                    emiCount += 1
                    emiTotal += amount
                }
                
                // Detect bounces
                if bounceKeywords.contains(where: { narration.contains($0) }) {
                    bounceCount += 1
                }
            }
        }
        
        let monthsAnalyzed = max(monthlyCredits.count, 1)
        
        // Calculate salary (use median of monthly salaries for stability)
        let sortedSalaries = monthlySalaries.values.sorted()
        let medianSalary: Double
        if sortedSalaries.isEmpty {
            medianSalary = totalCredits / Double(monthsAnalyzed)
        } else {
            let mid = sortedSalaries.count / 2
            medianSalary = sortedSalaries.count % 2 == 0
                ? (sortedSalaries[mid - 1] + sortedSalaries[mid]) / 2
                : sortedSalaries[mid]
        }
        
        // Average monthly balance (from credits - debits per month)
        let avgMonthlyIncome = totalCredits / Double(monthsAnalyzed)
        let avgMonthlyBalance = (totalCredits - totalDebits) / Double(monthsAnalyzed)
        
        // Existing EMI estimate
        let existingEMIs = emiCount > 0 ? emiTotal / Double(max(monthsAnalyzed, 1)) : 0
        
        // Income stability
        let salaryVariation: Double
        if sortedSalaries.count >= 2, let maxSal = sortedSalaries.last, let minSal = sortedSalaries.first, maxSal > 0 {
            salaryVariation = (maxSal - minSal) / maxSal
        } else {
            salaryVariation = 0
        }
        
        let stability: AnalyzedIncome.IncomeStability
        if salaryVariation < 0.1 && salaryCount >= monthsAnalyzed - 1 {
            stability = .stable
        } else if salaryVariation < 0.3 {
            stability = .moderate
        } else {
            stability = .unstable
        }
        
        return AnalyzedIncome(
            monthlySalary: medianSalary,
            averageMonthlyIncome: avgMonthlyIncome,
            averageMonthlyBalance: max(avgMonthlyBalance, 0),
            totalCredits: totalCredits,
            totalDebits: totalDebits,
            salaryCreditsCount: salaryCount,
            emiDebitsCount: emiCount,
            estimatedExistingEMIs: existingEMIs,
            bounceCount: bounceCount,
            accountHolderName: accountHolderName,
            panNumber: panNumber,
            monthsAnalyzed: monthsAnalyzed,
            incomeStability: stability
        )
    }
    
    // MARK: - Full Verification Flow (Convenience)
    
    func completeVerification(consentId: String) async throws -> AnalyzedIncome {
        // Check consent status
        let status = try await getConsentStatus(consentId: consentId)
        guard status.status.uppercased() == "APPROVED" || status.status.uppercased() == "ACTIVE" else {
            throw SetuError.consentNotApproved("Consent status: \(status.status). User must approve first.")
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
        let session = try await createDataSession(consentId: consentId, fromDate: fromDateStr, toDate: toDateStr)
        
        // Wait a moment for data to be ready, then fetch
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        
        let fiData = try await fetchFIData(sessionId: session.id)
        
        guard fiData.status.uppercased() == "COMPLETED" || fiData.status.uppercased() == "PARTIAL" else {
            throw SetuError.dataNotReady("Data session status: \(fiData.status). Try again shortly.")
        }
        
        // Dump FI Data for debugging
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(fiData) {
            try? data.write(to: URL(fileURLWithPath: "/Users/apple/Desktop/setu_fi_data.json"))
        }
        
        return analyzeTransactions(fiData)
    }
}

// MARK: - Errors

enum SetuError: LocalizedError {
    case authFailed(String)
    case consentFailed(String)
    case statusCheckFailed(String)
    case sessionFailed(String)
    case fetchFailed(String)
    case consentNotApproved(String)
    case dataNotReady(String)
    
    var errorDescription: String? {
        switch self {
        case .authFailed(let msg): return "Setu Auth: \(msg)"
        case .consentFailed(let msg): return "Consent: \(msg)"
        case .statusCheckFailed(let msg): return "Status: \(msg)"
        case .sessionFailed(let msg): return "Session: \(msg)"
        case .fetchFailed(let msg): return "Fetch: \(msg)"
        case .consentNotApproved(let msg): return msg
        case .dataNotReady(let msg): return msg
        }
    }
}
