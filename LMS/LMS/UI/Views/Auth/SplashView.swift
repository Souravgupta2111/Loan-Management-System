import SwiftUI
import UIKit

// MARK: - LZ Logo Shape (drawn as vector path)

/// The "L" stroke of the Loanz logo — a vertical line with dot at top, curving into horizontal bottom.
struct LogoLShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Vertical stroke of L (left side, with rounded top dot)
        let topDotCenter = CGPoint(x: w * 0.22, y: h * 0.12)
        path.addEllipse(in: CGRect(x: topDotCenter.x - w * 0.04, y: topDotCenter.y - w * 0.04, width: w * 0.08, height: w * 0.08))
        
        // Vertical line from dot down
        let strokeWidth = w * 0.065
        path.addRoundedRect(in: CGRect(x: w * 0.22 - strokeWidth / 2, y: h * 0.16, width: strokeWidth, height: h * 0.58), cornerSize: CGSize(width: strokeWidth / 2, height: strokeWidth / 2))
        
        // Horizontal bottom bar (curves from vertical to horizontal)
        let bottomY = h * 0.74
        let bottomPath = Path { p in
            p.move(to: CGPoint(x: w * 0.22 - strokeWidth / 2, y: bottomY))
            p.addLine(to: CGPoint(x: w * 0.22 - strokeWidth / 2, y: bottomY + strokeWidth * 0.5))
            // Curve at corner
            p.addQuadCurve(to: CGPoint(x: w * 0.22 + strokeWidth * 0.5, y: bottomY + strokeWidth * 1.5), control: CGPoint(x: w * 0.22 - strokeWidth / 2, y: bottomY + strokeWidth * 1.5))
            p.addLine(to: CGPoint(x: w * 0.62, y: bottomY + strokeWidth * 1.5))
            // Top edge of horizontal bar
            p.addLine(to: CGPoint(x: w * 0.62, y: bottomY + strokeWidth * 0.5))
            p.addLine(to: CGPoint(x: w * 0.22 + strokeWidth * 0.5, y: bottomY + strokeWidth * 0.5))
            p.addQuadCurve(to: CGPoint(x: w * 0.22 + strokeWidth / 2, y: bottomY), control: CGPoint(x: w * 0.22 + strokeWidth / 2, y: bottomY + strokeWidth * 0.5))
            p.closeSubpath()
        }
        path.addPath(bottomPath)
        
        return path
    }
}

/// The "Z" letterform of the Loanz logo.
struct LogoZShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let strokeWidth = w * 0.06
        
        // Z positioned to the right, overlapping slightly with L
        let zLeft = w * 0.38
        let zRight = w * 0.72
        let zTop = h * 0.32
        let zBottom = h * 0.68
        let cornerRadius = strokeWidth * 1.2
        
        // Top horizontal bar of Z
        path.addRoundedRect(in: CGRect(x: zLeft, y: zTop, width: zRight - zLeft, height: strokeWidth), cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        
        // Diagonal of Z
        let diagPath = Path { p in
            p.move(to: CGPoint(x: zRight - strokeWidth * 0.3, y: zTop + strokeWidth))
            p.addLine(to: CGPoint(x: zRight, y: zTop + strokeWidth))
            p.addLine(to: CGPoint(x: zLeft + strokeWidth * 0.3, y: zBottom - strokeWidth))
            p.addLine(to: CGPoint(x: zLeft, y: zBottom - strokeWidth))
            p.closeSubpath()
        }
        path.addPath(diagPath)
        
        // Bottom horizontal bar of Z
        path.addRoundedRect(in: CGRect(x: zLeft, y: zBottom - strokeWidth, width: zRight - zLeft, height: strokeWidth), cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        
        return path
    }
}

// MARK: - Animated Logo View

struct LoanzLogoView: View {
    let size: CGFloat
    let accentColor: Color
    
    @State private var showL = false
    @State private var showZ = false
    @State private var showGlow = false
    
    var body: some View {
        ZStack {
            // L shape (green/accent colored)
            LogoLShape()
                .fill(
                    LinearGradient(
                        colors: [accentColor, accentColor.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size, height: size)
                .scaleEffect(showL ? 1.0 : 0.3)
                .opacity(showL ? 1.0 : 0.0)
            
            // Z shape (silver/white)
            LogoZShape()
                .fill(
                    LinearGradient(
                        colors: [.white, Color(white: 0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .scaleEffect(showZ ? 1.0 : 0.3)
                .opacity(showZ ? 1.0 : 0.0)
            
            // Glow ring
            Circle()
                .stroke(accentColor.opacity(0.3), lineWidth: 2)
                .frame(width: size * 1.3, height: size * 1.3)
                .scaleEffect(showGlow ? 1.2 : 0.8)
                .opacity(showGlow ? 0.0 : 0.6)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.1)) {
                showL = true
            }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.35)) {
                showZ = true
            }
            withAnimation(.easeOut(duration: 1.5).delay(0.6)) {
                showGlow = true
            }
        }
    }
}

// MARK: - Splash Screen

/// Splash screen with animated Loanz logo that adapts to theme colors
struct SplashView: View {
    @State private var startAnimation = false
    @State private var showText = false
    @State private var pulseRings = false
    
    @EnvironmentObject var authViewModel: AuthViewModel

    // Theme color — uses the app's accent green
    private let themeColor = Color.accentGreen
    
    var body: some View {
        ZStack {
            // Background gradient (uses theme color)
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.gradientMintStart,
                    Color.gradientMintEnd
                ]),
                center: .center,
                startRadius: 50,
                endRadius: 500
            )
            .ignoresSafeArea()

            // Subtle pulse rings
            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(themeColor.opacity(0.15 - Double(i) * 0.04), lineWidth: 1.5)
                        .frame(width: CGFloat(200 + i * 80), height: CGFloat(200 + i * 80))
                        .scaleEffect(pulseRings ? 1.1 : 0.9)
                        .opacity(startAnimation ? 1.0 : 0.0)
                        .animation(
                            .easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.3),
                            value: pulseRings
                        )
                }
            }

            // Central logo & text
            VStack(spacing: 24) {
                // Logo container with rounded rect background
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.12, green: 0.22, blue: 0.16),
                                    Color(red: 0.08, green: 0.15, blue: 0.11)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 140, height: 140)
                        .shadow(color: themeColor.opacity(0.3), radius: 20, x: 0, y: 10)
                        .scaleEffect(startAnimation ? 1.0 : 0.5)
                        .opacity(startAnimation ? 1.0 : 0.0)
                    
                    LoanzLogoView(size: 120, accentColor: themeColor)
                }
                
                // App name
                HStack(spacing: 2) {
                    Text("LOAN")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(hex: "#1A1A1A"))
                    Text("Z")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundColor(themeColor)
                }
                .tracking(4)
                .opacity(showText ? 1.0 : 0.0)
                .offset(y: showText ? 0 : 15)
            }
            .offset(y: -20)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                startAnimation = true
            }
            
            withAnimation(.easeOut(duration: 0.6).delay(0.8)) {
                showText = true
            }
            
            pulseRings = true
            
            // Wait for 2.5 seconds to show the splash screen before checking session
            Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                authViewModel.checkSession()
            }
        }
    }
}

#Preview {
    SplashView()
        .environmentObject(AuthViewModel())
}
