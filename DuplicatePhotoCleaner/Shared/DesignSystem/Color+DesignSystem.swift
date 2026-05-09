import SwiftUI

extension Color {
    // MARK: - Primary (Crail Warm Brown-Red)
    static let appPrimary = Color(hex: "C15F3C")
    static let appPrimaryLight = Color(hex: "D4836A")
    static let appPrimaryGradient = LinearGradient(
        colors: [Color(hex: "C15F3C"), Color(hex: "A04E32")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let appPrimaryBG = Color(hex: "C15F3C").opacity(0.1)

    // MARK: - Semantic
    static let appSuccess = Color(hex: "6B8F5B")
    static let appSuccessBG = Color(hex: "6B8F5B").opacity(0.08)
    static let appWarning = Color(hex: "C4903D")
    static let appWarningBG = Color(hex: "C4903D").opacity(0.08)
    static let appDanger = Color(hex: "B84C4C")
    static let appDangerBG = Color(hex: "B84C4C").opacity(0.08)

    // MARK: - Neutral (Pampas Warm Gray)
    static let appBackground = Color(hex: "F4F3EE")
    static let appBackgroundSecondary = Color(hex: "EDECEA")
    static let appBackgroundTertiary = Color(hex: "DEDBD5")
    static let appSurface = Color.white
    static let appTextPrimary = Color(hex: "2D2A26")
    static let appTextSecondary = Color(hex: "8A8580")
    static let appTextTertiary = Color(hex: "B1ADA1")
    static let appTextQuaternary = Color(hex: "C8C4BC")
    static let appDivider = Color(hex: "D8D5CE")
    static let appDividerLight = Color(hex: "E8E6E1")

    // MARK: - Auxiliary
    static let appPurple = Color(hex: "8B7D9E")
    static let appTeal = Color(hex: "6A9BA5")
    static let appAmber = Color(hex: "C4903D")
    static let appSage = Color(hex: "6B8F5B")
    static let appDustyRose = Color(hex: "C17B8A")
    static let appSlateBlue = Color(hex: "7B8FA1")
    static let appCamel = Color(hex: "A67B5B")

    // MARK: - Hex Initializer
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}
