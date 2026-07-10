import LocalAuthentication
import Foundation

@MainActor
final class BiometricAuthService {
    static let shared = BiometricAuthService()
    
    private init() {}
    
    func canEvaluatePolicy() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    func authenticate(reason: String = "Log in to your LMS Staff account") async -> Bool {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }
        
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
        } catch {
            print("Biometric auth error: \(error.localizedDescription)")
            return false
        }
    }
}
