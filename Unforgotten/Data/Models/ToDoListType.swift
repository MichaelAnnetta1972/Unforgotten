//
//  ToDoListType.swift
//  Unforgotten
//
//  Created on 2025-12-18
//

import Foundation

struct ToDoListType: Identifiable, Codable, Equatable {
    var id: UUID
    var accountId: UUID
    var name: String
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case accountId = "account_id"
        case name
        case createdAt = "created_at"
    }

    init(
        id: UUID = UUID(),
        accountId: UUID,
        name: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.accountId = accountId
        self.name = name
        self.createdAt = createdAt
    }
}
