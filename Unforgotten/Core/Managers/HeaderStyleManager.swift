import SwiftUI

// MARK: - Header Style Manager
/// Manages the current header style selection and persists it to UserDefaults
@Observable
class HeaderStyleManager {
    private let styleIdKey = "selected_header_style_id"

    /// Current user ID for sync (set by AppState)
    var currentUserId: UUID?
    /// Current account ID for sync (set by AppState)
    var currentAccountId: UUID?

    /// The currently selected header style
    var currentStyle: HeaderStyle {
        didSet {
            UserDefaults.standard.set(currentStyle.id, forKey: styleIdKey)
            triggerSync()
        }
    }

    init() {
        // Load saved style ID or default to style one
        let savedId = UserDefaults.standard.string(forKey: styleIdKey) ?? HeaderStyle.defaultStyle.id
        self.currentStyle = HeaderStyle.style(for: savedId) ?? HeaderStyle.defaultStyle
    }

    /// Trigger async sync to Supabase
    private func triggerSync() {
        guard let userId = currentUserId, let accountId = currentAccountId else { return }
        Task { @MainActor in
            await PreferencesSyncService.shared.syncHeaderStyle(userId: userId, accountId: accountId)
        }
    }

    /// Select a new header style with animation
    func selectStyle(_ style: HeaderStyle) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStyle = style
        }
    }

    /// Get the asset for a specific page based on the current style
    func asset(for page: PageIdentifier) -> HeaderAsset {
        currentStyle.assets.asset(for: page)
    }

    /// Get the default accent color for the current style
    var defaultAccentColor: Color {
        currentStyle.defaultAccentColor
    }

    /// Get the default accent color hex for the current style
    var defaultAccentColorHex: String {
        currentStyle.defaultAccentColorHex
    }
}
