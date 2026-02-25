import SwiftUI
import SwiftData

// MARK: - Local Important Account Model
/// SwiftData model for ImportantAccount, stored locally for offline support
@Model
final class LocalImportantAccount {
    // MARK: - Core Properties
    var id: UUID
    var profileId: UUID
    var accountName: String
    var websiteURL: String?
    var username: String?
    var emailAddress: String?
    var phoneNumber: String?
    var securityQuestionHint: String?
    var recoveryHint: String?
    var notes: String?
    var category: String?  // Store as raw value
    var imageUrl: String?
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Sync Properties
    var isSynced: Bool
    var locallyDeleted: Bool

    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        profileId: UUID,
        accountName: String,
        websiteURL: String? = nil,
        username: String? = nil,
        emailAddress: String? = nil,
        phoneNumber: String? = nil,
        securityQuestionHint: String? = nil,
        recoveryHint: String? = nil,
        notes: String? = nil,
        category: String? = nil,
        imageUrl: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isSynced: Bool = false,
        locallyDeleted: Bool = false
    ) {
        self.id = id
        self.profileId = profileId
        self.accountName = accountName
        self.websiteURL = websiteURL
        self.username = username
        self.emailAddress = emailAddress
        self.phoneNumber = phoneNumber
        self.securityQuestionHint = securityQuestionHint
        self.recoveryHint = recoveryHint
        self.notes = notes
        self.category = category
        self.imageUrl = imageUrl
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isSynced = isSynced
        self.locallyDeleted = locallyDeleted
    }

    // MARK: - Conversion from Remote
    convenience init(from remote: ImportantAccount) {
        self.init(
            id: remote.id,
            profileId: remote.profileId,
            accountName: remote.accountName,
            websiteURL: remote.websiteURL,
            username: remote.username,
            emailAddress: remote.emailAddress,
            phoneNumber: remote.phoneNumber,
            securityQuestionHint: remote.securityQuestionHint,
            recoveryHint: remote.recoveryHint,
            notes: remote.notes,
            category: remote.category?.rawValue,
            imageUrl: remote.imageUrl,
            createdAt: remote.createdAt,
            updatedAt: remote.updatedAt,
            isSynced: true,
            locallyDeleted: false
        )
    }

    // MARK: - Conversion to Remote
    func toRemote() -> ImportantAccount {
        ImportantAccount(
            id: id,
            profileId: profileId,
            accountName: accountName,
            websiteURL: websiteURL,
            username: username,
            emailAddress: emailAddress,
            phoneNumber: phoneNumber,
            securityQuestionHint: securityQuestionHint,
            recoveryHint: recoveryHint,
            notes: notes,
            category: category.flatMap { AccountCategory(rawValue: $0) },
            imageUrl: imageUrl,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    // MARK: - Update from Remote
    func update(from remote: ImportantAccount) {
        self.profileId = remote.profileId
        self.accountName = remote.accountName
        self.websiteURL = remote.websiteURL
        self.username = remote.username
        self.emailAddress = remote.emailAddress
        self.phoneNumber = remote.phoneNumber
        self.securityQuestionHint = remote.securityQuestionHint
        self.recoveryHint = remote.recoveryHint
        self.notes = remote.notes
        self.category = remote.category?.rawValue
        self.imageUrl = remote.imageUrl
        self.createdAt = remote.createdAt
        self.updatedAt = remote.updatedAt
        self.isSynced = true
    }

    // MARK: - Sync Helpers
    func markAsModified() {
        self.updatedAt = Date()
        self.isSynced = false
    }

    // MARK: - Computed Properties
    var accountCategory: AccountCategory? {
        get { category.flatMap { AccountCategory(rawValue: $0) } }
        set { category = newValue?.rawValue }
    }
}
