import SwiftUI
import Supabase
import UIKit
import ActivityKit

struct EMIScheduleView: View {
    @Environment(\.dismiss) private var dismiss
    let loanId: UUID
    
    @State private var processingEMIId: UUID? = nil
    @State private var paymentSuccess = false
    @State private var paymentError: String?
    @State private var emiList: [EMIDetail] = []
    @State private var isLoading = true
    @State private var loadError: String? = nil
    @State private var activeRazorpayOrder: RazorpayOrder? = nil
    @State private var paymentActivity: Activity<PaymentActivityAttributes>? = nil
    
    var body: some View {
        ZStack {
                LinearGradient(
                    colors: [Color.gradientMintStart, Color.gradientMintEnd, Color.gradientMintStart],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
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
                                if let loadError {
                                    VStack(spacing: Spacing.md) {
                                        Image(systemName: "exclamationmark.triangle")
                                            .font(.title2)
                                            .foregroundColor(.accentRed)
                                            .accessibilityHidden(true)
                                        Text("Couldn't load your EMI schedule")
                                            .font(.bodyLarge)
                                            .foregroundColor(.textPrimary)
                                        Text(loadError)
                                            .font(.bodyRegular)
                                            .foregroundColor(.textSecondary)
                                            .multilineTextAlignment(.center)
                                        Button("Retry") {
                                            Task { await fetchEMIs() }
                                        }
                                        .font(.bodyRegular.weight(.semibold))
                                        .padding(.horizontal, Spacing.xl)
                                        .padding(.vertical, Spacing.sm)
                                        .background(Color.accentGreen)
                                        .foregroundColor(.white)
                                        .clipShape(Capsule())
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, Spacing.xl)
                                } else if emiList.isEmpty {
                                    Text("No EMI schedule found.")
                                        .foregroundColor(.textSecondary)
                                } else {
                                    ForEach($emiList) { $emi in
                                        let shouldShowPayNow = emi.status == .overdue || emi.status == .due
                                        EMIRow(emi: emi, isProcessing: processingEMIId == emi.id, showPayNow: shouldShowPayNow) {
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
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    GlassBackButton {
                        dismiss()
                    }
                }
            }
            .navigationTitle("EMI Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await fetchEMIs()
            }
            .sheet(item: $activeRazorpayOrder) { order in
                                NavigationStack {
                                    RazorpayWebView(
                                        keyId: order.keyId,
                                        amountPaise: order.amountPaise,
                                        orderId: order.orderId,
                                        onSuccess: { paymentId, _, signature in
                                            activeRazorpayOrder = nil
                                            Task {
                                                await confirmPayment(paymentRecordId: order.paymentRecordId, razorpayPaymentId: paymentId, razorpaySignature: signature)
                                            }
                                        },
                                        onFailure: { errorMsg in
                                            activeRazorpayOrder = nil
                                            paymentError = errorMsg
                                            Task { await PaymentLiveActivity.fail(paymentActivity, message: "Payment failed"); paymentActivity = nil }
                                            processingEMIId = nil
                                        },
                                        onCancel: {
                                            activeRazorpayOrder = nil
                                            Task { await PaymentLiveActivity.fail(paymentActivity, message: "Payment cancelled"); paymentActivity = nil }
                                            processingEMIId = nil
                                        }
                                    )
                                    .navigationBarBackButtonHidden(true)
                                    .navigationTitle("Pay EMI")
                                    .navigationBarTitleDisplayMode(.inline)
                                    .toolbar {
                                        ToolbarItem(placement: .navigationBarLeading) {
                                            Button("Cancel") {
                                                activeRazorpayOrder = nil
                                                Task { await PaymentLiveActivity.fail(paymentActivity, message: "Payment cancelled"); paymentActivity = nil }
                                                processingEMIId = nil
                                            }
                                        }
                                    }
                                }
                                .interactiveDismissDisabled(true)
                            }
    }
    
    private func startPaymentFlow(for emi: EMIDetail) async {
        processingEMIId = emi.id
        paymentError = nil
        paymentSuccess = false
        
        do {
            let order = try await PaymentService.shared.createOrder(emiId: emi.id, loanId: loanId)
            activeRazorpayOrder = order
            // Start a Live Activity so the payment shows in the Dynamic Island / lock screen.
            paymentActivity = PaymentLiveActivity.start(title: "EMI Payment", amount: emi.amount)
        } catch {
            paymentError = "Failed to initiate payment: \(error.localizedDescription)"
            processingEMIId = nil
        }
    }
    
    private func confirmPayment(paymentRecordId: UUID, razorpayPaymentId: String, razorpaySignature: String) async {
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
            // Proactively announce success for VoiceOver users.
            UIAccessibility.post(notification: .announcement, argument: "Payment successful. Your EMI has been paid.")
            await PaymentLiveActivity.confirm(paymentActivity)
            paymentActivity = nil
            await fetchEMIs()
        } catch {
            paymentError = "Payment succeeded on Razorpay, but failed to record in system: \(error.localizedDescription)"
            await PaymentLiveActivity.fail(paymentActivity, message: "Couldn't record payment")
            paymentActivity = nil
        }
        
        processingEMIId = nil
    }
    
    private func fetchEMIs() async {
        isLoading = true
        loadError = nil
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
            
            if schedule.isEmpty {
                emiList = []
                isLoading = false
                return
            }
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            
            var mappedList = schedule.map { s in
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
                } else if s.status == "due" {
                    emiStatus = .due
                } else if s.status == "written_off" {
                    // Written-off installments are settled by the institution;
                    // never show a Pay Now button for them.
                    emiStatus = .scheduled
                } else {
                    emiStatus = .upcoming
                }
                
                return EMIDetail(
                    id: s.id, date: dateStr, amount: s.total_emi + s.penalty_amount,
                    principal: s.principal_component, interest: s.interest_component,
                    penalty: s.penalty_amount, status: emiStatus
                )
            }
            
            if let firstUpcomingIdx = mappedList.firstIndex(where: { $0.status == .upcoming }) {
                var shouldUnlock = false
                if firstUpcomingIdx == 0 {
                    shouldUnlock = true
                } else {
                    if let prevDate = formatter.date(from: String(schedule[firstUpcomingIdx - 1].due_date.prefix(10))) {
                        let today = Calendar.current.startOfDay(for: Date())
                        let prevEmiDay = Calendar.current.startOfDay(for: prevDate)
                        if today > prevEmiDay {
                            shouldUnlock = true
                        }
                    } else {
                        shouldUnlock = true
                    }
                }
                
                if shouldUnlock {
                    mappedList[firstUpcomingIdx].status = .due
                }
            }
            
            // Post-process to distinguish first upcoming from scheduled
            var hasFoundFirstUpcoming = false
            for idx in 0..<mappedList.count {
                if mappedList[idx].status == .upcoming {
                    if !hasFoundFirstUpcoming {
                        mappedList[idx].status = .upcoming
                        hasFoundFirstUpcoming = true
                    } else {
                        mappedList[idx].status = .scheduled
                    }
                }
            }
            
            emiList = mappedList
            isLoading = false
        } catch {
            print("Failed to fetch EMIs: \(error)")
            emiList = []
            loadError = "Please check your connection and try again."
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
        case due
        case upcoming
        case scheduled
        case overdue
    }
}

struct EMIRow: View {
    let emi: EMIDetail
    let isProcessing: Bool
    let showPayNow: Bool
    let onPay: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(emi.date)
                    .font(.bodyRegular)
                    .foregroundColor(.textSecondary)
                
