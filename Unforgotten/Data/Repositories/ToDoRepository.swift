//
//  ToDoRepository.swift
//  Unforgotten
//
//  Created on 2025-12-18
//

import Foundation
import Supabase

protocol ToDoRepositoryProtocol {
    // List Types
    func getListTypes(accountId: UUID) async throws -> [ToDoListType]
    func createListType(accountId: UUID, name: String) async throws -> ToDoListType
    func deleteListType(id: UUID) async throws

    // Lists
    func getLists(accountId: UUID) async throws -> [ToDoList]
    func getList(id: UUID) async throws -> ToDoList?
    func createList(accountId: UUID, title: String, listType: String?, dueDate: Date?) async throws -> ToDoList
    func updateList(_ list: ToDoList) async throws
    func deleteList(id: UUID) async throws
    func getListsWithDueDates(accountId: UUID) async throws -> [ToDoList]

    // Items
    func getItems(listId: UUID) async throws -> [ToDoItem]
    func createItem(listId: UUID, text: String, sortOrder: Int) async throws -> ToDoItem
    func updateItem(_ item: ToDoItem) async throws
    func deleteItem(id: UUID) async throws
    func reorderItems(listId: UUID, items: [ToDoItem]) async throws

    // Sharing
    func getSharedListIds(userId: UUID) async throws -> [UUID]
    func getListsByIds(_ ids: [UUID]) async throws -> [ToDoList]
}

// MARK: - Date-Only Encoding Helper

/// Formats a Date as a "yyyy-MM-dd" string for date-only database columns.
/// This prevents timezone offsets from shifting the date by a day when
/// the default ISO8601 encoder converts local midnight to UTC.
private let dateOnlyFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    return formatter
}()

class ToDoRepository: ToDoRepositoryProtocol {
    private let client: SupabaseClient

    init() {
        self.client = SupabaseManager.shared.client
    }

    // MARK: - List Types

    func getListTypes(accountId: UUID) async throws -> [ToDoListType] {
        let response: [ToDoListType] = try await client
            .from(TableName.todoListTypes)
            .select()
            .eq("account_id", value: accountId.uuidString)
            .order("name")
            .execute()
            .value

        return response
    }

    func createListType(accountId: UUID, name: String) async throws -> ToDoListType {
        struct Insert: Encodable {
            let accountId: UUID
            let name: String

            enum CodingKeys: String, CodingKey {
                case accountId = "account_id"
                case name
            }
        }

        let insert = Insert(accountId: accountId, name: name)

        let response: ToDoListType = try await client
            .from(TableName.todoListTypes)
            .insert(insert)
            .select()
            .single()
            .execute()
            .value

        return response
    }

