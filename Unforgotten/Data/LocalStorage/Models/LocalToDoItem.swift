import SwiftUI
import SwiftData

// MARK: - Local ToDo Item Model
/// SwiftData model for ToDoItem, stored locally for offline support
@Model
final class LocalToDoItem {
    // MARK: - Core Properties
    var id: UUID
    var listId: UUID
    var text: String
    var isCompleted: Bool
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Sync Properties
    var isSynced: Bool
    var locallyDeleted: Bool

    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        listId: UUID,
        text: String,
        isCompleted: Bool = false,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isSynced: Bool = false,
        locallyDeleted: Bool = false
    ) {
        self.id = id
        self.listId = listId
        self.text = text
        self.isCompleted = isCompleted
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isSynced = isSynced
        self.locallyDeleted = locallyDeleted
    }

    // MARK: - Conversion from Remote
    convenience init(from remote: ToDoItem) {
        self.init(
            id: remote.id,
            listId: remote.listId,
            text: remote.text,
            isCompleted: remote.isCompleted,
            sortOrder: remote.sortOrder,
            createdAt: remote.createdAt,
            updatedAt: remote.updatedAt,
            isSynced: true,
            locallyDeleted: false
        )
    }

    // MARK: - Conversion to Remote
    func toRemote() -> ToDoItem {
        ToDoItem(
            id: id,
            listId: listId,
            text: text,
            isCompleted: isCompleted,
            sortOrder: sortOrder,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    // MARK: - Update from Remote
    func update(from remote: ToDoItem) {
        self.listId = remote.listId
        self.text = remote.text
        self.isCompleted = remote.isCompleted
        self.sortOrder = remote.sortOrder
        self.createdAt = remote.createdAt
        self.updatedAt = remote.updatedAt
        self.isSynced = true
    }

    // MARK: - Sync Helpers
    func markAsModified() {
        self.updatedAt = Date()
        self.isSynced = false
    }
}
