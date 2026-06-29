import Foundation
import Supabase

struct RazorpayOrder: Decodable, Identifiable {
    var id: String { orderId }
    let paymentRecordId: UUID
    let orderId: String
    let keyId: String
    let amountPaise: Int
    let currency: String
}

enum PaymentServiceError: LocalizedError {
    case checkoutSDKNotIntegrated

    var errorDescription: String? {
        switch self {
        case .checkoutSDKNotIntegrated:
            return "The Razorpay checkout SDK is not integrated yet. No payment was charged or marked paid."
        }
    }
}

@MainActor
final class PaymentService {
    static let shared = PaymentService()
    private init() {}

    /// Creates an authenticated, server-priced order without exposing the Razorpay secret.
    func createOrder(emiId: UUID, loanId: UUID) async throws -> RazorpayOrder {
        struct Payload: Encodable { let emiId: UUID; let loanId: UUID }
        return try await SupabaseManager.shared.client.functions.invoke(
            "create-razorpay-order",
            options: FunctionInvokeOptions(body: Payload(emiId: emiId, loanId: loanId))
        )
    }
}
