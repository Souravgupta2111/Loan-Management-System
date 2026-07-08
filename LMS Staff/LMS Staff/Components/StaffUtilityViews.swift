import SwiftUI

/// Empty state placeholder with icon, message, and optional action button
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: StaffSpacing.xxl) {
            Spacer()

            Image(systemName: icon)
                .font(.title.weight(.light))
                .foregroundColor(.staffTextTertiary)
                .frame(width: 100, height: 100)
                .background(Color.staffSurfaceLight)
                .clipShape(Circle())

            VStack(spacing: StaffSpacing.sm) {
                Text(title)
                    .font(.staffCardTitle)
                    .foregroundColor(.staffTextPrimary)

                Text(message)
                    .font(.staffBodyRegular)
                    .foregroundColor(.staffTextSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }

            if let actionTitle = actionTitle, let action = action {
                StaffButton(title: actionTitle, style: .outline, isFullWidth: false, action: action)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Loading state overlay
struct StaffLoadingView: View {
    var message: String = "Loading..."

    var body: some View {
        VStack(spacing: StaffSpacing.lg) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .staffAccent))
                .scaleEffect(1.2)

            Text(message)
                .font(.staffCaption)
                .foregroundColor(.staffTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.staffBackground.opacity(0.8))
    }
}

/// Section header with optional action button
struct StaffSectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.staffSectionTitle)
                .foregroundColor(.staffTextPrimary)

            Spacer()

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(actionTitle)
                            .font(.staffCaption)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundColor(.staffAccent)
                }
            }
        }
    }
}

/// Amount display with Indian formatting
struct StaffAmountDisplay: View {
    let amount: Double
    var style: AmountStyle = .regular
    var prefix: String = "₹"

    enum AmountStyle {
        case hero
        case large
        case regular
        case caption
    }

    var body: some View {
        Text("\(prefix)\(formattedAmount)")
            .font(amountFont)
            .foregroundColor(.staffTextPrimary)
    }

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_IN")
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }

    private var amountFont: Font {
        switch style {
        case .hero:    return .staffHeroAmount
        case .large:   return .staffLargeAmount
        case .regular: return .staffBody
        case .caption: return .staffCaption
        }
    }
}

// MARK: - Premium Animated Shimmer & Skeleton Views

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -0.5
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    let width = geo.size.width
                    let height = geo.size.height
                    
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: Color.white.opacity(0.35), location: 0.35),
                            .init(color: Color.white.opacity(0.65), location: 0.5),
                            .init(color: Color.white.opacity(0.35), location: 0.65),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .rotationEffect(.degrees(30))
                    .frame(width: width * 3, height: height * 3)
                    .offset(x: width * (phase - 1), y: -height)
                    .onAppear {
                        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                            phase = 1.5
                        }
                    }
                }
            )
            .clipped()
    }
}

extension View {
    func shimmer() -> some View {
        self.modifier(ShimmerModifier())
    }
}

struct SkeletonCell: View {
    var width: CGFloat? = nil
    var height: CGFloat
    var cornerRadius: CGFloat = 8
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.staffSurfaceMuted)
            .frame(width: width, height: height)
            .shimmer()
    }
}

struct ReportsSkeletonView: View {
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: StaffSpacing.xxl) {
                // Header Skeleton
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonCell(width: 200, height: 28, cornerRadius: 6)
                    SkeletonCell(width: 320, height: 16, cornerRadius: 4)
                }
                
                // Key Metrics Grid Skeleton (3 columns, 2 rows)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: StaffSpacing.md), count: 3), spacing: StaffSpacing.md) {
                    ForEach(0..<6, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                SkeletonCell(width: 40, height: 40, cornerRadius: 20) // Icon circle
                                Spacer()
                            }
                            SkeletonCell(width: 100, height: 14, cornerRadius: 4) // Title
                            SkeletonCell(width: 140, height: 24, cornerRadius: 6) // Value
                            SkeletonCell(width: 80, height: 12, cornerRadius: 3) // Subtitle
                        }
                        .padding(StaffSpacing.md)
                        .background(Color.staffSurface)
                        .cornerRadius(StaffCorner.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: StaffCorner.md)
                                .stroke(Color.staffBorder, lineWidth: 1)
                        )
                    }
                }
                
                // Charts Row 1 Skeleton (2 cards)
                HStack(spacing: StaffSpacing.md) {
                    ForEach(0..<2, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 16) {
                            SkeletonCell(width: 150, height: 18, cornerRadius: 4) // Title
                            HStack {
                                Spacer()
                                SkeletonCell(width: 180, height: 180, cornerRadius: 90) // Pie/Donut Chart shape
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        .padding(StaffSpacing.md)
                        .frame(maxWidth: .infinity)
                        .background(Color.staffSurface)
                        .cornerRadius(StaffCorner.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: StaffCorner.md)
                                .stroke(Color.staffBorder, lineWidth: 1)
                        )
                    }
                }
                
                // Charts Row 2 Skeleton (2 cards)
                HStack(spacing: StaffSpacing.md) {
                    ForEach(0..<2, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 16) {
                            SkeletonCell(width: 180, height: 18, cornerRadius: 4) // Title
                            SkeletonCell(height: 180, cornerRadius: 8) // Chart bars outline
                        }
                        .padding(StaffSpacing.md)
                        .frame(maxWidth: .infinity)
                        .background(Color.staffSurface)
                        .cornerRadius(StaffCorner.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: StaffCorner.md)
                                .stroke(Color.staffBorder, lineWidth: 1)
                        )
                    }
                }
                
                // Collection Trend Section Skeleton (1 wide card)
                VStack(alignment: .leading, spacing: 16) {
                    SkeletonCell(width: 220, height: 18, cornerRadius: 4) // Title
                    SkeletonCell(height: 220, cornerRadius: 8) // Large chart outline
                }
                .padding(StaffSpacing.md)
                .background(Color.staffSurface)
                .cornerRadius(StaffCorner.md)
                .overlay(
                    RoundedRectangle(cornerRadius: StaffCorner.md)
                        .stroke(Color.staffBorder, lineWidth: 1)
                )
                
                // Recent Loans Table Skeleton (1 wide card)
                VStack(alignment: .leading, spacing: 16) {
                    SkeletonCell(width: 180, height: 18, cornerRadius: 4) // Title
                    VStack(spacing: 12) {
                        ForEach(0..<4, id: \.self) { _ in
                            HStack(spacing: 16) {
                                SkeletonCell(width: 44, height: 44, cornerRadius: 8) // Icon / Thumbnail
                                VStack(alignment: .leading, spacing: 6) {
                                    SkeletonCell(width: 120, height: 14, cornerRadius: 4) // Name
                                    SkeletonCell(width: 80, height: 10, cornerRadius: 3) // Date
                                }
                                Spacer()
                                SkeletonCell(width: 90, height: 16, cornerRadius: 4) // Amount
                                SkeletonCell(width: 60, height: 18, cornerRadius: 9) // Status Badge
                            }
                            Divider()
                        }
                    }
                }
                .padding(StaffSpacing.md)
                .background(Color.staffSurface)
                .cornerRadius(StaffCorner.md)
                .overlay(
                    RoundedRectangle(cornerRadius: StaffCorner.md)
                        .stroke(Color.staffBorder, lineWidth: 1)
                )
            }
            .padding(StaffSpacing.lg)
            .padding(.bottom, StaffSpacing.mega)
        }
        .background(Color.staffBackground)
    }
}
