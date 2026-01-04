import Foundation
import SwiftUI

// MARK: - Preferences Sync Service
/// Coordinates syncing user preferences (header style, accent color, feature visibility)
/// between local managers and Supabase for cross-device sync
@MainActor
final class PreferencesSyncService: ObservableObject {
    static let shared = PreferencesSyncService()

    private let repository = UserPreferencesRepository()
    private var isSyncing = false

    // References to the managers (set during initialization)
    private weak var userPreferences: UserPreferences?
    private weak var headerStyleManager: HeaderStyleManager?
    private weak var featureVisibilityManager: FeatureVisibilityManager?

    private init() {}

    // MARK: - Configuration

    /// Configure the service with manager references
    func configure(
        userPreferences: UserPreferences,
        headerStyleManager: HeaderStyleManager,
        featureVisibilityManager: FeatureVisibilityManager
    ) {
        self.userPreferences = userPreferences
        self.headerStyleManager = headerStyleManager
        self.featureVisibilityManager = featureVisibilityManager
    }

    // MARK: - Load Preferences from Remote

    /// Load preferences from Supabase and apply to local managers
    /// Called when app launches or when switching accounts
    func loadFromRemote(userId: UUID, accountId: UUID) async {
        do {
            if let remote = try await repository.getPreferences(userId: userId, accountId: accountId) {
                applyRemotePreferences(remote)
                print("✅ Loaded preferences from Supabase")
            } else {
                // No remote preferences exist yet - save current local preferences to remote
                print("📝 No remote preferences found, saving current local settings")
                await saveToRemote(userId: userId, accountId: accountId)
            }
        } catch {
            print("⚠️ Error loading preferences from Supabase: \(error)")
            // Continue using local preferences
        }
    }

    /// Apply remote preferences to local managers
    private func applyRemotePreferences(_ remote: UserPreferencesRecord) {
        guard let userPrefs = userPreferences,
              let headerManager = headerStyleManager,
              let featureManager = featureVisibilityManager else {
            print("⚠️ Managers not configured for preferences sync")
            return
        }

        // Apply header style
        if let style = HeaderStyle.style(for: remote.headerStyleId) {
            headerManager.currentStyle = style
        }

        // Apply accent color
        userPrefs.selectedAccentColorIndex = remote.accentColorIndex
        userPrefs.hasCustomAccentColor = remote.hasCustomAccentColor

        // Apply feature visibility
        for (featureId, isVisible) in remote.featureVisibility {
            if let feature = Feature(rawValue: featureId) {
                featureManager.setVisibility(feature, isVisible: isVisible)
            }
        }
    }

    // MARK: - Save Preferences to Remote

    /// Save current local preferences to Supabase
    func saveToRemote(userId: UUID, accountId: UUID) async {
        // Prevent concurrent saves
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        guard let userPrefs = userPreferences,
              let headerManager = headerStyleManager,
              let featureManager = featureVisibilityManager else {
            print("⚠️ Managers not configured for preferences sync")
            return
        }

        // Build feature visibility dictionary
        var featureVisibility: [String: Bool] = [:]
        for feature in Feature.allCases {
            featureVisibility[feature.rawValue] = featureManager.isVisible(feature)
        }

        do {
            _ = try await repository.upsertPreferences(
                userId: userId,
                accountId: accountId,
                headerStyleId: headerManager.currentStyle.id,
                accentColorIndex: userPrefs.selectedAccentColorIndex,
                hasCustomAccentColor: userPrefs.hasCustomAccentColor,
                featureVisibility: featureVisibility
            )
            print("✅ Saved preferences to Supabase")
        } catch {
            print("⚠️ Error saving preferences to Supabase: \(error)")
        }
    }

    // MARK: - Sync Individual Changes

    /// Called when header style changes
    func syncHeaderStyle(userId: UUID, accountId: UUID) async {
        await saveToRemote(userId: userId, accountId: accountId)
    }

    /// Called when accent color changes
    func syncAccentColor(userId: UUID, accountId: UUID) async {
        await saveToRemote(userId: userId, accountId: accountId)
    }

    /// Called when feature visibility changes
    func syncFeatureVisibility(userId: UUID, accountId: UUID) async {
        await saveToRemote(userId: userId, accountId: accountId)
    }
}
