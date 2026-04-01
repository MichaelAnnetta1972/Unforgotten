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

            var ownLists = try await fetchedLists ?? []
            listTypes = try await fetchedTypes ?? []

            // Mark own lists that are shared with others
            let ownShares = try await appState.familyCalendarRepository.getAllSharesForAccount(accountId: accountId)
            let todoShares = ownShares.filter { $0.eventType == .todoList }

            for share in todoShares {
                if let index = ownLists.firstIndex(where: { $0.id == share.eventId }) {
                    ownLists[index].isSharedWithOthers = true
                    // Load shared member names
                    let members = try await appState.familyCalendarRepository.getMembersForShare(shareId: share.id)
                    let profiles = try await appState.profileRepository.getProfiles(accountId: accountId)
                    var names: [String] = []
                    for member in members {
                        if let profile = profiles.first(where: {
                            ($0.linkedUserId ?? $0.sourceUserId) == member.memberUserId
                        }) {
                            names.append(profile.displayName)
                        }
                    }
                    ownLists[index].sharedWithDisplayNames = names
                }
            }

            // Fetch lists shared WITH the current user from other accounts
            if let userId = await SupabaseManager.shared.currentUserId {
                let sharedListIds = try await repository?.getSharedListIds(userId: userId) ?? []
                // Filter out any IDs that are already in own lists (shouldn't happen, but safety)
                let ownListIds = Set(ownLists.map { $0.id })
                let newSharedIds = sharedListIds.filter { !ownListIds.contains($0) }

                if !newSharedIds.isEmpty {
                    var sharedLists = try await repository?.getListsByIds(newSharedIds) ?? []

                    // Annotate shared lists with sharer info
                    let visibleShares = try await appState.familyCalendarRepository.getSharesVisibleToUser()
                    let todoSharesVisible = visibleShares.filter { $0.eventType == .todoList }

                    // Load profiles in current account to resolve sharer names
                    let currentProfiles = try await appState.profileRepository.getProfiles(accountId: accountId)

                    for i in sharedLists.indices {
                        if let share = todoSharesVisible.first(where: { $0.eventId == sharedLists[i].id }) {
                            sharedLists[i].sharedByUserId = share.sharedByUserId
                            // Find the synced/connected profile in our account that represents the sharer
                            if let sharerProfile = currentProfiles.first(where: {
                                ($0.linkedUserId ?? $0.sourceUserId) == share.sharedByUserId
                            }) {
                                sharedLists[i].sharedByDisplayName = sharerProfile.displayName
                            }
                        }
                    }

                    ownLists.append(contentsOf: sharedLists)
                }
            }

            lists = ownLists
        } catch {
            self.error = error
        }
    }

    func createList(title: String, type: String?, dueDate: Date? = nil) {
        guard let accountId = accountId, let repository = repository else { return }

        Task {
            do {
                let newList = try await repository.createList(
                    accountId: accountId,
                    title: title,
                    listType: type,
                    dueDate: dueDate
                )
                lists.append(newList)
            } catch {
                self.error = error
            }
        }
    }

    func createListAsync(title: String, type: String?, dueDate: Date? = nil) async -> ToDoList? {
        guard let accountId = accountId, let repository = repository else { return nil }

        do {
            let newList = try await repository.createList(
                accountId: accountId,
                title: title,
                listType: type,
                dueDate: dueDate
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
