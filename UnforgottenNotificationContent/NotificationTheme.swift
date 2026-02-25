import SwiftUI

// Standalone theme constants for the Notification Content Extension.
// Mirrors relevant values from the main app's Theme.swift.
// The extension cannot import the main app module.

enum NotificationTheme {
    // Colors
    static let background = Color(hex: "000000")
    static let cardBackground = Color(hex: "222222")
    static let accentYellow = Color(hex: "FFC93A")
    static let headerGradientStart = Color(hex: "283C96")
    static let headerGradientEnd = Color(hex: "F25BA5")
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "c1bfbf")
    static let medicalRed = Color(hex: "F36A6A")

    // Dimensions
    static let cardCornerRadius: CGFloat = 18
    static let buttonCornerRadius: CGFloat = 14
    static let cardPadding: CGFloat = 30

    // Typography
    static let titleFont = Font.system(size: 22, weight: .semibold)
    static let bodyFont = Font.system(size: 20, weight: .regular)
    static let captionFont = Font.system(size: 14, weight: .medium)
    static let buttonFont = Font.system(size: 20, weight: .semibold)

    // Header gradient
    static let headerGradient = LinearGradient(
        colors: [headerGradientStart, headerGradientEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
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
