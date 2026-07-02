import Foundation
let str = "2026-07-01T20:12:55.511Z"
let isoFormatter = ISO8601DateFormatter()
isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
if let d = isoFormatter.date(from: str) {
    print("Parsed:", d)
} else {
    print("Failed to parse")
}
