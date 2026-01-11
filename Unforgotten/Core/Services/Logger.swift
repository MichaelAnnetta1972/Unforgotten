import Foundation
import os.log

/// App-wide logger that only outputs in DEBUG builds.
/// Use this instead of print() throughout the app.
enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.unforgotten"

    // MARK: - Log Categories
    private static let authLogger = Logger(subsystem: subsystem, category: "Auth")
    private static let dataLogger = Logger(subsystem: subsystem, category: "Data")
    private static let syncLogger = Logger(subsystem: subsystem, category: "Sync")
    private static let notificationLogger = Logger(subsystem: subsystem, category: "Notifications")
    private static let uiLogger = Logger(subsystem: subsystem, category: "UI")
    private static let generalLogger = Logger(subsystem: subsystem, category: "General")

    enum Category {
        case auth
        case data
        case sync
        case notifications
        case ui
        case general

        fileprivate var logger: Logger {
            switch self {
            case .auth: return authLogger
            case .data: return dataLogger
            case .sync: return syncLogger
            case .notifications: return notificationLogger
            case .ui: return uiLogger
            case .general: return generalLogger
            }
        }
    }

    // MARK: - Logging Methods

    /// Log debug information (only in DEBUG builds)
    static func debug(_ message: String, category: Category = .general) {
        #if DEBUG
        category.logger.debug("\(message, privacy: .public)")
        #endif
    }

    /// Log informational messages
    static func info(_ message: String, category: Category = .general) {
        #if DEBUG
        category.logger.info("\(message, privacy: .public)")
        #endif
    }

    /// Log warnings
    static func warning(_ message: String, category: Category = .general) {
        #if DEBUG
        category.logger.warning("\(message, privacy: .public)")
        #endif
    }

    /// Log errors (these may be logged in release for crash reporting)
    static func error(_ message: String, category: Category = .general) {
        #if DEBUG
        category.logger.error("\(message, privacy: .public)")
        #endif
    }

    /// Log with custom emoji prefix (for backwards compatibility)
    static func log(_ emoji: String, _ message: String, category: Category = .general) {
        #if DEBUG
        print("\(emoji) \(message)")
        #endif
    }
}

// MARK: - Convenience Functions

/// Debug print that only outputs in DEBUG builds
func debugPrint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    let output = items.map { "\($0)" }.joined(separator: separator)
    print(output, terminator: terminator)
    #endif
}
