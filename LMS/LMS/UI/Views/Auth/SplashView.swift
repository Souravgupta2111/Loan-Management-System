import SwiftUI

/// Splash screen with gradient animation (design.md §8.1)
struct SplashView: View {
    @State private var startAnimation = false
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.gradientMintStart, .surface, Color.gradientLavenderStart],
                startPoint: startAnimation ? .topLeading : .bottomTrailing,
                endPoint: startAnimation ? .bottomTrailing : .topLeading
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: startAnimation)

            VStack(spacing: Spacing.xxl) {
                Image(systemName: "building.columns.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .foregroundColor(.accentGreen)
                    .scaleEffect(startAnimation ? 1.0 : 0.8)
                    .opacity(startAnimation ? 1.0 : 0.0)
                    .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2), value: startAnimation)

                Text("LMS")
                    .font(.heroAmount)
                    .foregroundColor(.textPrimary)
                    .opacity(startAnimation ? 1.0 : 0.0)
                    .animation(.easeIn(duration: 0.8).delay(0.5), value: startAnimation)

                Text("Loan Management System")
                    .font(.bodyRegular)
                    .foregroundColor(.textSecondary)
                    .opacity(startAnimation ? 1.0 : 0.0)
                    .animation(.easeIn(duration: 0.8).delay(0.7), value: startAnimation)
            }
        }
        .onAppear {
            startAnimation = true
            Task {
                authViewModel.checkSession()
            }
        }
    }
}
