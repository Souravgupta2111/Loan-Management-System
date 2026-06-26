import Foundation

struct LoanSummary: Identifiable {
    let id: UUID
    let name: String
    let loanType: String
    let outstandingAmount: Double
    let emiAmount: Double
    let status: String
    let paidPercent: Double
    let changePercent: Double

    var icon: String {
        switch loanType.lowercased() {
        case "home":        return "house.fill"
        case "vehicle":     return "car.fill"
        case "business":    return "building.2.fill"
        case "education":   return "graduationcap.fill"
        case "personal":    return "person.fill"
        case "agriculture": return "leaf.fill"
        default:            return "indianrupeesign.circle.fill"
        }
    }
}
