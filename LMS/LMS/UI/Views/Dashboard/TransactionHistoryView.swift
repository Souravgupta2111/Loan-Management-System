import SwiftUI

struct TransactionHistoryView: View {
    @Environment(\.dismiss) private var dismiss
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
                colors: [Color.gradientMintStart, Color.gradientMintEnd, Color.gradientMintStart],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationBarBackButtonHidden(true)
        .toolbar { ToolbarItem(placement: .topBarLeading) { GlassBackButton { dismiss() } } }
        .navigationTitle("Transaction History")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func transactionCard(_ item: TxItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(item.statusBg)
                    .frame(width: 28, height: 28)
                Image(systemName: item.statusIcon)
                    .font(.footnote.weight(.bold))
                    .foregroundColor(item.statusColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body.weight(.bold))
                    .foregroundColor(Color(hex: "#1A1A1A"))
                Text(item.subtitle)
                    .font(.subheadline.weight(.regular))
                    .foregroundColor(Color(hex: "#6B6B6B"))
            }
            
            Spacer()
            
            HStack(spacing: 2) {
                Text(item.direction.sign)
                    .font(.body.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundColor(item.direction.color)
                Text("₹\(formatIndian(abs(item.amount)))")
                    .font(.body.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundColor(Color(hex: "#1A1A1A"))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
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
