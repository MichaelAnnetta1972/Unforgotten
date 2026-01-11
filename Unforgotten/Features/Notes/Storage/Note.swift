import SwiftUI
import SwiftData

// MARK: - Note Model (SwiftData)
/// Core note model stored locally with SwiftData
@Model
final class LocalNote {
    // MARK: - Properties

    /// Unique identifier for local storage
    var id: UUID

    /// Note title
    var title: String

    /// Rich text content stored as Data (attributed string)
    var content: Data

    /// Plain text version for search and preview
    var contentPlainText: String

    /// Visual theme for the note
    var theme: String

    /// Creation timestamp
    var createdAt: Date

    /// Last modification timestamp
    var updatedAt: Date

    /// Whether the note is pinned to top
    var isPinned: Bool

    /// Whether the note has been synced to Supabase
    var isSynced: Bool

    /// Remote ID from Supabase (nil if not yet synced)
    var supabaseId: String?

    /// Account ID for multi-account support
    var accountId: UUID?

    // MARK: - Initialization

    init(
        title: String = "",
        theme: NoteTheme = .standard,
        accountId: UUID? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.content = Data()
        self.contentPlainText = ""
        self.theme = theme.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isPinned = false
        self.isSynced = false
        self.supabaseId = nil
        self.accountId = accountId
    }

    // MARK: - Computed Properties

    /// Get the NoteTheme enum value
    var noteTheme: NoteTheme {
        get { NoteTheme(rawValue: theme) ?? .standard }
        set { theme = newValue.rawValue }
    }

    /// Display title (with fallback for empty)
    var displayTitle: String {
        title.isEmpty ? "Untitled Note" : title
    }

    /// Preview of content for list display
    var previewContent: String {
        let trimmed = contentPlainText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "No additional text"
        }
        if trimmed.count > 100 {
            return String(trimmed.prefix(100)) + "..."
        }
        return trimmed
    }

    /// First line of content for preview
    var firstLine: String {
        let lines = contentPlainText.components(separatedBy: .newlines)
        if let first = lines.first, !first.isEmpty {
            return String(first.prefix(50))
        }
        return ""
    }

    /// Formatted date for display
    var formattedDate: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(updatedAt) {
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: updatedAt)
        } else if calendar.isDateInYesterday(updatedAt) {
            return "Yesterday"
        } else if calendar.isDate(updatedAt, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE"
            return formatter.string(from: updatedAt)
        } else if calendar.isDate(updatedAt, equalTo: Date(), toGranularity: .year) {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: updatedAt)
        } else {
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: updatedAt)
        }
    }

    // MARK: - Content Management

    /// Update content from attributed string
    func setContent(_ attributedString: NSAttributedString) {
        do {
            let data = try attributedString.data(
                from: NSRange(location: 0, length: attributedString.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
            self.content = data
            self.contentPlainText = attributedString.string
            self.updatedAt = Date()
            self.isSynced = false
        } catch {
            #if DEBUG
            print("Error encoding attributed string: \(error)")
            #endif
        }
    }

    /// Get content as attributed string
    func getAttributedContent() -> NSAttributedString {
        guard !content.isEmpty else {
            return NSAttributedString(string: "")
        }

        do {
            let attributedString = try NSAttributedString(
                data: content,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            )
            return attributedString
        } catch {
            #if DEBUG
            print("Error decoding attributed string: \(error)")
            #endif
            return NSAttributedString(string: contentPlainText)
        }
    }

    /// Update plain text content (for simple edits)
    func setPlainTextContent(_ text: String) {
        self.contentPlainText = text
        // Create attributed string from plain text
        let attributedString = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 17),
                .foregroundColor: UIColor.label
            ]
        )
        do {
            let data = try attributedString.data(
                from: NSRange(location: 0, length: attributedString.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
            self.content = data
        } catch {
            #if DEBUG
            print("Error encoding plain text: \(error)")
            #endif
        }
        self.updatedAt = Date()
        self.isSynced = false
    }

    // MARK: - Sync Helpers

    /// Mark as needing sync
    func markAsModified() {
        self.updatedAt = Date()
        self.isSynced = false
    }

    /// Mark as synced with remote ID
    func markAsSynced(remoteId: String) {
        self.supabaseId = remoteId
        self.isSynced = true
    }
}

// MARK: - Sync Status
enum SyncStatus: String, CaseIterable {
    case pending = "pending"
    case syncing = "syncing"
    case synced = "synced"
    case failed = "failed"

    var icon: String {
        switch self {
        case .pending: return "icloud.slash"
        case .syncing: return "arrow.triangle.2.circlepath.icloud"
        case .synced: return "checkmark.icloud"
        case .failed: return "exclamationmark.icloud"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .secondary
        case .syncing: return .blue
        case .synced: return .green
        case .failed: return .red
        }
    }
}
