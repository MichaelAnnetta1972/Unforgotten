import Foundation

/// App configuration that reads from Info.plist or falls back to defaults.
///
/// ## Setup for Production
/// 1. Create a `Secrets.xcconfig` file (excluded from git) with:
///    ```
///    SUPABASE_URL = https://your-project.supabase.co
///    SUPABASE_ANON_KEY = your-anon-key
///    ```
/// 2. In Xcode, set the xcconfig file for your Release configuration
/// 3. Add these keys to Info.plist:
///    - SUPABASE_URL = $(SUPABASE_URL)
///    - SUPABASE_ANON_KEY = $(SUPABASE_ANON_KEY)
///
/// For App Store builds, the credentials should come from the xcconfig or Info.plist.
enum AppConfiguration {

    // MARK: - Supabase Configuration

    static var supabaseURL: URL {
        guard let urlString = configValue(for: "SUPABASE_URL"),
              let url = URL(string: urlString) else {
            fatalError("SUPABASE_URL not configured. Create a Secrets.xcconfig file with your Supabase URL. See Secrets.xcconfig.template for format.")
        }
        return url
    }

    static var supabaseAnonKey: String {
        guard let key = configValue(for: "SUPABASE_ANON_KEY"), !key.isEmpty else {
            fatalError("SUPABASE_ANON_KEY not configured. Create a Secrets.xcconfig file with your Supabase anon key. See Secrets.xcconfig.template for format.")
        }
        return key
    }

    // MARK: - App URLs

    /// Website URL for the app
    static let websiteURL = URL(string: "https://unforgottenapp.com")!

    /// Privacy policy URL
    static let privacyPolicyURL = URL(string: "https://unforgottenapp.com/privacy")!

    /// Terms of service URL
    static let termsOfServiceURL = URL(string: "https://unforgottenapp.com/terms")!

    /// Support email
    static let supportEmail = "support@unforgottenapp.com"

    /// Feedback and bug report email
    static let feedbackEmail = "feedback@unforgottenapp.com"

    /// App Store ID — replace with the real ID once the app is approved in App Store Connect.
    /// Find this in App Store Connect → your app → App Information → Apple ID.
    static let appStoreID = "6760533999"

    /// Deep link that opens the App Store write-review page for this app.
    static var appStoreReviewURL: String {
        "https://apps.apple.com/app/id\(appStoreID)?action=write-review"
    }

    // MARK: - Private Helpers

    /// Reads a configuration value from Info.plist or environment variables
    private static func configValue(for key: String) -> String? {
        // First try Info.plist
        if let value = Bundle.main.infoDictionary?[key] as? String,
           !value.isEmpty,
           !value.hasPrefix("$(") { // Not an unresolved variable
            return value
        }

        // Then try environment variables (useful for testing)
        if let value = ProcessInfo.processInfo.environment[key], !value.isEmpty {
            return value
        }

        return nil
    }
}
