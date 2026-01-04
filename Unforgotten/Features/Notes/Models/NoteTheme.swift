import SwiftUI

// MARK: - Note Theme
/// Defines the visual theme for a note, including colors, icons, and header styling
enum NoteTheme: String, CaseIterable, Codable, Identifiable {
    case standard
    case festive
    case work
    case holidays
    case shopping
    case family

    var id: String { rawValue }

    // MARK: - Display Properties

    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .festive: return "Festive"
        case .work: return "Work"
        case .holidays: return "Holidays"
        case .shopping: return "Shopping"
        case .family: return "Family"
        }
    }

    var icon: String {
        switch self {
        case .standard: return "note.text"
        case .festive: return "gift.fill"
        case .work: return "briefcase.fill"
        case .holidays: return "sun.max.fill"
        case .shopping: return "cart.fill"
        case .family: return "heart.fill"
        }
    }

    var decorativeIcons: [String] {
        switch self {
        case .standard: return ["doc.text", "pencil", "bookmark"]
        case .festive: return ["gift.fill", "snowflake", "star.fill"]
        case .work: return ["briefcase.fill", "doc.text.fill", "calendar"]
        case .holidays: return ["sun.max.fill", "beach.umbrella.fill", "airplane"]
        case .shopping: return ["cart.fill", "bag.fill", "creditcard.fill"]
        case .family: return ["heart.fill", "house.fill", "person.2.fill"]
        }
    }

    // MARK: - Colors

    /// Primary accent color for the theme
    var accentColor: Color {
        switch self {
        case .standard: return Color(.systemBlue)
        case .festive: return Color(hex: "B91C1C") // Deep red
        case .work: return Color(hex: "6366F1") // Indigo/purple
        case .holidays: return Color(hex: "F59E0B") // Warm orange
        case .shopping: return Color(hex: "14B8A6") // Teal
        case .family: return Color(hex: "F43F5E") // Warm rose
        }
    }

    /// Background color for note cards and editor
    var backgroundColor: Color {
        Color.appBackgroundLight
    }

    /// Secondary background for subtle differentiation
    var secondaryBackgroundColor: Color {
        Color.appBackground
    }

    // MARK: - Header Gradient

    /// Gradient colors for the themed header
    var headerGradientColors: [Color] {
        switch self {
        case .standard:
            return [
                Color(.systemBlue).opacity(0.3),
                Color(.systemBlue).opacity(0.1),
                Color(.systemBackground)
            ]
        case .festive:
            return [
                Color(hex: "B91C1C").opacity(0.4),
                Color(hex: "166534").opacity(0.3),
                Color(.systemBackground)
            ]
        case .work:
            return [
                Color(hex: "6366F1").opacity(0.3),
                Color(hex: "3B82F6").opacity(0.2),
                Color(.systemBackground)
            ]
        case .holidays:
            return [
                Color(hex: "F59E0B").opacity(0.4),
                Color(hex: "0EA5E9").opacity(0.2),
                Color(.systemBackground)
            ]
        case .shopping:
            return [
                Color(hex: "14B8A6").opacity(0.3),
                Color(hex: "6366F1").opacity(0.2),
                Color(.systemBackground)
            ]
        case .family:
            return [
                Color(hex: "F43F5E").opacity(0.3),
                Color(hex: "FB923C").opacity(0.2),
                Color(.systemBackground)
            ]
        }
    }

    /// Decorative pattern opacity
    var patternOpacity: Double {
        0.08
    }

    /// Header image name for the note editor (independent of app style)
    var headerImageName: String {
        "note_header_\(rawValue)"
    }
}

// Note: Color(hex:) extension is defined in Core/Theme/Theme.swift

// MARK: - Note Spacing Constants
enum NoteSpacing {
    static let listRowPadding: CGFloat = 16
    static let listRowVertical: CGFloat = 12
    static let editorHorizontalPadding: CGFloat = 20
    static let editorTopPadding: CGFloat = 16
    static let titleContentSpacing: CGFloat = 12
    static let toolbarHeight: CGFloat = 44
    static let headerExpandedHeight: CGFloat = 150
    static let headerCollapsedHeight: CGFloat = 60
    static let themeIconSize: CGFloat = 18
    static let toolbarIconSize: CGFloat = 20
}

// MARK: - Note Typography
enum NoteTypography {
    static let noteTitle = Font.system(size: 28, weight: .bold)
    static let heading = Font.system(size: 22, weight: .bold)
    static let body = Font.system(size: 17, weight: .regular)
    static let monospace = Font.system(size: 15, weight: .regular, design: .monospaced)
    static let listRowTitle = Font.system(size: 17, weight: .semibold)
    static let listRowPreview = Font.system(size: 15, weight: .regular)
    static let listRowDate = Font.system(size: 13, weight: .regular)
}

// Note: Note-specific colors are defined in Core/Theme/Theme.swift
