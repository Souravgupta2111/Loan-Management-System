import Foundation

let clientID = "c611b744-fbbd-42d2-a817-171cbe9b36ac"
let clientSecret = "JTbuZo5gMAGukZvRq786LX8hmAcIRywy"
let baseURL = "https://orgservice-prod.setu.co"
let aaBaseURL = "https://fiu-sandbox.setu.co"

func test() async throws {
    let consentId = "67537497-5c8c-457a-b205-4b2d29d78358"

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
    
    let (data, _) = try await URLSession.shared.data(for: request)
    let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    let token = json["access_token"] as! String
    
    print("Token OK")
    
    // Status
    let statusUrl = URL(string: "\(aaBaseURL)/v2/consents/\(consentId)")!
    var req3 = URLRequest(url: statusUrl)
    req3.httpMethod = "GET"
    req3.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    req3.setValue(clientID, forHTTPHeaderField: "x-client-id")
    req3.setValue(clientSecret, forHTTPHeaderField: "x-client-secret")
    req3.setValue("48a7626f-69dc-47c4-a393-1a297660ac60", forHTTPHeaderField: "x-product-instance-id")
    
    let (data3, _) = try await URLSession.shared.data(for: req3)
    let statusJson = try JSONSerialization.jsonObject(with: data3) as! [String: Any]
    print("Status:", statusJson["status"] ?? "nil")
    let detail = statusJson["detail"] as? [String: Any]
    let consentStart = detail?["consentStart"] as? String ?? ""
    print("Consent Start:", consentStart)
    
    if (statusJson["status"] as? String ?? "").uppercased() != "APPROVED" && (statusJson["status"] as? String ?? "").uppercased() != "ACTIVE" {
        print("Not approved!")
        return
    }

    let isoFormatter = ISO8601DateFormatter()
    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    
    var toDate = Date()
    if let parsed = isoFormatter.date(from: consentStart) {
        toDate = parsed
    } else {
        let formatterWithoutFractional = ISO8601DateFormatter()
        formatterWithoutFractional.formatOptions = [.withInternetDateTime]
        if let parsed = formatterWithoutFractional.date(from: consentStart) {
            toDate = parsed
        }
    }
    
    let safeToDate = Calendar.current.date(byAdding: .day, value: -1, to: toDate)!
    let safeFromDate = Calendar.current.date(byAdding: .month, value: -11, to: safeToDate)!
    
    let formatterForSession = ISO8601DateFormatter()
    formatterForSession.formatOptions = [.withInternetDateTime]
    let fromDateStr = formatterForSession.string(from: safeFromDate)
    let toDateStr = formatterForSession.string(from: safeToDate)

    print("From: \(fromDateStr), To: \(toDateStr)")

    // Create session
    let sUrl = URL(string: "\(aaBaseURL)/v2/sessions")!
    var req4 = URLRequest(url: sUrl)
    req4.httpMethod = "POST"
    req4.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req4.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    req4.setValue(clientID, forHTTPHeaderField: "x-client-id")
    req4.setValue(clientSecret, forHTTPHeaderField: "x-client-secret")
    req4.setValue("48a7626f-69dc-47c4-a393-1a297660ac60", forHTTPHeaderField: "x-product-instance-id")
    
    let sessionBody: [String: Any] = [
        "consentId": consentId,
        "dataRange": ["from": fromDateStr, "to": toDateStr],
        "format": "json"
    ]
    req4.httpBody = try JSONSerialization.data(withJSONObject: sessionBody)
    let (data4, response4) = try await URLSession.shared.data(for: req4)
    let sJson = try JSONSerialization.jsonObject(with: data4) as! [String: Any]
    print("Session:", sJson)
    let sessionId = sJson["id"] as? String ?? ""

    try await Task.sleep(nanoseconds: 3_000_000_000)

    // Fetch FI data
    let fUrl = URL(string: "\(aaBaseURL)/v2/sessions/\(sessionId)")!
    var req5 = URLRequest(url: fUrl)
    req5.httpMethod = "GET"
    req5.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    req5.setValue(clientID, forHTTPHeaderField: "x-client-id")
    req5.setValue(clientSecret, forHTTPHeaderField: "x-client-secret")
    req5.setValue("48a7626f-69dc-47c4-a393-1a297660ac60", forHTTPHeaderField: "x-product-instance-id")
    
    let (data5, _) = try await URLSession.shared.data(for: req5)
    let fiStr = String(data: data5, encoding: .utf8) ?? ""
    print("FI Data Payload preview:")
    print(fiStr.prefix(2000))
}

Task {
    do {
        try await test()
    } catch {
        print(error)
    }
    exit(0)
}
RunLoop.main.run()
