import SwiftUI
import SwiftData

// MARK: - Notes Model Container
/// Configures the SwiftData container for notes storage
struct NotesContainerConfiguration {

    /// Creates the model container for notes
    /// - Returns: Configured ModelContainer for LocalNote
    static func createContainer() throws -> ModelContainer {
        let schema = Schema([
            LocalNote.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        return try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )
    }

    /// Creates an in-memory container for previews and testing
    static func createPreviewContainer() throws -> ModelContainer {
        let schema = Schema([
            LocalNote.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        return try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )
    }
}

// MARK: - Preview Sample Data
extension LocalNote {
    /// Sample notes for SwiftUI previews
    static func sampleNotes(in context: ModelContext) -> [LocalNote] {
        let notes: [LocalNote] = [
            {
                let note = LocalNote(title: "Gift Ideas for Mom", theme: .festive)
                note.isPinned = true
                note.setPlainTextContent("""
                Thinking about getting her a nice scarf this year.

                Ideas:
                • Cashmere scarf (blue or gray)
                • New cookbook
                • Spa gift card
                • Photo album of grandkids
                """)
                return note
            }(),
            {
                let note = LocalNote(title: "Grocery List", theme: .shopping)
                note.setPlainTextContent("""
                ☐ Milk
                ☐ Eggs
                ☐ Bread
                ☐ Butter
                ☐ Apples
                ☑ Coffee (done!)
                """)
                return note
            }(),
            {
                let note = LocalNote(title: "Beach Trip Planning", theme: .holidays)
                note.setPlainTextContent("""
                Trip to Myrtle Beach - July 15-22

                Things to pack:
                • Sunscreen
                • Beach chairs
                • Snorkeling gear
                • Books to read
                """)
                return note
            }(),
            {
                let note = LocalNote(title: "Project Tasks", theme: .work)
                note.setPlainTextContent("""
                Q1 Goals:

                1. Complete quarterly review
                2. Update team roadmap
                3. Schedule planning sessions
                4. Review budget proposals
                """)
                return note
            }(),
            {
                let note = LocalNote(title: "Family Recipes", theme: .family)
                note.setPlainTextContent("""
                Grandma's Apple Pie

                Ingredients:
                • 6 cups sliced apples
                • 3/4 cup sugar
                • 2 tbsp flour
                • 1 tsp cinnamon
                """)
                return note
            }(),
            {
                let note = LocalNote(title: "Meeting Notes", theme: .standard)
                note.setPlainTextContent("""
                Team meeting - Dec 10

                Action items:
                • Follow up with client
                • Review proposal
                • Schedule next call
                """)
                return note
            }()
        ]

        // Insert all notes into context
        for note in notes {
            context.insert(note)
        }

        return notes
    }
}

// MARK: - Environment Key for Notes Container
private struct NotesContainerKey: EnvironmentKey {
    static var defaultValue: ModelContainer?
}

extension EnvironmentValues {
    var notesContainer: ModelContainer? {
        get { self[NotesContainerKey.self] }
        set { self[NotesContainerKey.self] = newValue }
    }
}
