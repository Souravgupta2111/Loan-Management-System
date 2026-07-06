import SwiftUI
import Supabase

struct EMIScheduleView: View {
    @Environment(\.dismiss) private var dismiss
    let loanId: UUID
    
    @State private var isProcessingPayment = false
    @State private var paymentSuccess = false
    @State private var paymentError: String?
    @State private var emiList: [EMIDetail] = []
    @State private var isLoading = true
    @State private var activeRazorpayOrder: RazorpayOrder? = nil
    
    var body: some View {
        ZStack {
                LinearGradient(
                    colors: [Color(hex: "#E7EFE5"), Color(hex: "#EFF4EA"), Color(hex: "#E7EFE5")],
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
                                if emiList.isEmpty {
                                    Text("No EMI schedule found.")
                                        .foregroundColor(.textSecondary)
                                } else {
                                    ForEach($emiList) { $emi in
                                        let shouldShowPayNow = emi.status == .overdue || emi.status == .due
                                        EMIRow(emi: emi, isProcessing: $isProcessingPayment, showPayNow: shouldShowPayNow) {
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
            .navigationTitle("EMI Schedule")
            .navigationBarTitleDisplayMode(.large)
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
                        },
                        onCancel: {
                            activeRazorpayOrder = nil
                        }
                    )
                    .navigationBarBackButtonHidden(true)
                    .navigationTitle("Pay EMI")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                activeRazorpayOrder = nil
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
            
            if schedule.isEmpty {
                emiList = getDummyEMIs(for: loanId)
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
            emiList = mappedList
            isLoading = false
        } catch {
            print("Failed to fetch EMIs: \(error)")
            emiList = getDummyEMIs(for: loanId)
            isLoading = false
        }
    }
    
    private func getDummyEMIs(for loanId: UUID) -> [EMIDetail] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        let now = Date()
        var list: [EMIDetail] = []
        
        if loanId == UUID(uuidString: "11111111-1111-1111-1111-111111111111") {
            // Home Loan
            for i in -5...6 {
                let dueDate = Calendar.current.date(byAdding: .month, value: i, to: now) ?? now
                let dateStr = formatter.string(from: dueDate)
                let isPaid = i < 0
                let isOverdue = i == 0
                let status: EMIDetail.EMIStatus = isPaid ? .paid : (isOverdue ? .overdue : .upcoming)
                list.append(EMIDetail(
                    id: UUID(),
                    date: dateStr,
                    amount: 38500.0 + (isOverdue ? 500.0 : 0.0),
                    principal: 28500.0,
                    interest: 10000.0,
                    penalty: isOverdue ? 500.0 : 0.0,
                    status: status
                ))
            }
        } else if loanId == UUID(uuidString: "22222222-2222-2222-2222-222222222222") {
            // Vehicle Loan
            for i in -5...6 {
                let dueDate = Calendar.current.date(byAdding: .month, value: i, to: now) ?? now
                let dateStr = formatter.string(from: dueDate)
                let isPaid = i < 0
                let status: EMIDetail.EMIStatus = isPaid ? .paid : .upcoming
                list.append(EMIDetail(
                    id: UUID(),
                    date: dateStr,
                    amount: 16200.0,
                    principal: 12200.0,
                    interest: 4000.0,
                    penalty: 0.0,
                    status: status
                ))
            }
        } else if loanId == UUID(uuidString: "33333333-3333-3333-3333-333333333333") {
            // Personal Loan (Closed)
            for i in -12...(-1) {
                let dueDate = Calendar.current.date(byAdding: .month, value: i, to: now) ?? now
                let dateStr = formatter.string(from: dueDate)
                list.append(EMIDetail(
                    id: UUID(),
                    date: dateStr,
                    amount: 9500.0,
                    principal: 8000.0,
                    interest: 1500.0,
                    penalty: 0.0,
                    status: .paid
                ))
            }
        } else if loanId == UUID(uuidString: "44444444-4444-4444-4444-444444444444") {
            // Education Loan
            for i in -1...10 {
                let dueDate = Calendar.current.date(byAdding: .month, value: i, to: now) ?? now
                let dateStr = formatter.string(from: dueDate)
                let isPaid = i < 0
                let status: EMIDetail.EMIStatus = isPaid ? .paid : .upcoming
                list.append(EMIDetail(
                    id: UUID(),
                    date: dateStr,
                    amount: 14500.0,
                    principal: 11000.0,
                    interest: 3500.0,
                    penalty: 0.0,
                    status: status
                ))
            }
        } else {
            // Generic fallback
            for i in 1...6 {
                let dueDate = Calendar.current.date(byAdding: .month, value: i, to: now) ?? now
                let dateStr = formatter.string(from: dueDate)
                list.append(EMIDetail(
                    id: UUID(),
                    date: dateStr,
                    amount: 5000.0,
                    principal: 4000.0,
                    interest: 1000.0,
                    penalty: 0.0,
                    status: .upcoming
                ))
            }
        }
        if let firstUpcomingIdx = list.firstIndex(where: { $0.status == .upcoming }) {
            var shouldUnlock = false
            if firstUpcomingIdx == 0 {
                shouldUnlock = true
            } else {
                if let prevDate = formatter.date(from: list[firstUpcomingIdx - 1].date) {
                    let today = Calendar.current.startOfDay(for: now)
                    let prevEmiDay = Calendar.current.startOfDay(for: prevDate)
                    if today > prevEmiDay {
                        shouldUnlock = true
                    }
                } else {
                    shouldUnlock = true
                }
            }
            
            if shouldUnlock {
                list[firstUpcomingIdx].status = .due
            }
        }
        
        return list
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
        case overdue
    }
}

struct EMIRow: View {
    let emi: EMIDetail
    @Binding var isProcessing: Bool
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
                        .font(.system(size: 10, weight: .bold))
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
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: Spacing.sm) {
                Text("₹\(Int(emi.amount))")
                    .font(.cardTitle)
                    .foregroundColor(.textPrimary)
                
                if emi.status != .paid {
                    if isProcessing {
                        ProgressView()
                            .tint(.accentGreen)
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
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .background(emi.status == .overdue ? Color.accentRed.opacity(0.05) : Color.clear)
        .liquidGlass(cornerRadius: 20)
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(emi.status == .overdue ? Color.accentRed.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .opacity(emi.status == .paid ? 0.6 : 1.0)
    }
    
    private var statusText: String {
        switch emi.status {
        case .paid: return "PAID"
        case .due: return "DUE NOW"
        case .upcoming: return "UPCOMING"
        case .overdue: return "OVERDUE"
        }
    }
    
    private var statusColor: Color {
        switch emi.status {
        case .paid: return .accentGreen
        case .due: return Color(hex: "#D97706") // amber
        case .upcoming: return .textSecondary
        case .overdue: return .accentRed
        }
    }
}
