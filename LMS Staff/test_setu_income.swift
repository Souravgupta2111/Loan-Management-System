import Foundation

// We will fetch the FI data using the Setu API just like the app does.
let consentId = "67537497-5c8c-457a-b205-4b2d29d78358"
let clientAPIKey = "c430e3bb-40dc-4a73-90d5-263a23cb9db4" // Mock API Key
let clientSecret = "c18f3a39-ec98-4c6e-8260-14e44f77242d"
let baseURL = "https://fiu-sandbox.setu.co/v2"

func getSessionToken() async throws -> String {
    let url = URL(string: "https://fiu-sandbox.setu.co/v2/sessions")!
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.addValue(clientAPIKey, forHTTPHeaderField: "x-client-id")
    req.addValue(clientSecret, forHTTPHeaderField: "x-client-secret")
    req.addValue("application/json", forHTTPHeaderField: "Content-Type")

    let (data, _) = try await URLSession.shared.data(for: req)
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let id = json["id"] as? String else {
        throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get session"])
    }
    return id
}

func fetchFIData() async {
    do {
        print("Getting session...")
        let token = try await getSessionToken()
        print("Session Token: \(token)")
        
        let url = URL(string: "https://fiu-sandbox.setu.co/v2/consents/\(consentId)/fi-data")!
        var req = URLRequest(url: url)
        req.addValue(clientAPIKey, forHTTPHeaderField: "x-client-id")
        req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: req)
        let str = String(data: data, encoding: .utf8) ?? ""
        print("Response: \(str.prefix(1000))...")
        
    } catch {
        print("Error: \(error)")
    }
}

let semaphore = DispatchSemaphore(value: 0)
Task {
    await fetchFIData()
    semaphore.signal()
}
semaphore.wait()
