import Foundation

let url = URL(string: "http://localhost:54321/rest/v1/borrower_profiles?aa_consent_id=eq.67537497-5c8c-457a-b205-4b2d29d78358&select=monthly_income,verified_annual_income,income_verified")!
var request = URLRequest(url: url)
request.httpMethod = "GET"
request.addValue("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRlZmF1bHQiLCJyb2xlIjoiYW5vbiIsImlhdCI6MTY3MDUxMzI0MywiZXhwIjoxOTg2MDgzMjQzfQ.F9Rz2HwL824jYg1rE5L2z5yv5uS-g8w7aB-P12TqC_8", forHTTPHeaderField: "apikey")
request.addValue("Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRlZmF1bHQiLCJyb2xlIjoiYW5vbiIsImlhdCI6MTY3MDUxMzI0MywiZXhwIjoxOTg2MDgzMjQzfQ.F9Rz2HwL824jYg1rE5L2z5yv5uS-g8w7aB-P12TqC_8", forHTTPHeaderField: "Authorization")

let semaphore = DispatchSemaphore(value: 0)
Task {
    let (data, _) = try await URLSession.shared.data(for: request)
    print(String(data: data, encoding: .utf8) ?? "")
    semaphore.signal()
}
semaphore.wait()
