import Foundation

/// A flexible decoder for JSON values that may be String, Number, or Bool.
/// Used when a database JSONB field stores mixed types.
enum AnyCodableValue: Decodable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let i = try? container.decode(Int.self) {
            self = .int(i)
        } else if let d = try? container.decode(Double.self) {
            self = .double(d)
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else {
            self = .string("")
        }
    }

    /// Converts any variant to its String representation
    var stringValue: String {
        switch self {
        case .string(let s): return s
        case .int(let i): return String(i)
        case .double(let d):
            // Format without trailing .0 for whole numbers
            if d == d.rounded() && d < 1e15 {
                return String(Int(d))
            }
            return String(d)
        case .bool(let b): return b ? "true" : "false"
        }
    }
}
