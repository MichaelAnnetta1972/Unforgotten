import SwiftUI
import SwiftData

// MARK: - Local ToDo List Model
/// SwiftData model for ToDoList, stored locally for offline support
@Model
final class LocalToDoList {
    // MARK: - Core Properties
    var id: UUID
    var accountId: UUID
    var title: String
    var listType: String?
    var dueDate: Date?
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Sync Properties
    var isSynced: Bool
    var locallyDeleted: Bool

    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        accountId: UUID,
        title: String,
        listType: String? = nil,
        dueDate: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isSynced: Bool = false,
        locallyDeleted: Bool = false
    ) {
        self.id = id
        self.accountId = accountId
        self.title = title
        self.listType = listType
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isSynced = isSynced
        self.locallyDeleted = locallyDeleted
    }

    // MARK: - Conversion from Remote
    convenience init(from remote: ToDoList) {
        self.init(
            id: remote.id,
            accountId: remote.accountId,
            title: remote.title,
            listType: remote.listType,
            dueDate: remote.dueDate,
            createdAt: remote.createdAt,
            updatedAt: remote.updatedAt,
            isSynced: true,
            locallyDeleted: false
        )
    }

    // MARK: - Conversion to Remote
    func toRemote(with items: [ToDoItem] = []) -> ToDoList {
        ToDoList(
            id: id,
            accountId: accountId,
            title: title,
            listType: listType,
            dueDate: dueDate,
            createdAt: createdAt,
            updatedAt: updatedAt,
            items: items
        )
    }

    // MARK: - Update from Remote
    func update(from remote: ToDoList) {
        self.accountId = remote.accountId
        self.title = remote.title
        self.listType = remote.listType
        self.dueDate = remote.dueDate
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
