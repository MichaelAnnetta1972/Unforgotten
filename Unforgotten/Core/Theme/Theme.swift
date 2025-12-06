import SwiftUI

// MARK: - App Colors
extension Color {
    // Background colors
    static let appBackground = Color(hex: "000000")
    static let cardBackground = Color(hex: "1E1A1A")
    static let cardBackgroundLight = Color(hex: "383838")   
    static let cardBackgroundSoft = Color(hex: "2A2424")
    static let cardBackgroundDark = Color(hex: "1A1A1A")
    
    // Accent colors
    static let accentYellow = Color(hex: "FFC93A")
    static let medicalRed = Color(hex: "F36A6A")
    static let medicalRedBackground = Color(hex: "C75B5B")
    static let giftPurple = Color(hex: "4C3A8E")
    static let giftPurpleBackground = Color(hex: "3D2E6B")
    static let clothingBlue = Color(hex: "365A9C")
    static let connectionsGreen = Color(hex: "2E7D5A")

    // Header gradient
    static let headerGradientStart = Color(hex: "283C96")
    static let headerGradientEnd = Color(hex: "F25BA5")
    
    // Text colors
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "B0A9A9")
    static let textMuted = Color(hex: "808080")
    
    // Status colors
    static let badgeGreen = Color(hex: "35C16C")
    static let badgeGrey = Color(hex: "333333")
    static let badgeRed = Color(hex: "E74C3C")
    
    // Calendar colors
    static let calendarPink = Color(hex: "D4A5A5")
    static let calendarBlue = Color(hex: "5B8FB9")
    
    // Initialize from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
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

// MARK: - App Typography
extension Font {
    static let appLargeTitle = Font.system(size: 28, weight: .bold)
    static let appTitle = Font.system(size: 22, weight: .semibold)
    static let appTitle2 = Font.system(size: 20, weight: .semibold)
    static let appCardTitle = Font.system(size: 18, weight: .semibold)
    static let appBody = Font.system(size: 17, weight: .regular)
    static let appBodyMedium = Font.system(size: 17, weight: .medium)
    static let appCaption = Font.system(size: 13, weight: .medium)
    static let appCaptionSmall = Font.system(size: 11, weight: .medium)
    static let appButtonText = Font.system(size: 17, weight: .semibold)
    static let appValuePill = Font.system(size: 15, weight: .medium)
}

// MARK: - App Dimensions
struct AppDimensions {
    static let cardCornerRadius: CGFloat = 18
    static let buttonCornerRadius: CGFloat = 12
    static let smallCornerRadius: CGFloat = 10
    static let pillCornerRadius: CGFloat = 8
    
    static let cardPadding: CGFloat = 24
    static let screenPadding: CGFloat = 12
    static let cardSpacing: CGFloat = 12
    
    static let floatingButtonSize: CGFloat = 56
    static let headerHeight: CGFloat = 300
    static let headerHeightLarge: CGFloat = 360
    static let headerContentSpacing: CGFloat = 248  // Space from top of screen to first content (below header)
    
    static let categoryCardWidth: CGFloat = 150
    static let categoryCardHeight: CGFloat = 165
    
    static let buttonHeight: CGFloat = 50
    static let textFieldHeight: CGFloat = 50
}

// MARK: - App Gradients
extension LinearGradient {
    static let headerGradient = LinearGradient(
        colors: [Color.headerGradientStart, Color.headerGradientEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let medicalGradient = LinearGradient(
        colors: [Color.medicalRed, Color.medicalRedBackground],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let giftGradient = LinearGradient(
        colors: [Color.giftPurple, Color.giftPurpleBackground],
        startPoint: .top,
        endPoint: .bottom
    )
}
