//
//  ToDoListsViewModel.swift
//  Unforgotten
//
//  Created on 2025-12-18
//

import Foundation

@MainActor
class ToDoListsViewModel: ObservableObject {
    @Published var lists: [ToDoList] = []
    @Published var listTypes: [ToDoListType] = []
    @Published var isLoading = false
    @Published var error: Error?

    private var repository: ToDoRepositoryProtocol?
    private var accountId: UUID?

    /// Unique types derived from existing lists (for filtering)
    var availableFilterTypes: [String] {
        let types = lists.compactMap { $0.listType }
        return Array(Set(types)).sorted()
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
            async let fetchedLists = repository?.getLists(accountId: accountId)
            async let fetchedTypes = repository?.getListTypes(accountId: accountId)

            lists = try await fetchedLists ?? []
            listTypes = try await fetchedTypes ?? []
        } catch {
            self.error = error
        }
    }

    func createList(title: String, type: String?) {
        guard let accountId = accountId, let repository = repository else { return }

        Task {
            do {
                let newList = try await repository.createList(
                    accountId: accountId,
                    title: title,
                    listType: type
                )
                lists.append(newList)
            } catch {
                self.error = error
            }
        }
    }

    func createListAsync(title: String, type: String?) async -> ToDoList? {
        guard let accountId = accountId, let repository = repository else { return nil }

        do {
            let newList = try await repository.createList(
                accountId: accountId,
                title: title,
                listType: type
            )
            lists.append(newList)
            return newList
        } catch {
            self.error = error
            return nil
        }
    }

    func deleteList(_ list: ToDoList) {
        guard let repository = repository else { return }

        Task {
            do {
                try await repository.deleteList(id: list.id)
                lists.removeAll { $0.id == list.id }
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
                listTypes.append(newType)
            } catch {
                self.error = error
            }
        }
    }

    func deleteType(_ type: ToDoListType) async {
        guard let repository = repository else { return }

        do {
            try await repository.deleteListType(id: type.id)
            listTypes.removeAll { $0.id == type.id }
        } catch {
            self.error = error
        }
    }
}
