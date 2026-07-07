//
//  BiometricAuthService.swift
//  LMS
//
//  Handles LocalAuthentication (Face ID / Touch ID)
//

import LocalAuthentication
import Foundation

@MainActor
final class BiometricAuthService {
    static let shared = BiometricAuthService()
    
    private init() {}
    
    /// Checks if the device supports biometric authentication
    func canEvaluatePolicy() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    /// Authenticates the user using biometrics
    func authenticate(reason: String = "Log in to your LMS account") async -> Bool {
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
