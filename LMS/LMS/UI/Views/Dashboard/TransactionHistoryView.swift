import SwiftUI

struct TransactionHistoryView: View {
    let transactions: [TxItem]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(transactions) { item in
                    transactionCard(item)
                }
            }
            .padding()
        }
        .background(
            LinearGradient(
                colors: [Color(hex: "#E7EFE5"), Color(hex: "#EFF4EA"), Color(hex: "#E7EFE5")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Transaction History")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func transactionCard(_ item: TxItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(item.statusBg)
                    .frame(width: 40, height: 40)
                Image(systemName: item.statusIcon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(item.statusColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(hex: "#1A1A1A"))
                Text(item.subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color(hex: "#6B6B6B"))
            }
            
            Spacer()
            
            HStack(spacing: 2) {
                Text(item.direction.sign)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(item.direction.color)
                Text("₹\(formatIndian(abs(item.amount)))")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#1A1A1A"))
            }
        }
        .padding(16)
        .liquidGlass(cornerRadius: 16)
    }
    
    private func formatIndian(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
}
