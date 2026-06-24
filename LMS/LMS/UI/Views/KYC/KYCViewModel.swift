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
    
    @Published var isLoading = false
    @Published var verificationStatus: String? = nil
    @Published var errorMessage: String? = nil
    
    @Published var addressProofData: Data? = nil
    @Published var selfieData: Data? = nil
    
    @Published var isVerified = false
    @Published var isAadhaarVerified = false
    @Published var aadhaarVerificationStatus: String? = nil
    @Published var isSubmittingFullKYC = false
    @Published var kycStatus = "pending"
    @Published var rejectedDocuments: [String: String] = [:] // Document Type -> Reason

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
    
    func verifyPAN() async {
        let normalizedPAN = panNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let panPattern = "^[A-Z]{5}[0-9]{4}[A-Z]$"
        guard normalizedPAN.range(of: panPattern, options: .regularExpression) != nil,
              fullName.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2,
              dob.range(of: "^(0[1-9]|[12][0-9]|3[01])/(0[1-9]|1[0-2])/([0-9]{4})$", options: .regularExpression) != nil else {
            self.errorMessage = "Enter a valid PAN, full name, and DOB in DD/MM/YYYY format"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await KYCService.shared.verifyPAN(normalizedPAN, name: fullName, dob: dob)
            if response.status.lowercased() == "valid" && response.nameAsPerPanMatch && response.dateOfBirthMatch {
                panNumber = normalizedPAN
                self.verificationStatus = "PAN Verified Successfully"
                self.isVerified = true
            } else {
                self.errorMessage = "PAN details could not be verified (Status: \(response.status))"
            }
        } catch {
            print("PAN Verification Error: \(error)")
            self.errorMessage = "Failed to verify PAN. Backend error: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func verifyAadhaar() async {
        let normalizedAadhaar = aadhaarNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedAadhaar.count == 12, CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: normalizedAadhaar)) else {
            self.errorMessage = "Please enter a valid 12-digit Aadhaar Number"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await KYCService.shared.verifyAadhaar(normalizedAadhaar)
            if response.status.lowercased() == "valid" || response.status.lowercased() == "success" {
                self.aadhaarNumber = normalizedAadhaar
                self.aadhaarVerificationStatus = "Aadhaar Verified Successfully"
                self.isAadhaarVerified = true
            } else {
                self.errorMessage = "Aadhaar details could not be verified (Status: \(response.status))"
            }
        } catch {
            print("Aadhaar Verification Error: \(error)")
            self.errorMessage = "Failed to verify Aadhaar. Backend error: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func submitFullKYC(authViewModel: AuthViewModel) async {
        guard isAadhaarVerified else {
            self.errorMessage = "Please verify your Aadhaar Number first"
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
                // Upload real documents
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
            // Refresh status after successful resubmission
            await refreshKYCStatus()
        } catch {
            errorMessage = "Failed to resubmit document. Please try again."
        }
        isLoading = false
    }
}
