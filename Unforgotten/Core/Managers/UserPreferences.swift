import SwiftUI

// MARK: - Accent Color Option
enum AccentColorOption: Int, CaseIterable, Identifiable {
    case yellow = 0
    case orange
    case coral
    case pink
    case purple
    case blue
    case cyan
    case teal
    case green
    case mint

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .yellow: return "Yellow"
        case .orange: return "Orange"
        case .coral: return "Coral"
        case .pink: return "Pink"
        case .purple: return "Purple"
        case .blue: return "Blue"
        case .cyan: return "Cyan"
        case .teal: return "Teal"
        case .green: return "Green"
        case .mint: return "Mint"
        }
    }

    var color: Color {
        switch self {
        case .yellow: return Color(hex: "FFD60A")
        case .orange: return Color(hex: "FF9F0A")
        case .coral: return Color(hex: "FF6B6B")
        case .pink: return Color(hex: "ce76b7")
        case .purple: return Color(hex: "BF5AF2")
        case .blue: return Color(hex: "0A84FF")
        case .cyan: return Color(hex: "64D2FF")
        case .teal: return Color(hex: "40C8E0")
        case .green: return Color(hex: "6a863e")
        case .mint: return Color(hex: "63E6BE")
        }
    }

    var hexString: String {
        switch self {
        case .yellow: return "FFD60A"
        case .orange: return "FF9F0A"
        case .coral: return "FF6B6B"
        case .pink: return "f16690"
        case .purple: return "935cb6"
        case .blue: return "0A84FF"
        case .cyan: return "64D2FF"
        case .teal: return "40C8E0"
        case .green: return "518d69"
        case .mint: return "63E6BE"
        }
    }

    /// Find the accent color option that matches a hex string (case-insensitive)
    static func from(hex: String) -> AccentColorOption? {
        let normalizedHex = hex.uppercased().trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        return allCases.first { $0.hexString.uppercased() == normalizedHex }
    }
}

// MARK: - User Preferences Manager
@Observable
class UserPreferences {
    private let accentColorKey = "user_accent_color_index"
    private let hasCustomAccentColorKey = "has_custom_accent_color"

    /// Current user ID for sync (set by AppState)
    var currentUserId: UUID?
    /// Current account ID for sync (set by AppState)
    var currentAccountId: UUID?

    var selectedAccentColorIndex: Int {
        didSet {
            UserDefaults.standard.set(selectedAccentColorIndex, forKey: accentColorKey)
            triggerSync()
        }
    }

    /// Whether the user has explicitly chosen a custom accent color
    /// If false, the app should use the current header style's default accent color
    var hasCustomAccentColor: Bool {
        didSet {
            UserDefaults.standard.set(hasCustomAccentColor, forKey: hasCustomAccentColorKey)
            triggerSync()
        }
    }

    /// Trigger async sync to Supabase
    private func triggerSync() {
        guard let userId = currentUserId, let accountId = currentAccountId else { return }
        Task { @MainActor in
            await PreferencesSyncService.shared.syncAccentColor(userId: userId, accountId: accountId)
        }
    }

    var selectedAccentColor: AccentColorOption {
        get {
            AccentColorOption(rawValue: selectedAccentColorIndex) ?? .yellow
        }
        set {
            selectedAccentColorIndex = newValue.rawValue
        }
    }

    var accentColor: Color {
        selectedAccentColor.color
    }

    init() {
        // Load saved preference or default to yellow (index 0)
        self.selectedAccentColorIndex = UserDefaults.standard.integer(forKey: accentColorKey)
        self.hasCustomAccentColor = UserDefaults.standard.bool(forKey: hasCustomAccentColorKey)
    }

    /// Select a custom accent color - this sets hasCustomAccentColor to true
    func selectColor(_ option: AccentColorOption) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedAccentColor = option
            hasCustomAccentColor = true
        }
    }

    /// Reset to use the style's default accent color
    func resetToStyleDefault() {
        withAnimation(.easeInOut(duration: 0.2)) {
            hasCustomAccentColor = false
        }
    }

    /// Sync the selected accent color to match a style's default (used when changing styles)
    /// This does NOT set hasCustomAccentColor, it just updates the stored color for display purposes
    func syncToStyleDefault(hex: String) {
        if let option = AccentColorOption.from(hex: hex) {
            selectedAccentColorIndex = option.rawValue
        }
    }
}
