//
//  SplashView.swift
//  LMS Staff
//
//  Splash screen while checking active auth session.
//

import SwiftUI

struct SplashView: View {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.5
    
    var body: some View {
        ZStack {
            Color.staffBackground.ignoresSafeArea()
            VStack(spacing: StaffSpacing.lg) {
                // Large elegant icon/logo
                Image(systemName: "building.columns.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .foregroundColor(.staffAccent)
                    .scaleEffect(scale)
                    .opacity(opacity)
                    .onAppear {
                        withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: true)) {
                            scale = 1.05
                            opacity = 1.0
                        }
                    }
                
                Text("LOANZ STAFF PORTAL")
                    .font(.staffTitle)
                    .foregroundColor(.staffTextPrimary)
                    .tracking(4)
                
                Text("Secure Institutional Access")
                    .font(.staffBody)
                    .foregroundColor(.staffTextSecondary)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .staffAccent))
                    .scaleEffect(1.2)
                    .padding(.top, StaffSpacing.xl)
            }
        }
        .ignoresSafeArea()
    }
}

// Helper wrapper to easily layout background colors
extension View {
    func Z景色(_ color: Color, @ViewBuilder content: () -> some View) -> some View {
        ZStack {
            color.ignoresSafeArea()
            content()
        }
    }
}

struct SplashView_Previews: PreviewProvider {
    static var previews: some View {
        SplashView()
    }
}
