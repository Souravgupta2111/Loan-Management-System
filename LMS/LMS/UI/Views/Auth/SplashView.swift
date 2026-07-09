import SwiftUI
import UIKit

// MARK: - Loanz "L" Path (thick stroke with dot at top, curved bottom corner)

struct LogoLPath: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let thick: CGFloat = w * 0.09 // stroke thickness
        let r = thick * 1.4 // corner radius at the bottom-left bend

        var p = Path()

        // Dot at top of vertical stroke
        let dotRadius = thick * 0.75
        let dotCenter = CGPoint(x: w * 0.24, y: h * 0.10)
        p.addEllipse(in: CGRect(x: dotCenter.x - dotRadius, y: dotCenter.y - dotRadius,
                                width: dotRadius * 2, height: dotRadius * 2))

        // Vertical bar (below dot, down to bend)
        let vTop = h * 0.17
        let vBottom = h * 0.78
        let vLeft = w * 0.24 - thick / 2
        p.addRoundedRect(in: CGRect(x: vLeft, y: vTop, width: thick, height: vBottom - vTop),
                         cornerSize: CGSize(width: thick / 2, height: thick / 2))

        // Bottom horizontal bar with rounded corner connecting to vertical
        let hLeft = w * 0.24 - thick / 2
        let hRight = w * 0.64
        let hTop = vBottom - thick
        let barPath = Path { bp in
            // Start top-left of horizontal, after the curve
            bp.move(to: CGPoint(x: hLeft + r + thick, y: hTop + thick))
            bp.addLine(to: CGPoint(x: hRight, y: hTop + thick))
            // Round the right end
            bp.addQuadCurve(to: CGPoint(x: hRight, y: hTop + thick * 2),
                            control: CGPoint(x: hRight + thick * 0.4, y: hTop + thick * 1.5))
            bp.addLine(to: CGPoint(x: hLeft + r, y: hTop + thick * 2))
            // Curve back up at bottom-left corner
            bp.addQuadCurve(to: CGPoint(x: hLeft, y: hTop + thick * 2 - r),
                            control: CGPoint(x: hLeft, y: hTop + thick * 2))
            bp.addLine(to: CGPoint(x: hLeft, y: hTop + thick))
            bp.closeSubpath()
        }
        p.addPath(barPath)

        return p
    }
}

// MARK: - Loanz "Z" Path (chunky Z with rounded ends)

struct LogoZPath: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let thick: CGFloat = w * 0.085

        let zL = w * 0.38
        let zR = w * 0.76
        let zT = h * 0.28
        let zB = h * 0.72
        let cr = thick * 0.6 // end cap roundness

        var p = Path()

        // Top bar
        p.addRoundedRect(in: CGRect(x: zL, y: zT, width: zR - zL, height: thick),
                         cornerSize: CGSize(width: cr, height: cr))

        // Diagonal (parallelogram)
        let diagInset = thick * 0.55
        let diag = Path { d in
            d.move(to: CGPoint(x: zR - diagInset, y: zT + thick))
            d.addLine(to: CGPoint(x: zR + diagInset * 0.2, y: zT + thick))
            d.addLine(to: CGPoint(x: zL + diagInset, y: zB - thick))
            d.addLine(to: CGPoint(x: zL - diagInset * 0.2, y: zB - thick))
            d.closeSubpath()
        }
        p.addPath(diag)

        // Bottom bar
        p.addRoundedRect(in: CGRect(x: zL, y: zB - thick, width: zR - zL, height: thick),
                         cornerSize: CGSize(width: cr, height: cr))

        return p
    }
}

// MARK: - Animated Logo Composition

struct LoanzAnimatedLogo: View {
    let size: CGFloat
    let accentColor: Color

    @State private var drawL = false
    @State private var drawZ = false
    @State private var shimmer = false

    var body: some View {
        ZStack {
            // L shape — accent gradient
            LogoLPath()
                .fill(
                    LinearGradient(colors: [accentColor, accentColor.opacity(0.65)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .frame(width: size, height: size)
                .scaleEffect(drawL ? 1.0 : 0.0)
                .opacity(drawL ? 1 : 0)

            // Z shape — metallic silver
            LogoZPath()
                .fill(
                    LinearGradient(colors: [Color.white, Color(white: 0.78)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: size, height: size)
                .scaleEffect(drawZ ? 1.0 : 0.0)
                .opacity(drawZ ? 1 : 0)

            // Shimmer highlight sweep across logo
            RoundedRectangle(cornerRadius: size * 0.12)
                .fill(
                    LinearGradient(colors: [.clear, .white.opacity(0.35), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .frame(width: size * 0.3, height: size)
                .offset(x: shimmer ? size * 0.7 : -size * 0.7)
                .mask(
                    ZStack {
                        LogoLPath().frame(width: size, height: size)
                        LogoZPath().frame(width: size, height: size)
                    }
                )
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65).delay(0.15)) {
                drawL = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65).delay(0.4)) {
                drawZ = true
            }
            withAnimation(.easeInOut(duration: 1.0).delay(0.9)) {
                shimmer = true
            }
        }
    }
}

// MARK: - Splash Screen

/// Mandatory 2-second animated splash with the Loanz LZ logo.
/// The logo uses the app's theme accent color so it adapts to the palette.
struct SplashView: View {
    @State private var showContainer = false
    @State private var showText = false
    @State private var ringPulse = false

    @EnvironmentObject var authViewModel: AuthViewModel

    private let themeColor = Color.accentGreen

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color.gradientMintStart, Color.gradientMintEnd, Color.gradientMintStart],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Animated concentric rings
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(themeColor.opacity(0.12 - Double(i) * 0.03), lineWidth: 1.5)
                        .frame(width: CGFloat(180 + i * 70), height: CGFloat(180 + i * 70))
                        .scaleEffect(ringPulse ? 1.08 : 0.92)
                        .animation(
                            .easeInOut(duration: 1.8).repeatForever(autoreverses: true).delay(Double(i) * 0.25),
                            value: ringPulse
                        )
                }
            }
            .opacity(showContainer ? 1 : 0)

            // Logo + Text
            VStack(spacing: 28) {
                // Icon container (dark rounded square like actual app icon)
                ZStack {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.10, green: 0.20, blue: 0.14),
                                    Color(red: 0.05, green: 0.12, blue: 0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 150, height: 150)
                        .overlay(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .stroke(themeColor.opacity(0.25), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 24, x: 0, y: 12)
                        .scaleEffect(showContainer ? 1.0 : 0.4)
                        .opacity(showContainer ? 1 : 0)

                    LoanzAnimatedLogo(size: 120, accentColor: themeColor)
                }

                // LOANZ text
                HStack(spacing: 1) {
                    Text("LOAN")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(hex: "#1A1A1A"))
                    Text("Z")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundColor(themeColor)
                }
                .tracking(5)
                .opacity(showText ? 1 : 0)
                .offset(y: showText ? 0 : 12)
            }
            .offset(y: -16)
        }
        .onAppear {
            // Container scales in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                showContainer = true
            }
            // Text fades in after logo draws
            withAnimation(.easeOut(duration: 0.5).delay(1.0)) {
                showText = true
            }
            // Rings start pulsing
            ringPulse = true

            // Mandatory 2-second minimum splash, then check session
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                authViewModel.checkSession()
            }
        }
    }
}

#Preview {
    SplashView()
        .environmentObject(AuthViewModel())
}
