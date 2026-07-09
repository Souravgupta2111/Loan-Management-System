//
//  LoanzLogo.swift
//  LMS Staff
//
//  Animated Loanz LZ logo drawn as SwiftUI vector paths.
//  Used in splash and login screens. Adapts to the staff color palette.
//

import SwiftUI

// MARK: - "L" Path

struct StaffLogoLPath: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let thick: CGFloat = w * 0.09
        let r = thick * 1.4

        var p = Path()

        // Dot at top
        let dotRadius = thick * 0.75
        let dotCenter = CGPoint(x: w * 0.24, y: h * 0.10)
        p.addEllipse(in: CGRect(x: dotCenter.x - dotRadius, y: dotCenter.y - dotRadius,
                                width: dotRadius * 2, height: dotRadius * 2))

        // Vertical bar
        let vTop = h * 0.17
        let vBottom = h * 0.78
        p.addRoundedRect(in: CGRect(x: w * 0.24 - thick / 2, y: vTop, width: thick, height: vBottom - vTop),
                         cornerSize: CGSize(width: thick / 2, height: thick / 2))

        // Bottom horizontal bar with curved corner
        let hLeft = w * 0.24 - thick / 2
        let hRight = w * 0.64
        let hTop = vBottom - thick
        let barPath = Path { bp in
            bp.move(to: CGPoint(x: hLeft + r + thick, y: hTop + thick))
            bp.addLine(to: CGPoint(x: hRight, y: hTop + thick))
            bp.addQuadCurve(to: CGPoint(x: hRight, y: hTop + thick * 2),
                            control: CGPoint(x: hRight + thick * 0.4, y: hTop + thick * 1.5))
            bp.addLine(to: CGPoint(x: hLeft + r, y: hTop + thick * 2))
            bp.addQuadCurve(to: CGPoint(x: hLeft, y: hTop + thick * 2 - r),
                            control: CGPoint(x: hLeft, y: hTop + thick * 2))
            bp.addLine(to: CGPoint(x: hLeft, y: hTop + thick))
            bp.closeSubpath()
        }
        p.addPath(barPath)

        return p
    }
}

// MARK: - "Z" Path

struct StaffLogoZPath: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let thick: CGFloat = w * 0.085

        let zL = w * 0.38
        let zR = w * 0.76
        let zT = h * 0.28
        let zB = h * 0.72
        let cr = thick * 0.6

        var p = Path()

        // Top bar
        p.addRoundedRect(in: CGRect(x: zL, y: zT, width: zR - zL, height: thick),
                         cornerSize: CGSize(width: cr, height: cr))

        // Diagonal
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

// MARK: - Animated Logo

struct StaffLoanzAnimatedLogo: View {
    let size: CGFloat
    let accentColor: Color

    @State private var drawL = false
    @State private var drawZ = false
    @State private var shimmer = false

    var body: some View {
        ZStack {
            StaffLogoLPath()
                .fill(
                    LinearGradient(colors: [accentColor, accentColor.opacity(0.65)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .frame(width: size, height: size)
                .scaleEffect(drawL ? 1.0 : 0.0)
                .opacity(drawL ? 1 : 0)

            StaffLogoZPath()
                .fill(
                    LinearGradient(colors: [Color.white, Color(white: 0.78)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: size, height: size)
                .scaleEffect(drawZ ? 1.0 : 0.0)
                .opacity(drawZ ? 1 : 0)

            // Shimmer
            RoundedRectangle(cornerRadius: size * 0.12)
                .fill(
                    LinearGradient(colors: [.clear, .white.opacity(0.35), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .frame(width: size * 0.3, height: size)
                .offset(x: shimmer ? size * 0.7 : -size * 0.7)
                .mask(
                    ZStack {
                        StaffLogoLPath().frame(width: size, height: size)
                        StaffLogoZPath().frame(width: size, height: size)
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