                if emi.status == .overdue {
                    Text(statusText)
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentRed)
                        .clipShape(Capsule())
                } else {
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(statusColor)
                }

                Text("Principal ₹\(Int(emi.principal)) • Interest ₹\(Int(emi.interest))")
                    .font(.caption2)
                    .foregroundColor(.textSecondary)
                if emi.penalty > 0 {
                    Text("Penalty ₹\(Int(emi.penalty))")
                        .font(.caption2)
                        .foregroundColor(.accentRed)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "EMI due \(emi.date). \(statusText). Principal ₹\(Int(emi.principal)), interest ₹\(Int(emi.interest))"
                + (emi.penalty > 0 ? ", penalty ₹\(Int(emi.penalty))" : "")
            )
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: Spacing.sm) {
                Text("₹\(Int(emi.amount))")
                    .font(.cardTitle)
                    .foregroundColor(.textPrimary)
                    .accessibilityLabel("Total amount ₹\(Int(emi.amount))")
                
                if emi.status != .paid {
                    if isProcessing {
                        ProgressView()
                            .tint(.accentGreen)
                            .accessibilityLabel("Processing payment")
                    } else if showPayNow {
                        Button("PAY NOW") {
                            onPay()
                        }
                        .font(.caption)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)
                        .background(Color.accentGreen)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .accessibilityLabel("Pay now")
                        .accessibilityHint("Pays the EMI of ₹\(Int(emi.amount)) due \(emi.date)")
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .background(
            emi.status == .overdue ? Color.accentRed.opacity(0.05) :
            (emi.status == .upcoming || emi.status == .due) ? Color.accentGreenBg : Color.clear
        )
        .liquidGlass(cornerRadius: 20)
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    emi.status == .overdue ? Color.accentRed.opacity(0.3) :
                    (emi.status == .upcoming || emi.status == .due) ? Color.accentGreen.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
        .opacity(emi.status == .paid ? 0.6 : 1.0)
    }
    
    private var statusText: String {
        switch emi.status {
        case .paid: return "PAID"
        case .due: return "DUE NOW"
        case .upcoming: return "UPCOMING"
        case .scheduled: return "SCHEDULED"
        case .overdue: return "OVERDUE"
        }
    }
    
    private var statusColor: Color {
        switch emi.status {
        case .paid: return .accentGreen
        case .due: return Color(hex: "#D97706") // amber
        case .upcoming: return .textSecondary
        case .scheduled: return .textSecondary
        case .overdue: return .accentRed
        }
    }
}
