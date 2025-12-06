import Foundation

/// App configuration that reads from Info.plist or falls back to defaults.
/// To configure:
/// 1. Add SUPABASE_URL and SUPABASE_ANON_KEY to your xcconfig file
/// 2. Reference them in your Info.plist or build settings
/// 3. Or set them as environment variables for local development
enum AppConfiguration {

    // MARK: - Supabase Configuration

    static var supabaseURL: URL {
        guard let urlString = configValue(for: "SUPABASE_URL"),
              let url = URL(string: urlString) else {
            // Fallback for development - remove in production
            #if DEBUG
            return URL(string: "https://qjnthlgkqjqrtbkromjx.supabase.co")!
            #else
            fatalError("SUPABASE_URL not configured. Add it to your xcconfig or Info.plist.")
            #endif
        }
        return url
    }

    static var supabaseAnonKey: String {
        guard let key = configValue(for: "SUPABASE_ANON_KEY"), !key.isEmpty else {
            // Fallback for development - remove in production
            #if DEBUG
            return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFqbnRobGdrcWpxcnRia3JvbWp4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ1MDIxMjQsImV4cCI6MjA4MDA3ODEyNH0.WAW-_mb-C5DSXVx0Iwvo5_eXp3b0bFJ5-CSAr5cZOjo"
            #else
            fatalError("SUPABASE_ANON_KEY not configured. Add it to your xcconfig or Info.plist.")
            #endif
        }
        return key
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
