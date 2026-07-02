import Foundation

let clientID = "c611b744-fbbd-42d2-a817-171cbe9b36ac"
let clientSecret = "JTbuZo5gMAGukZvRq786LX8hmAcIRywy"
let baseURL = "https://orgservice-prod.setu.co"
let aaBaseURL = "https://fiu-sandbox.setu.co"

func test() async throws {
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
    
    print("Token: \(token.prefix(10))...")
    
    // Now create a consent just to see its format when we fetch it
    let createUrl = URL(string: "\(aaBaseURL)/v2/consents")!
    var req2 = URLRequest(url: createUrl)
    req2.httpMethod = "POST"
    req2.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req2.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    req2.setValue(clientID, forHTTPHeaderField: "x-client-id")
    req2.setValue(clientSecret, forHTTPHeaderField: "x-client-secret")
    req2.setValue("48a7626f-69dc-47c4-a393-1a297660ac60", forHTTPHeaderField: "x-product-instance-id")
    
    let now = Date()
    let calendar = Calendar.current
    let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: now)!
    let isoFormatter = ISO8601DateFormatter()
    isoFormatter.formatOptions = [.withInternetDateTime]
    
    let consentBody: [String: Any] = [
        "consentDuration": ["unit": "MONTH", "value": 12],
        "vua": "9999999999@onemoney",
        "dataRange": ["from": isoFormatter.string(from: oneYearAgo), "to": isoFormatter.string(from: now)],
        "context": [["key": "accounttype", "value": "SAVINGS"]],
        "fiTypes": ["DEPOSIT"],
        "consentMode": "STORE",
        "fetchType": "ONETIME",
        "frequency": ["value": 1, "unit": "MONTH"],
        "dataFilter": [["type": "TRANSACTIONAMOUNT", "operator": ">=", "value": "1"]],
        "dataLife": ["value": 1, "unit": "MONTH"],
        "purpose": ["category": ["type": "string"], "code": "103", "refUri": "https://api.rebit.org.in/aa/purpose/103.xml", "text": "test"],
        "redirectUrl": "https://setu.co"
    ]
    req2.httpBody = try JSONSerialization.data(withJSONObject: consentBody)
    let (data2, _) = try await URLSession.shared.data(for: req2)
    let json2 = try JSONSerialization.jsonObject(with: data2) as! [String: Any]
    print("Consent Response:", json2)
    
    let consentId = json2["id"] as! String
    
    // Fetch consent status
    let statusUrl = URL(string: "\(aaBaseURL)/v2/consents/\(consentId)")!
    var req3 = URLRequest(url: statusUrl)
    req3.httpMethod = "GET"
    req3.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    req3.setValue(clientID, forHTTPHeaderField: "x-client-id")
    req3.setValue(clientSecret, forHTTPHeaderField: "x-client-secret")
    req3.setValue("48a7626f-69dc-47c4-a393-1a297660ac60", forHTTPHeaderField: "x-product-instance-id")
    
    let (data3, _) = try await URLSession.shared.data(for: req3)
    if let str = String(data: data3, encoding: .utf8) {
        print("Status JSON:", str)
    }
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