    func deleteListType(id: UUID) async throws {
        try await client
            .from(TableName.todoListTypes)
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Lists

    func getLists(accountId: UUID) async throws -> [ToDoList] {
        let lists: [ToDoList] = try await client
            .from(TableName.todoLists)
            .select()
            .eq("account_id", value: accountId.uuidString)
            .order("updated_at", ascending: false)
            .execute()
            .value

        // Fetch items for each list
        var listsWithItems: [ToDoList] = []
        for var list in lists {
            let items = try await getItems(listId: list.id)
            list.items = items
            listsWithItems.append(list)
        }

        return listsWithItems
    }

    func getList(id: UUID) async throws -> ToDoList? {
        var list: ToDoList = try await client
            .from(TableName.todoLists)
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value

        // Fetch items for the list
        let items = try await getItems(listId: list.id)
        list.items = items

        return list
    }

    func createList(accountId: UUID, title: String, listType: String?, dueDate: Date? = nil) async throws -> ToDoList {
        struct Insert: Encodable {
            let accountId: UUID
            let title: String
            let listType: String?
            let dueDate: Date?

            enum CodingKeys: String, CodingKey {
                case accountId = "account_id"
                case title
                case listType = "list_type"
                case dueDate = "due_date"
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(accountId, forKey: .accountId)
                try container.encode(title, forKey: .title)
                try container.encodeIfPresent(listType, forKey: .listType)
                // Encode as "yyyy-MM-dd" string to avoid timezone shift on DATE column
                if let dueDate = dueDate {
                    try container.encode(dateOnlyFormatter.string(from: dueDate), forKey: .dueDate)
                } else {
                    try container.encodeNil(forKey: .dueDate)
                }
            }
        }

        let insert = Insert(accountId: accountId, title: title, listType: listType, dueDate: dueDate)

        var list: ToDoList = try await client
            .from(TableName.todoLists)
            .insert(insert)
            .select()
            .single()
            .execute()
            .value

        list.items = []
        return list
    }

    func updateList(_ list: ToDoList) async throws {
        struct Update: Encodable {
            let title: String
            let listType: String?
            let dueDate: Date?

            enum CodingKeys: String, CodingKey {
                case title
                case listType = "list_type"
                case dueDate = "due_date"
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(title, forKey: .title)
                try container.encodeIfPresent(listType, forKey: .listType)
                // Encode as "yyyy-MM-dd" string to avoid timezone shift on DATE column
                if let dueDate = dueDate {
                    try container.encode(dateOnlyFormatter.string(from: dueDate), forKey: .dueDate)
                } else {
                    try container.encodeNil(forKey: .dueDate)
                }
            }
        }

        let update = Update(title: list.title, listType: list.listType, dueDate: list.dueDate)

        try await client
            .from(TableName.todoLists)
            .update(update)
            .eq("id", value: list.id.uuidString)
            .execute()
    }

    func deleteList(id: UUID) async throws {
        try await client
            .from(TableName.todoLists)
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    func getListsWithDueDates(accountId: UUID) async throws -> [ToDoList] {
        let lists: [ToDoList] = try await client
            .from(TableName.todoLists)
            .select()
            .eq("account_id", value: accountId.uuidString)
            .not("due_date", operator: .is, value: "null")
            .execute()
            .value

        return lists
    }

    // MARK: - Items

    func getItems(listId: UUID) async throws -> [ToDoItem] {
        let response: [ToDoItem] = try await client
            .from(TableName.todoItems)
            .select()
            .eq("list_id", value: listId.uuidString)
            .order("sort_order")
            .execute()
            .value

        return response
    }

    func createItem(listId: UUID, text: String, sortOrder: Int) async throws -> ToDoItem {
        struct Insert: Encodable {
            let listId: UUID
            let text: String
            let sortOrder: Int

            enum CodingKeys: String, CodingKey {
                case listId = "list_id"
                case text
                case sortOrder = "sort_order"
            }
        }

        let insert = Insert(listId: listId, text: text, sortOrder: sortOrder)

        let response: ToDoItem = try await client
            .from(TableName.todoItems)
            .insert(insert)
            .select()
            .single()
            .execute()
            .value

        return response
    }

    func updateItem(_ item: ToDoItem) async throws {
        struct Update: Encodable {
            let text: String
            let isCompleted: Bool
            let sortOrder: Int

            enum CodingKeys: String, CodingKey {
                case text
                case isCompleted = "is_completed"
                case sortOrder = "sort_order"
            }
        }

        let update = Update(
            text: item.text,
            isCompleted: item.isCompleted,
            sortOrder: item.sortOrder
        )

        try await client
            .from(TableName.todoItems)
            .update(update)
            .eq("id", value: item.id.uuidString)
            .execute()
    }

    func deleteItem(id: UUID) async throws {
        try await client
            .from(TableName.todoItems)
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    func reorderItems(listId: UUID, items: [ToDoItem]) async throws {
        // Update sort order for all items
        for item in items {
            try await updateItem(item)
        }
    }

    // MARK: - Sharing

    func getSharedListIds(userId: UUID) async throws -> [UUID] {
        let response = try await client
            .rpc("get_shared_todo_list_ids", params: ["p_user_id": userId.uuidString])
            .execute()

        let data = response.data
        guard !data.isEmpty else { return [] }

        let json = try JSONSerialization.jsonObject(with: data)

        // Format 1: Array of strings ["uuid1", "uuid2", ...]
        if let strings = json as? [String] {
            return strings.compactMap { UUID(uuidString: $0) }
        }

        // Format 2: Array of objects [{"get_shared_todo_list_ids": "uuid"}, ...]
        if let objects = json as? [[String: Any]] {
            return objects.compactMap { dict in
                if let uuidString = dict["get_shared_todo_list_ids"] as? String {
                    return UUID(uuidString: uuidString)
                }
                if let first = dict.values.first as? String {
                    return UUID(uuidString: first)
                }
                return nil
            }
        }

        return []
    }

    func getListsByIds(_ ids: [UUID]) async throws -> [ToDoList] {
        guard !ids.isEmpty else { return [] }

        let lists: [ToDoList] = try await client
            .from(TableName.todoLists)
            .select()
            .in("id", values: ids.map { $0.uuidString })
            .order("updated_at", ascending: false)
            .execute()
            .value

        // Fetch items for each list
        var listsWithItems: [ToDoList] = []
        for var list in lists {
            let items = try await getItems(listId: list.id)
            list.items = items
            listsWithItems.append(list)
        }

        return listsWithItems
    }
}
