import SwiftUI
import Combine

@MainActor
final class StaffIntentRouter: ObservableObject {
    static let shared = StaffIntentRouter()

    enum Destination {
        case aiChat
        case applications
        case portfolio
        case npa
        case disbursements
    }

    @Published var pending: Destination?

    @Published var approvalTargetNumber: String?

    private var assistantPrefill: String?

    private init() {}

    func request(_ destination: Destination, prefill: String? = nil) {
        assistantPrefill = prefill
        pending = destination
    }

    func requestApproval(applicationNumber: String) {
        approvalTargetNumber = applicationNumber
        pending = .applications
    }

    func consumePrefill() -> String? {
        let value = assistantPrefill
        assistantPrefill = nil
        return value
    }
}
