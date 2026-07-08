import SwiftUI

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
        let midHeight = height * 0.2
        
        path.move(to: CGPoint(x: 0, y: height))
        
        for x in stride(from: 0, through: width + 1, by: 1) {
            let relativeX = x / width
            let sine = sin(relativeX * frequency * .pi * 2 + phase)
            let y = strength * sine + midHeight
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: width, y: height))
        path.closeSubpath()
        return path
    }
}
