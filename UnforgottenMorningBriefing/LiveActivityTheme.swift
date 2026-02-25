import SwiftUI

// Standalone theme constants for the Morning Briefing Live Activity extension.
// Mirrors relevant values from the main app's Theme.swift.
// The extension cannot import the main app module.

enum LiveActivityTheme {
    // Colors
    static let background = Color(hex: "000000")
    static let cardBackground = Color(hex: "4A4A5E")
    //static let cardBackground = Color(hex: "1A1A2E")
    static let cardBackgroundOpacity: Double = 0.3
    static let accentYellow = Color(hex: "FFC93A")
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "c1bfbf")
    static let medicalRed = Color(hex: "F36A6A")
    static let calendarBlue = Color(hex: "4A90D9")
    static let birthdayPink = Color(hex: "F25BA5")
    static let countdownPurple = Color(hex: "9B59B6")

    // Dimensions
    static let cardCornerRadius: CGFloat = 16
    static let itemSpacing: CGFloat = 8
    static let cardPadding: CGFloat = 16

    // Typography (sized to fit within 160pt Live Activity height limit)
    static let titleFont = Font.system(size: 20, weight: .bold)
    static let dateFont = Font.system(size: 12, weight: .regular)
    static let itemFont = Font.system(size: 14, weight: .medium)
    static let itemSubtitleFont = Font.system(size: 12, weight: .regular)
    static let summaryFont = Font.system(size: 12, weight: .medium)

    // Custom header image from asset catalog (used on Lock Screen)
    static let headerImageName = "sun-icon"

    // Header SF Symbol (time-of-day based, used in Dynamic Island)
    static var headerSystemImageName: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "sun.max.fill"
        case 12..<17: return "sun.min.fill"
        case 17..<21: return "sunset.fill"
        default: return "moon.stars.fill"
        }
    }

}

extension Color {
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
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
