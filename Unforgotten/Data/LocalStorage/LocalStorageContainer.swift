import SwiftUI
import SwiftData

// MARK: - Local Storage Container Configuration
/// Configures the SwiftData container for all local storage models
struct LocalStorageContainer {

    /// The schema containing all local storage models
    private static var schema: Schema {
        Schema([
            // Account & Auth
            LocalAccount.self,
            LocalAccountMember.self,

            // Profiles
            LocalProfile.self,
            LocalProfileDetail.self,
            LocalProfileConnection.self,

            // Medications
            LocalMedication.self,
            LocalMedicationSchedule.self,
            LocalMedicationLog.self,

            // Other entities
            LocalAppointment.self,
            LocalUsefulContact.self,
            LocalToDoList.self,
            LocalToDoItem.self,
            LocalCountdown.self,
            LocalStickyReminder.self,
            LocalMoodEntry.self,
            LocalImportantAccount.self,

            // Sync infrastructure
            PendingChange.self,
            SyncMetadata.self
        ])
    }

    /// The URL for the local storage store file
    private static var storeURL: URL {
        URL.applicationSupportDirectory.appending(path: "UnforgottenLocalStorage.store")
    }

    /// Creates the model container for all local storage
    /// - Returns: Configured ModelContainer for all local models
    static func create() throws -> ModelContainer {
        let modelConfiguration = ModelConfiguration(
            "UnforgottenLocalStorage",
            schema: schema,
            url: storeURL,
            allowsSave: true
        )

        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            // If the store is corrupted or incompatible, delete it and try again
            #if DEBUG
            print("⚠️ Failed to create model container: \(error)")
            print("⚠️ Attempting to delete and recreate the store...")
            #endif

            // Delete the corrupted store files
            deleteStoreFiles()

            // Try creating the container again
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        }
    }

    /// Deletes all store files associated with the local storage
    private static func deleteStoreFiles() {
        let fileManager = FileManager.default
        let storeBasePath = storeURL.path

        // SwiftData creates multiple files with different extensions
        let extensions = ["", "-shm", "-wal"]
        for ext in extensions {
            let filePath = storeBasePath + ext
            if fileManager.fileExists(atPath: filePath) {
                try? fileManager.removeItem(atPath: filePath)
                #if DEBUG
                print("🗑️ Deleted store file: \(filePath)")
                #endif
            }
        }
    }

    /// Creates an in-memory container for previews and testing
    static func createPreviewContainer() throws -> ModelContainer {
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        return try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )
    }
}

// MARK: - Environment Key for Local Storage Container
private struct LocalStorageContainerKey: EnvironmentKey {
    static var defaultValue: ModelContainer?
}

extension EnvironmentValues {
    var localStorageContainer: ModelContainer? {
        get { self[LocalStorageContainerKey.self] }
        set { self[LocalStorageContainerKey.self] = newValue }
    }
}
