import SwiftUI

// MARK: - User Preferences Manager
@Observable
class UserPreferences {
    private let accentColorHexKey = "user_accent_color_hex"
    private let hasCustomAccentColorKey = "has_custom_accent_color"
    private let legacyAccentColorIndexKey = "user_accent_color_index"
    private let recentColorHexesKeyPrefix = "recent_accent_color_hexes"
    private let maxRecentColors = 5

    /// Current user ID for sync (set by AppState)
    var currentUserId: UUID? {
        didSet {
            // Reload user-scoped recent colours when the user changes
            if oldValue != currentUserId {
                loadRecentColors()
            }
        }
    }
    /// Current account ID for sync (set by AppState)
    var currentAccountId: UUID?

    /// Returns a user-scoped UserDefaults key for recent colours
    private var recentColorHexesKey: String {
        if let userId = currentUserId {
            return "\(recentColorHexesKeyPrefix)_\(userId.uuidString)"
        }
        return recentColorHexesKeyPrefix
    }

    var selectedAccentColorHex: String {
        didSet {
            UserDefaults.standard.set(selectedAccentColorHex, forKey: accentColorHexKey)
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

    /// The user's most recent 5 custom accent colour hex values (newest first)
    var recentColorHexes: [String] {
        didSet {
            UserDefaults.standard.set(recentColorHexes, forKey: recentColorHexesKey)
        }
    }

    /// The user's recent colours as SwiftUI Color values
    var recentColors: [Color] {
        recentColorHexes.map { Color(hex: $0) }
    }

    /// Trigger async sync to Supabase
    private func triggerSync() {
        guard let userId = currentUserId, let accountId = currentAccountId else { return }
        Task { @MainActor in
            await PreferencesSyncService.shared.syncAccentColor(userId: userId, accountId: accountId)
        }
    }

    var accentColor: Color {
        Color(hex: selectedAccentColorHex)
    }

    init() {
        let defaults = UserDefaults.standard

        // Check for new hex-based storage first
        if let existingHex = defaults.string(forKey: accentColorHexKey) {
            self.selectedAccentColorHex = existingHex
        } else {
            // Migrate from legacy integer index
            let legacyIndex = defaults.integer(forKey: legacyAccentColorIndexKey)
            let hex = Self.legacyIndexToHex(legacyIndex)
            self.selectedAccentColorHex = hex
            defaults.set(hex, forKey: accentColorHexKey)
            defaults.removeObject(forKey: legacyAccentColorIndexKey)
        }

        self.hasCustomAccentColor = defaults.bool(forKey: hasCustomAccentColorKey)
        // Recent colours are loaded when currentUserId is set (user-scoped)
        self.recentColorHexes = []
    }

    /// Loads recent colours from UserDefaults using the user-scoped key.
    /// Migrates any existing data from the old global key on first load.
    private func loadRecentColors() {
        let defaults = UserDefaults.standard
        let globalKey = recentColorHexesKeyPrefix

        if let userColors = defaults.stringArray(forKey: recentColorHexesKey), !userColors.isEmpty {
            recentColorHexes = userColors
        } else if let globalColors = defaults.stringArray(forKey: globalKey), !globalColors.isEmpty,
                  currentUserId != nil {
            // Migrate from old global key to user-scoped key
            recentColorHexes = globalColors
            defaults.removeObject(forKey: globalKey)
        } else {
            recentColorHexes = []
        }
    }

    /// Apply a custom accent color live without saving to recent history.
    /// Use this during continuous interactions like dragging the colour picker.
    func applyColorLive(_ color: Color) {
        let hex = color.toHex()
        selectedAccentColorHex = hex
        hasCustomAccentColor = true
    }

    /// Select a custom accent color - this sets hasCustomAccentColor to true and saves to recent history.
    /// Use this when the user has committed to a final colour choice.
    func selectColor(_ color: Color) {
        let hex = color.toHex()
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedAccentColorHex = hex
            hasCustomAccentColor = true
        }
        addToRecentColors(hex: hex)
    }

    /// Adds a hex colour to the recent list, keeping only the last 5 unique entries
    private func addToRecentColors(hex: String) {
        var recent = recentColorHexes
        recent.removeAll { $0.lowercased() == hex.lowercased() }
        recent.insert(hex, at: 0)
        if recent.count > maxRecentColors {
            recent = Array(recent.prefix(maxRecentColors))
        }
        recentColorHexes = recent
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
        selectedAccentColorHex = hex
    }

    // MARK: - Legacy Migration

    /// Maps old AccentColorOption integer indices to hex strings.
    /// Used only for one-time migration from integer-based storage.
    private static func legacyIndexToHex(_ index: Int) -> String {
        switch index {
        case 0: return "FFD60A"   // yellow
        case 1: return "FF9F0A"   // orange
        case 2: return "FF6B6B"   // coral
        case 3: return "CE76B7"   // pink
        case 4: return "BF5AF2"   // purple
        case 5: return "0A84FF"   // blue
        case 6: return "64D2FF"   // cyan
        case 7: return "40C8E0"   // teal
        case 8: return "6A863E"   // green
        case 9: return "63E6BE"   // mint
        case 10: return "FFFFFF"  // white
        case 11: return "A7A7A7"  // grey
        case 12: return "98ACA4"  // sage
        case 13: return "7791A4"  // dusk
        case 14: return "565577"  // indigo
        default: return "FFD60A"  // fallback to yellow
        }
    }
}
