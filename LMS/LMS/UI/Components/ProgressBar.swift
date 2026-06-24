import SwiftUI

/// Loan Repayment Progress Bar
struct LoanProgressBar: View {
    /// Value from 0.0 to 1.0
    let progress: Double
    let color: Color

    init(progress: Double, color: Color = .accentGreen) {
        self.progress = min(max(progress, 0), 1)
        self.color = color
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.surfaceMuted)
                    .frame(height: 6)

                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: geo.size.width * progress, height: 6)
                    .animation(.spring(response: 0.6), value: progress)
            }
        }
        .frame(height: 6)
    }
}
