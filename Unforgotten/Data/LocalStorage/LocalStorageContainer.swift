import SwiftUI
import SwiftData
import UIKit

// MARK: - Local Storage Container Configuration
/// Configures the SwiftData container for all local storage models
struct LocalStorageContainer {

    /// Error thrown when the device has not been unlocked since boot and
    /// the protected store file cannot be opened.
    struct ProtectedDataUnavailableError: Error {}

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
            LocalRecipe.self,
            LocalPlannedMeal.self,

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
        // Ensure the parent directory exists and is marked with a protection
        // class that becomes available after first unlock (and stays available
        // until shutdown), so subsequent background launches can open the store.
        try? prepareStoreDirectory()

        let modelConfiguration = ModelConfiguration(
            "UnforgottenLocalStorage",
            schema: schema,
            url: storeURL,
            allowsSave: true
        )

        let container: ModelContainer
        do {
            container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            // If this failure is because the device has not been unlocked since
            // boot (headless background launch pre-first-unlock), surface a
            // typed error so the caller can exit cleanly instead of crashing.
            if isProtectedDataError(error) {
                throw ProtectedDataUnavailableError()
            }

            // Otherwise the store is likely corrupted or incompatible — delete
            // and try again.
            #if DEBUG
            print("⚠️ Failed to create model container: \(error)")
            print("⚠️ Attempting to delete and recreate the store...")
            #endif

            deleteStoreFiles()

            container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        }

        // Relax protection on the store files so they can be opened during
        // background launches that occur after first unlock but while the
        // device is locked.
        applyStoreFileProtection()

        return container
    }

    /// Best-effort check: does this error look like "file is protected and the
    /// device hasn't been unlocked since boot"? SwiftData wraps the underlying
    /// POSIX error, so we match on the NSError domain/code and the localized
    /// description.
    private static func isProtectedDataError(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain == NSPOSIXErrorDomain && ns.code == Int(EPERM) { return true }
        let description = ns.localizedDescription.lowercased()
        return description.contains("operation not permitted")
            || description.contains("protected")
    }

    /// Ensures the store's parent directory exists with a protection class
    /// that permits access after first unlock.
    private static func prepareStoreDirectory() throws {
        let fileManager = FileManager.default
        let directory = storeURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )
        } else {
            try? fileManager.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: directory.path
            )
        }
    }

    /// Applies `completeUntilFirstUserAuthentication` protection to the store
    /// files so they remain accessible across background launches.
    private static func applyStoreFileProtection() {
        let fileManager = FileManager.default
        let storeBasePath = storeURL.path
        let extensions = ["", "-shm", "-wal"]
        for ext in extensions {
            let filePath = storeBasePath + ext
            guard fileManager.fileExists(atPath: filePath) else { continue }
            try? fileManager.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: filePath
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
