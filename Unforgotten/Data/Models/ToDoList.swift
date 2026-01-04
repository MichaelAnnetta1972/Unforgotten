//
//  ToDoList.swift
//  Unforgotten
//
//  Created on 2025-12-18
//

import Foundation

struct ToDoList: Identifiable, Equatable {
    var id: UUID
    var accountId: UUID
    var title: String
    var listType: String?
    var createdAt: Date
    var updatedAt: Date

    var items: [ToDoItem]

    init(
        id: UUID = UUID(),
        accountId: UUID,
        title: String,
        listType: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        items: [ToDoItem] = []
    ) {
        self.id = id
        self.accountId = accountId
        self.title = title
        self.listType = listType
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.items = items
    }

    var completedCount: Int {
        items.filter { $0.isCompleted }.count
    }

    var totalCount: Int {
        items.count
    }

    var progressText: String {
        "\(completedCount)/\(totalCount)"
    }
}

// MARK: - Codable Conformance
extension ToDoList: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case accountId = "account_id"
        case title
        case listType = "list_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        accountId = try container.decode(UUID.self, forKey: .accountId)
        title = try container.decode(String.self, forKey: .title)
        listType = try container.decodeIfPresent(String.self, forKey: .listType)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        items = [] // Items are loaded separately
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(accountId, forKey: .accountId)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(listType, forKey: .listType)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        // items are not encoded - they're managed separately
    }
}
