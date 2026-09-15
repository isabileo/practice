import SwiftUI

enum GameTheme {
    static let abyss = Color(red: 0.04, green: 0.09, blue: 0.14)
    static let deep = Color(red: 0.06, green: 0.16, blue: 0.22)
    static let teal = Color(red: 0.18, green: 0.72, blue: 0.68)
    static let foam = Color(red: 0.72, green: 0.94, blue: 0.90)
    static let coral = Color(red: 1.0, green: 0.42, blue: 0.28)
    static let amber = Color(red: 1.0, green: 0.72, blue: 0.28)
    static let stone = Color(red: 0.32, green: 0.38, blue: 0.46)

    static var sky: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.18, blue: 0.26),
                abyss,
                Color(red: 0.05, green: 0.12, blue: 0.16)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var spark: RadialGradient {
        RadialGradient(
            colors: [amber, coral.opacity(0.85), coral.opacity(0)],
            center: .center,
            startRadius: 2,
            endRadius: 28
        )
    }
}
