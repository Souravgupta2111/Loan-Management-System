import SwiftUI
import UIKit

/// Animated Wave Shape for the bottom of the splash screen
struct Wave: Shape {
    var phase: Double
    var strength: Double
    var frequency: Double

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = Double(rect.width)
        let height = Double(rect.height)
        
        // Start from bottom left
        path.move(to: CGPoint(x: 0, y: height))
        
        // Draw the wave curve
        for x in stride(from: 0, through: width + 1, by: 1) {
            let relativeX = x / width
            let sine = sin(relativeX * frequency * .pi * 2 + phase)
            // Mid-height of the wave
            let y = strength * sine + (height * 0.3)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        // Close path to bottom right
        path.addLine(to: CGPoint(x: width, y: height))
        path.closeSubpath()
        return path
    }
}

/// Splash screen with wave animations and logo animations
struct SplashView: View {
    @State private var startAnimation = false
    @State private var wavePhase1 = 0.0
    @State private var wavePhase2 = 0.0
    @State private var wavePhase3 = 0.0
    
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        ZStack {
            // 1. Background (Light greenish gradient)
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.96, green: 0.98, blue: 0.95),
                    Color(red: 0.90, green: 0.95, blue: 0.91)
                ]),
                center: .center,
                startRadius: 50,
                endRadius: 500
            )
            .ignoresSafeArea()

            // 2. Concentric Circles
            ZStack {
                ForEach(1..<6) { i in
                    Circle()
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        .frame(width: CGFloat(i) * 150, height: CGFloat(i) * 150)
                }
            }
            .scaleEffect(startAnimation ? 1.0 : 0.8)
            .opacity(startAnimation ? 1.0 : 0.0)
            .animation(.easeOut(duration: 2.0), value: startAnimation)

            // 3. Central Logo & Name (Visible immediately, animates scale)
            VStack(spacing: 16) {
                if let uiImage = UIImage(named: "Logo") {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 120)
                } else {
                    // Fallback logo if the asset is missing
                    ZStack {
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 70))
                            .foregroundColor(Color(red: 0.45, green: 0.75, blue: 0.45))
                            .offset(x: 20, y: 15)
                        
                        Text("Z")
                            .font(.system(size: 110, weight: .heavy, design: .rounded))
                            .foregroundColor(Color(red: 0.3, green: 0.65, blue: 0.4))
                            .italic()
                            .offset(x: -20, y: -10)
                    }
                    .frame(height: 120)
                }
                
                Text("LOANZ")
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(red: 0.3, green: 0.65, blue: 0.4))
                    .tracking(3)
            }
            .scaleEffect(startAnimation ? 1.0 : 0.6)
            // Make it visible immediately but animate its scale smoothly
            .animation(.spring(response: 0.9, dampingFraction: 0.5), value: startAnimation)
            .offset(y: -40)

            // 4. Waves at the exact bottom edge
            VStack {
                Spacer()
                ZStack(alignment: .bottom) {
                    Wave(phase: wavePhase1, strength: 20, frequency: 0.8)
                        .fill(Color(red: 0.65, green: 0.85, blue: 0.65).opacity(0.6))
                        .frame(height: 220)
                        .offset(y: 30) // Pushed slightly down to hug the edge
                    
                    Wave(phase: wavePhase2, strength: 25, frequency: 1.0)
                        .fill(Color(red: 0.55, green: 0.78, blue: 0.55).opacity(0.7))
                        .frame(height: 180)
                        .offset(y: 20)

                    Wave(phase: wavePhase3, strength: 15, frequency: 1.2)
                        .fill(Color(red: 0.45, green: 0.70, blue: 0.45).opacity(0.9))
                        .frame(height: 140)
                        .offset(y: 10)
                }
            }
            .ignoresSafeArea(edges: .bottom) // Ensure it touches the absolute bottom of the screen
        }
        .onAppear {
            // Start animations immediately when view loads
            startAnimation = true
            
            withAnimation(.linear(duration: 5.0).repeatForever(autoreverses: false)) {
                wavePhase1 = .pi * 2
            }
            withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                wavePhase2 = -.pi * 2
            }
            withAnimation(.linear(duration: 6.0).repeatForever(autoreverses: false)) {
                wavePhase3 = .pi * 2
            }
            
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
