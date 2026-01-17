//
//  ToDoListDetailViewModel.swift
//  Unforgotten
//
//  Created on 2025-12-18
//

import Foundation

@MainActor
class ToDoListDetailViewModel: ObservableObject {
    @Published var list: ToDoList
    @Published var listTitle: String
    @Published var selectedType: String?
    @Published var items: [ToDoItem] = []
    @Published var availableTypes: [ToDoListType] = []
    @Published var isLoading = false
    @Published var error: Error?

    private var repository: ToDoRepositoryProtocol?
    private var accountId: UUID?

    /// Default type names shown when user has no custom types
    private static let defaultTypeNames = ["Personal", "Shopping", "Work", "Errands"]

    var sortedItems: [ToDoItem] {
        items.sorted { item1, item2 in
            // Completed items go to the bottom
            if item1.isCompleted != item2.isCompleted {
                return !item1.isCompleted
            }
            // Within same completion status, sort by sortOrder
            return item1.sortOrder < item2.sortOrder
        }
    }

    init(list: ToDoList) {
        self.list = list
        self.listTitle = list.title
        self.selectedType = list.listType
        self.items = list.items
    }

    func loadData(appState: AppState) async {
        guard let accountId = appState.currentAccount?.id else { return }
        self.accountId = accountId

        // Initialize repository if needed
        if repository == nil {
            repository = ToDoRepository()
        }

        isLoading = true
        defer { isLoading = false }

        do {
            async let fetchedItems = repository?.getItems(listId: list.id)
            async let fetchedTypes = repository?.getListTypes(accountId: accountId)

            items = try await fetchedItems ?? []
            var types = try await fetchedTypes ?? []

            // If no types exist, create default types for the user
            if types.isEmpty {
                types = await createDefaultTypes(accountId: accountId)
            }

            availableTypes = types
        } catch {
            self.error = error
        }
    }

    /// Creates default list types for a new user
    private func createDefaultTypes(accountId: UUID) async -> [ToDoListType] {
        guard let repository = repository else { return [] }

        var createdTypes: [ToDoListType] = []
        for name in Self.defaultTypeNames {
            do {
                let newType = try await repository.createListType(accountId: accountId, name: name)
                createdTypes.append(newType)
            } catch {
                // Continue with other types even if one fails
                #if DEBUG
                print("Failed to create default type '\(name)': \(error)")
                #endif
            }
        }
        return createdTypes
    }

    func saveTitle() {
        guard let repository = repository else { return }
        list.title = listTitle

        Task {
            do {
                try await repository.updateList(list)
            } catch {
                self.error = error
            }
        }
    }

    func saveType() {
        guard let repository = repository else { return }
        list.listType = selectedType

        Task {
            do {
                try await repository.updateList(list)
            } catch {
                self.error = error
            }
        }
    }

    func addNewItem() {
        guard let repository = repository else { return }
        let sortOrder = (items.map { $0.sortOrder }.max() ?? -1) + 1

        Task {
            do {
                let newItem = try await repository.createItem(
                    listId: list.id,
                    text: "",
                    sortOrder: sortOrder
                )
                items.append(newItem)
            } catch {
                self.error = error
            }
        }
    }

    func addNewItemWithText(_ text: String) {
        guard let repository = repository else { return }
        let sortOrder = (items.map { $0.sortOrder }.max() ?? -1) + 1

        Task {
            do {
                let newItem = try await repository.createItem(
                    listId: list.id,
                    text: text,
                    sortOrder: sortOrder
                )
                items.append(newItem)
            } catch {
                self.error = error
            }
        }
    }

    func toggleItem(_ item: ToDoItem) {
        guard let repository = repository else { return }

        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isCompleted.toggle()
            items[index].updatedAt = Date()

            Task {
                do {
                    try await repository.updateItem(items[index])
                } catch {
                    self.error = error
                }
            }
        }
    }

    func updateItemText(_ item: ToDoItem, text: String) {
        guard let repository = repository else { return }

        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].text = text
            items[index].updatedAt = Date()

            // Debounce the save
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                do {
                    try await repository.updateItem(items[index])
                } catch {
                    self.error = error
                }
            }
        }
    }

    func deleteItem(_ item: ToDoItem) {
        guard let repository = repository else { return }

        Task {
            do {
                try await repository.deleteItem(id: item.id)
                items.removeAll { $0.id == item.id }
            } catch {
                self.error = error
            }
        }
    }

    func moveItems(from source: IndexSet, to destination: Int) {
        guard let repository = repository else { return }

        var sortedItems = self.sortedItems
        sortedItems.move(fromOffsets: source, toOffset: destination)

        // Update sort orders
        for (index, item) in sortedItems.enumerated() {
            if let itemIndex = items.firstIndex(where: { $0.id == item.id }) {
                items[itemIndex].sortOrder = index
            }
        }

        Task {
            do {
                try await repository.reorderItems(listId: list.id, items: items)
            } catch {
                self.error = error
            }
        }
    }

    func addNewType(name: String) {
        guard let accountId = accountId, let repository = repository, !name.isEmpty else { return }

        Task {
            do {
                let newType = try await repository.createListType(accountId: accountId, name: name)
                availableTypes.append(newType)
            } catch {
                self.error = error
            }
        }
    }

    func deleteType(_ type: ToDoListType) async {
        guard let repository = repository else { return }

        do {
            try await repository.deleteListType(id: type.id)
            availableTypes.removeAll { $0.id == type.id }
            // If the deleted type was selected, clear the selection
            if selectedType == type.name {
                selectedType = nil
            }
        } catch {
            self.error = error
        }
    }

    func moveItemUp(_ item: ToDoItem) {
        let sorted = sortedItems
        guard let currentIndex = sorted.firstIndex(where: { $0.id == item.id }),
              currentIndex > 0 else { return }

        let previousItem = sorted[currentIndex - 1]

        // Swap sort orders
        if let currentItemIndex = items.firstIndex(where: { $0.id == item.id }),
           let previousItemIndex = items.firstIndex(where: { $0.id == previousItem.id }) {
            let tempOrder = items[currentItemIndex].sortOrder
            items[currentItemIndex].sortOrder = items[previousItemIndex].sortOrder
            items[previousItemIndex].sortOrder = tempOrder

            // Save changes
            Task {
                guard let repository = repository else { return }
                do {
                    try await repository.reorderItems(listId: list.id, items: items)
                } catch {
                    self.error = error
                }
            }
        }
    }

    func moveItemDown(_ item: ToDoItem) {
        let sorted = sortedItems
        guard let currentIndex = sorted.firstIndex(where: { $0.id == item.id }),
              currentIndex < sorted.count - 1 else { return }

        let nextItem = sorted[currentIndex + 1]

        // Swap sort orders
        if let currentItemIndex = items.firstIndex(where: { $0.id == item.id }),
           let nextItemIndex = items.firstIndex(where: { $0.id == nextItem.id }) {
            let tempOrder = items[currentItemIndex].sortOrder
            items[currentItemIndex].sortOrder = items[nextItemIndex].sortOrder
            items[nextItemIndex].sortOrder = tempOrder

            // Save changes
            Task {
                guard let repository = repository else { return }
                do {
                    try await repository.reorderItems(listId: list.id, items: items)
                } catch {
                    self.error = error
                }
            }
        }
    }

    func deleteList() async {
        guard let repository = repository else { return }

        do {
            try await repository.deleteList(id: list.id)
        } catch {
            self.error = error
        }
    }
}
