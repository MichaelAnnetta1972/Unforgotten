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
}

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
}
