import SwiftUI

enum ChargeTheme {
    static let void = Color(red: 0.03, green: 0.04, blue: 0.07)
    static let abyss = Color(red: 0.07, green: 0.09, blue: 0.14)
    static let ember = Color(red: 1.0, green: 0.55, blue: 0.18)
    static let molten = Color(red: 1.0, green: 0.78, blue: 0.32)
    static let ice = Color(red: 0.55, green: 0.82, blue: 1.0)
    static let mist = Color.white.opacity(0.7)

    static var night: LinearGradient {
        LinearGradient(colors: [void, abyss], startPoint: .top, endPoint: .bottom)
    }

    static var chargeGlow: AngularGradient {
        AngularGradient(
            colors: [ember, molten, ice, ember],
            center: .center
        )
    }
}
