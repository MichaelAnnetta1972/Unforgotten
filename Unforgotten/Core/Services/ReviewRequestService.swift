import Foundation
import StoreKit
import UIKit

/// Manages when to ask the user to rate the app on the App Store.
///
/// Apple allows at most 3 prompts per user per 365 days. The system decides
/// whether the dialog actually appears — we just request it at good moments.
/// See: https://developer.apple.com/documentation/storekit/requesting_app_store_reviews
@MainActor
final class ReviewRequestService {
    static let shared = ReviewRequestService()

    // MARK: - Keys
    private let eventCountKey = "review_significantEventCount"
    private let lastRequestDateKey = "review_lastRequestDate"
    private let firstLaunchDateKey = "review_firstLaunchDate"
    private let lastPromptedVersionKey = "review_lastPromptedAppVersion"

    // MARK: - Thresholds
    /// Minimum number of significant events before we consider prompting.
    private let minimumEventsBeforePrompt = 8
    /// Minimum days since first launch before prompting (let users experience value first).
    private let minimumDaysSinceFirstLaunch = 5
    /// Minimum days between prompts (on top of Apple's 3-per-year limit).
    private let minimumDaysBetweenPrompts = 90

    private init() {
        // Record first launch date on first use
        if UserDefaults.standard.object(forKey: firstLaunchDateKey) == nil {
            UserDefaults.standard.set(Date(), forKey: firstLaunchDateKey)
        }
    }

    // MARK: - Public API

    /// Record a "significant event" — a moment where the user got real value from the app.
    /// Examples: logging a medication, completing a mood entry, adding a profile.
    /// Call this from meaningful flows, not from every tap.
    func recordSignificantEvent() {
        let current = UserDefaults.standard.integer(forKey: eventCountKey)
        UserDefaults.standard.set(current + 1, forKey: eventCountKey)
    }

    /// Record a significant event and, if conditions are met, request a review.
    /// Safe to call frequently — the gating logic ensures Apple's prompt is only
    /// triggered at appropriate moments.
    func recordSignificantEventAndMaybeRequest() {
        recordSignificantEvent()
        requestReviewIfAppropriate()
    }

    /// Request a review if our heuristics say it's a good moment.
    /// Even if we call it, iOS may silently ignore it based on its own limits.
    func requestReviewIfAppropriate() {
        guard shouldRequestReview() else { return }

        // Get the active window scene to present on
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
            return
        }

        // Delay slightly so the prompt doesn't collide with other UI transitions
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            SKStoreReviewController.requestReview(in: scene)
            self.markRequestMade()
        }
    }

    /// Open the App Store write-review page directly.
    /// Use this for a manual "Rate Us" link in Settings.
    func openAppStoreReviewPage() {
        guard let url = URL(string: AppConfiguration.appStoreReviewURL) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Gating Logic

    private func shouldRequestReview() -> Bool {
        // 1. Enough significant events?
        let eventCount = UserDefaults.standard.integer(forKey: eventCountKey)
        guard eventCount >= minimumEventsBeforePrompt else { return false }

        // 2. Been using the app long enough?
        if let firstLaunch = UserDefaults.standard.object(forKey: firstLaunchDateKey) as? Date {
            let daysSinceFirstLaunch = Calendar.current.dateComponents([.day], from: firstLaunch, to: Date()).day ?? 0
            guard daysSinceFirstLaunch >= minimumDaysSinceFirstLaunch else { return false }
        }

        // 3. Not prompted too recently?
        if let lastRequest = UserDefaults.standard.object(forKey: lastRequestDateKey) as? Date {
            let daysSinceLastRequest = Calendar.current.dateComponents([.day], from: lastRequest, to: Date()).day ?? 0
            guard daysSinceLastRequest >= minimumDaysBetweenPrompts else { return false }
        }

        // 4. Haven't already prompted for this exact version?
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let lastPromptedVersion = UserDefaults.standard.string(forKey: lastPromptedVersionKey) ?? ""
        guard currentVersion != lastPromptedVersion else { return false }

        return true
    }

    private func markRequestMade() {
        UserDefaults.standard.set(Date(), forKey: lastRequestDateKey)
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        UserDefaults.standard.set(currentVersion, forKey: lastPromptedVersionKey)
    }
}
