import SwiftUI
import Supabase

struct EMIScheduleView: View {
    let loanId: UUID
    
    @State private var isProcessingPayment = false
    @State private var paymentSuccess = false
    @State private var paymentError: String?
    @State private var emiList: [EMIDetail] = []
    @State private var isLoading = true
    @State private var showRazorpaySheet = false
    @State private var activeRazorpayOrder: RazorpayOrder? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: Spacing.xl) {
                            if paymentSuccess {
                                VStack(spacing: Spacing.md) {
                                    HStack {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundColor(.accentGreen)
                                            .font(.title2)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Payment Successful")
                                                .font(.bodyLarge)
                                                .foregroundColor(.textPrimary)
                                            Text("Your EMI has been paid.")
                                                .font(.bodyRegular)
                                                .foregroundColor(.textSecondary)
                                        }
                                        Spacer()
                                    }
                                }
                                .padding(Spacing.lg)
                                .background(Color.accentGreenBg)
                                .clipShape(RoundedRectangle(cornerRadius: Corner.xl))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Corner.xl)
                                        .strokeBorder(Color.accentGreen.opacity(0.3), lineWidth: 1)
                                )
                            }

                            if let paymentError {
                                Text(paymentError)
                                    .font(.bodyRegular)
                                    .foregroundColor(.accentRed)
                                    .padding(Spacing.lg)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.accentRedBg)
                                    .clipShape(RoundedRectangle(cornerRadius: Corner.lg))
                            }
                            
                            VStack(spacing: Spacing.md) {
                                if emiList.isEmpty {
                                    Text("No EMI schedule found.")
                                        .foregroundColor(.textSecondary)
                                } else {
                                    ForEach($emiList) { $emi in
                                        EMIRow(emi: emi, isProcessing: $isProcessingPayment) {
                                            Task {
                                                await startPaymentFlow(for: emi)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(Spacing.xl)
                    }
                }
            }
            .navigationTitle("EMI Schedule")
            .task {
                await fetchEMIs()
            }
            .sheet(isPresented: $showRazorpaySheet) {
                if let order = activeRazorpayOrder {
                    NavigationStack {
                        RazorpayWebView(
                            keyId: order.keyId,
                            amountPaise: order.amountPaise,
                            orderId: order.orderId,
                            onSuccess: { paymentId, _, signature in
                                showRazorpaySheet = false
                                Task {
                                    await confirmPayment(paymentRecordId: order.paymentRecordId, razorpayPaymentId: paymentId, razorpaySignature: signature)
                                }
                            },
                            onFailure: { errorMsg in
                                showRazorpaySheet = false
                                paymentError = errorMsg
                            },
                            onCancel: {
                                showRazorpaySheet = false
                            }
                        )
                        .navigationTitle("Pay EMI")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Cancel") {
                                    showRazorpaySheet = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func startPaymentFlow(for emi: EMIDetail) async {
        isProcessingPayment = true
        paymentError = nil
        paymentSuccess = false
        
        do {
            let order = try await PaymentService.shared.createOrder(emiId: emi.id, loanId: loanId)
            activeRazorpayOrder = order
            showRazorpaySheet = true
        } catch {
            paymentError = "Failed to initiate payment: \(error.localizedDescription)"
        }
        
        isProcessingPayment = false
    }
    
    private func confirmPayment(paymentRecordId: UUID, razorpayPaymentId: String, razorpaySignature: String) async {
        isProcessingPayment = true
        paymentError = nil
        
        do {
            try await SupabaseManager.shared.client
                .from("payments")
                .update([
                    "status": "confirmed",
                    "razorpay_payment_id": razorpayPaymentId,
                    "razorpay_signature": razorpaySignature
                ])
                .eq("id", value: paymentRecordId)
                .execute()
            
            paymentSuccess = true
            await fetchEMIs()
        } catch {
            paymentError = "Payment succeeded on Razorpay, but failed to record in system: \(error.localizedDescription)"
        }
        
        isProcessingPayment = false
    }
    
    private func fetchEMIs() async {
        do {
            struct EMIFetch: Decodable {
                let id: UUID
                let due_date: String
                let total_emi: Double
                let principal_component: Double
                let interest_component: Double
                let penalty_amount: Double
                let status: String
            }
            let schedule: [EMIFetch] = try await SupabaseManager.shared.client
                .from("emi_schedule")
                .select()
                .eq("loan_id", value: loanId)
                .order("due_date", ascending: true)
                .execute()
                .value
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            
            emiList = schedule.map { s in
                let dateStr: String
                if let d = formatter.date(from: String(s.due_date.prefix(10))) {
                    dateStr = displayFormatter.string(from: d)
                } else {
                    dateStr = s.due_date
                }
                
                let emiStatus: EMIDetail.EMIStatus
                if s.status == "paid" {
                    emiStatus = .paid
                } else if s.status == "overdue" {
                    emiStatus = .overdue
                } else {
                    emiStatus = .upcoming
                }
                
                return EMIDetail(
                    id: s.id, date: dateStr, amount: s.total_emi + s.penalty_amount,
                    principal: s.principal_component, interest: s.interest_component,
                    penalty: s.penalty_amount, status: emiStatus
                )
            }
            isLoading = false
        } catch {
            print("Failed to fetch EMIs: \(error)")
            isLoading = false
        }
    }
}

struct EMIDetail: Identifiable {
    let id: UUID
    let date: String
    let amount: Double
    let principal: Double
    let interest: Double
    let penalty: Double
    var status: EMIStatus
    
    enum EMIStatus {
        case paid
        case upcoming
        case overdue
    }
}

struct EMIRow: View {
    let emi: EMIDetail
    @Binding var isProcessing: Bool
    let onPay: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(emi.date)
                    .font(.bodyRegular)
                    .foregroundColor(.textSecondary)
                
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(statusColor)

                Text("Principal ₹\(Int(emi.principal)) • Interest ₹\(Int(emi.interest))")
                    .font(.caption2)
                    .foregroundColor(.textSecondary)
                if emi.penalty > 0 {
                    Text("Penalty ₹\(Int(emi.penalty))")
                        .font(.caption2)
                        .foregroundColor(.accentRed)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: Spacing.sm) {
                Text("₹\(Int(emi.amount))")
                    .font(.cardTitle)
                    .foregroundColor(.textPrimary)
                
                if emi.status != .paid {
                    if isProcessing {
                        ProgressView()
                            .tint(.accentGreen)
                    } else {
                        Button("PAY NOW") {
                            onPay()
                        }
                        .font(.caption)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)
                        .background(Color.accentGreen)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Corner.xl))
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
        .opacity(emi.status == .paid ? 0.6 : 1.0)
    }
    
    private var statusText: String {
        switch emi.status {
        case .paid: return "PAID"
        case .upcoming: return "UPCOMING"
        case .overdue: return "OVERDUE"
        }
    }
    
    private var statusColor: Color {
        switch emi.status {
        case .paid: return .accentGreen
        case .upcoming: return .textSecondary
        case .overdue: return .accentRed
        }
    }
}
