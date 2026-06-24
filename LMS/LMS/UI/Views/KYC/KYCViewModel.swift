import SwiftUI
import Supabase
import Auth
import Combine

@MainActor
class KYCViewModel: ObservableObject {
    @Published var aadhaarNumber: String = ""
    @Published var panNumber: String = ""
    @Published var fullName: String = ""
    @Published var dob: String = ""
    
    // --- PAN separate states ---
    @Published var isPANLoading = false
    @Published var panVerificationStatus: String? = nil
    @Published var panErrorMessage: String? = nil
    @Published var isVerified = false  // PAN verified
    
    // --- Aadhaar separate states ---
    @Published var isAadhaarLoading = false
    @Published var aadhaarVerificationStatus: String? = nil
    @Published var aadhaarErrorMessage: String? = nil
    @Published var isAadhaarVerified = false
    @Published var isOTPSent = false
    @Published var aadhaarOTP: String = ""
    @Published var aadhaarReferenceId: String? = nil
    @Published var aadhaarVerifiedName: String? = nil
    
    @Published var addressProofData: Data? = nil
    @Published var selfieData: Data? = nil
    
    @Published var isSubmittingFullKYC = false
    @Published var kycStatus = "pending"
    @Published var rejectedDocuments: [String: String] = [:]
    
    // Legacy — used by rejected docs resubmission only
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    func refreshKYCStatus() async {
        guard let userId = SupabaseManager.shared.currentUserId else { return }
        struct StatusRow: Decodable { let kyc_status: String }
        do {
            let rows: [StatusRow] = try await SupabaseManager.shared.client
                .from("borrower_profiles").select("kyc_status")
                .eq("user_id", value: userId).execute().value
            kycStatus = rows.first?.kyc_status ?? "pending"
            
            if kycStatus == "rejected" {
                struct DocRow: Decodable {
                    let document_type: String
                    let rejection_reason: String?
                }
                let docRows: [DocRow] = try await SupabaseManager.shared.client
                    .from("documents")
                    .select("document_type, rejection_reason")
                    .eq("owner_id", value: userId)
                    .eq("category", value: "kyc")
                    .execute().value
                
                var rejected: [String: String] = [:]
                for doc in docRows {
                    if let reason = doc.rejection_reason, !reason.isEmpty {
                        rejected[doc.document_type] = reason
                    }
                }
                self.rejectedDocuments = rejected
            } else {
                self.rejectedDocuments = [:]
            }
        } catch {
            errorMessage = "Unable to refresh KYC status"
        }
    }
    
    // MARK: - PAN Verification
    
    func verifyPAN() async {
        let normalizedPAN = panNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let panPattern = "^[A-Z]{5}[0-9]{4}[A-Z]$"
        guard normalizedPAN.range(of: panPattern, options: .regularExpression) != nil,
              fullName.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2,
              dob.range(of: "^(0[1-9]|[12][0-9]|3[01])/(0[1-9]|1[0-2])/([0-9]{4})$", options: .regularExpression) != nil else {
            self.panErrorMessage = "Enter a valid PAN, full name, and DOB in DD/MM/YYYY format"
            return
        }
        
        isPANLoading = true
        panErrorMessage = nil
        
        do {
            let response = try await KYCService.shared.verifyPAN(normalizedPAN, name: fullName, dob: dob)
            if response.status.lowercased() == "valid" && response.nameAsPerPanMatch && response.dateOfBirthMatch {
                panNumber = normalizedPAN
                self.panVerificationStatus = "PAN Verified Successfully"
                self.isVerified = true
            } else {
                self.panErrorMessage = "PAN details could not be verified (Status: \(response.status))"
            }
        } catch {
            print("PAN Verification Error: \(error)")
            self.panErrorMessage = "Failed to verify PAN. Backend error: \(error.localizedDescription)"
        }
        
        isPANLoading = false
    }
    
    // MARK: - Aadhaar Verification (2-step OTP)
    
