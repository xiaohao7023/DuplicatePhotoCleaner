import SwiftUI

extension Color {
    // MARK: - Primary (Dupes System Blue)
    static let appPrimary = Color(hex: "1677FF")
    static let appPrimaryLight = Color(hex: "4DB8FF")
    static let appPrimaryGradient = LinearGradient(
        colors: [Color(hex: "42C4FF"), Color(hex: "0868F2")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let appPrimaryBG = Color(hex: "1677FF").opacity(0.1)

    // MARK: - Semantic
    static let appSuccess = Color(hex: "6B8F5B")
    static let appSuccessBG = Color(hex: "6B8F5B").opacity(0.08)
    static let appWarning = Color(hex: "C4903D")
    static let appWarningBG = Color(hex: "C4903D").opacity(0.08)
    static let appDanger = Color(hex: "B93632")
    static let appDangerBG = Color(hex: "B93632").opacity(0.08)

    // MARK: - Neutral (Cool system gray)
    static let appBackground = Color(hex: "F6F9FD")
    static let appBackgroundSecondary = Color(hex: "EEF3F9")
    static let appBackgroundTertiary = Color(hex: "E1E9F3")
    static let appSurface = Color.white
    static let appTextPrimary = Color(hex: "172033")
    static let appTextSecondary = Color(hex: "667085")
    static let appTextTertiary = Color(hex: "98A2B3")
    static let appTextQuaternary = Color(hex: "C3CCD8")
    static let appDivider = Color(hex: "D7E0EB")
    static let appDividerLight = Color(hex: "E8EEF5")

    // MARK: - Auxiliary
    static let appPurple = Color(hex: "8B7D9E")
    static let appTeal = Color(hex: "6A9BA5")
    static let appAmber = Color(hex: "C4903D")
    static let appSage = Color(hex: "6B8F5B")
    static let appDustyRose = Color(hex: "C17B8A")
    static let appSlateBlue = Color(hex: "7B8FA1")
    static let appCamel = Color(hex: "A67B5B")
    static let appRose = Color(hex: "D4566B")

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
