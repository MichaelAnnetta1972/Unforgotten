//
//  ToDoItem.swift
//  Unforgotten
//
//  Created on 2025-12-18
//

import Foundation

struct ToDoItem: Identifiable, Codable, Equatable {
    var id: UUID
    var listId: UUID
    var text: String
    var isCompleted: Bool
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case listId = "list_id"
        case text
        case isCompleted = "is_completed"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: UUID = UUID(),
        listId: UUID,
        text: String,
        isCompleted: Bool = false,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.listId = listId
        self.text = text
        self.isCompleted = isCompleted
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