    func sendAadhaarOTP() async {
        guard isVerified else {
            self.aadhaarErrorMessage = "Please verify your PAN Card first"
            return
        }
        
        let normalizedAadhaar = aadhaarNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedAadhaar.count == 12, CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: normalizedAadhaar)) else {
            self.aadhaarErrorMessage = "Please enter a valid 12-digit Aadhaar Number"
            return
        }
        
        isAadhaarLoading = true
        aadhaarErrorMessage = nil
        
        do {
            let response = try await KYCService.shared.generateAadhaarOTP(normalizedAadhaar)
            if response.success, let refId = response.referenceId {
                self.aadhaarReferenceId = refId
                self.isOTPSent = true
                self.aadhaarVerificationStatus = "OTP sent to your Aadhaar-linked mobile"
            } else {
                self.aadhaarErrorMessage = response.error ?? "Failed to send OTP"
            }
        } catch {
            print("Aadhaar OTP Error: \(error)")
            self.aadhaarErrorMessage = "Failed to send OTP. \(error.localizedDescription)"
        }
        
        isAadhaarLoading = false
    }
    
    func verifyAadhaarOTP() async {
        guard let refId = aadhaarReferenceId else {
            self.aadhaarErrorMessage = "No OTP session found. Please send OTP again."
            return
        }
        let trimmedOTP = aadhaarOTP.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedOTP.count == 6, CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: trimmedOTP)) else {
            self.aadhaarErrorMessage = "Please enter the 6-digit OTP"
            return
        }
        
        isAadhaarLoading = true
        aadhaarErrorMessage = nil
        
        do {
            let response = try await KYCService.shared.verifyAadhaarOTP(referenceId: refId, otp: trimmedOTP)
            if response.success {
                self.aadhaarVerifiedName = response.name
                
                // Cross-check: PAN name vs Aadhaar name
                if let aadhaarName = response.name, !aadhaarName.isEmpty {
                    if !namesMatch(panName: fullName, aadhaarName: aadhaarName) {
                        self.aadhaarErrorMessage = "Name mismatch: PAN name (\(fullName)) does not match Aadhaar name (\(aadhaarName)). Both must belong to the same person."
                        self.isAadhaarVerified = false
                        isAadhaarLoading = false
                        return
                    }
                }
                
                self.aadhaarVerificationStatus = "Aadhaar Verified Successfully"
                self.isAadhaarVerified = true
            } else {
                self.aadhaarErrorMessage = response.error ?? "OTP verification failed"
            }
        } catch {
            print("Aadhaar Verify OTP Error: \(error)")
            self.aadhaarErrorMessage = "Failed to verify OTP. \(error.localizedDescription)"
        }
        
        isAadhaarLoading = false
    }
    
    // MARK: - Submit Full KYC
    
    func submitFullKYC(authViewModel: AuthViewModel) async {
        guard isAadhaarVerified else {
            self.aadhaarErrorMessage = "Please verify your Aadhaar Number first"
            return
        }
        
        guard let addressData = addressProofData, let selfie = selfieData else {
            self.errorMessage = "Please upload all required documents and capture a selfie"
            return
        }
        
        isSubmittingFullKYC = true
        errorMessage = nil
        
        do {
            if let userId = SupabaseManager.shared.currentUserId {
                let addressPath = try await KYCService.shared.uploadDocument(data: addressData, type: "address_proof", userId: userId.uuidString)
                try await KYCService.shared.recordDocument(userId: userId, type: "address_proof", storagePath: addressPath, byteCount: addressData.count)
                let selfiePath = try await KYCService.shared.uploadDocument(data: selfie, type: "selfie", userId: userId.uuidString)
                try await KYCService.shared.recordDocument(userId: userId, type: "selfie", storagePath: selfiePath, byteCount: selfie.count)
                
                try await KYCService.shared.submitFullKYCDocs(userId: userId, aadhaar: aadhaarNumber, pan: panNumber)
                kycStatus = "verified"
                authViewModel.checkSession()
            }
        } catch {
            self.errorMessage = "Failed to submit KYC. Please try again."
        }
        
        isSubmittingFullKYC = false
    }
    
    func resubmitDocument(type: String, data: Data) async {
        guard let userId = SupabaseManager.shared.currentUserId else { return }
        isLoading = true
        errorMessage = nil
        do {
            try await KYCService.shared.resubmitDocument(userId: userId, type: type, data: data)
            await refreshKYCStatus()
        } catch {
            errorMessage = "Failed to resubmit document. Please try again."
        }
        isLoading = false
    }
    
    // MARK: - Name Matching Helper
    
    /// Compares PAN-verified name with Aadhaar-verified name using normalized word overlap.
    /// Handles minor differences like middle names, initials, or ordering.
    private func namesMatch(panName: String, aadhaarName: String) -> Bool {
        let normalize: (String) -> Set<String> = { name in
            Set(
                name.lowercased()
                    .components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .punctuationCharacters) }
                    .filter { $0.count > 1 } // drop single-char initials
            )
        }
        let panWords = normalize(panName)
        let aadhaarWords = normalize(aadhaarName)
        
        guard !panWords.isEmpty, !aadhaarWords.isEmpty else { return false }
        
        let commonWords = panWords.intersection(aadhaarWords)
        let minCount = min(panWords.count, aadhaarWords.count)
        
        // Require at least half the words in the shorter name to match
        return Double(commonWords.count) / Double(minCount) >= 0.5
    }
}
