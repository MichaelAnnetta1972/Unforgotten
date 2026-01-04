import SwiftUI
import UIKit

// MARK: - Page Identifier
enum PageIdentifier: String, Codable, CaseIterable, Identifiable {
    case home
    case birthdays
    case medications
    case appointments
    case contacts
    case profiles
    case notes
    case mood
    case todoLists
    case settings
    case stickyReminders
    // Detail pages
    case profileDetail
    case appointmentDetail
    case contactDetail
    case medicationDetail
    case todoDetail

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .home: return "Home"
        case .birthdays: return "Birthdays"
        case .medications: return "Medications"
        case .appointments: return "Appointments"
        case .contacts: return "Contacts"
        case .profiles: return "Family & Friends"
        case .notes: return "Notes"
        case .mood: return "Mood Tracker"
        case .todoLists: return "To Do Lists"
        case .settings: return "Settings"
        case .stickyReminders: return "Sticky Reminders"
        case .profileDetail: return "Profile Detail"
        case .appointmentDetail: return "Appointment Detail"
        case .contactDetail: return "Contact Detail"
        case .medicationDetail: return "Medication Detail"
        case .todoDetail: return "To Do List"
        }
    }

    var defaultHeaderImage: String {
        switch self {
        case .home: return "header-home"
        case .birthdays: return "header-birthdays"
        case .medications: return "header-medications"
        case .appointments: return "header-appointments"
        case .contacts: return "header-contacts"
        case .profiles: return "header-profiles"
        case .notes: return "header-notes"
        case .mood: return "header-mood"
        case .todoLists: return "header-todo"
        case .settings: return "header-settings"
        case .stickyReminders: return "header-reminders"
        case .profileDetail: return "header-profile-detail"
        case .appointmentDetail: return "header-appointment-detail"
        case .contactDetail: return "header-contacts-detail"
        case .medicationDetail: return "header-medication-detail"
        case .todoDetail: return "header-todo"
        }
    }
}

// MARK: - User Header Overrides Manager
@Observable
class UserHeaderOverrides {
    private let fileManager = FileManager.default
    private let userDefaultsKey = "custom_header_paths"

    // Cache for loaded images
    private var imageCache: [PageIdentifier: UIImage] = [:]

    // Track which pages have custom headers
    private(set) var customHeaderPaths: [String: String] = [:]

    init() {
        loadSavedPaths()
    }

    // MARK: - Public Methods

    /// Check if a page has a custom header image
    func hasCustomImage(for page: PageIdentifier) -> Bool {
        customHeaderPaths[page.rawValue] != nil
    }

    /// Get the custom image for a page (returns nil if no custom image)
    func image(for page: PageIdentifier) -> UIImage? {
        // Check cache first
        if let cached = imageCache[page] {
            return cached
        }

        // Load from file system
        guard let path = customHeaderPaths[page.rawValue] else {
            return nil
        }

        let fileURL = getDocumentsDirectory().appendingPathComponent(path)

        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            // File doesn't exist or can't be loaded, clean up reference
            clearImage(for: page)
            return nil
        }

        // Cache the loaded image
        imageCache[page] = image
        return image
    }

    /// Set a custom header image for a page
    func setImage(_ image: UIImage, for page: PageIdentifier) {
        // Resize image if needed (max 1200px width)
        let resizedImage = resizeImageIfNeeded(image, maxWidth: 1200)

        // Compress as JPEG
        guard let data = resizedImage.jpegData(compressionQuality: 0.8) else {
            return
        }

        // Generate filename
        let filename = "header_\(page.rawValue).jpg"
        let fileURL = getDocumentsDirectory().appendingPathComponent(filename)

        // Save to file system
        do {
            try data.write(to: fileURL)

            // Update paths dictionary
            customHeaderPaths[page.rawValue] = filename
            savePaths()

            // Update cache
            imageCache[page] = resizedImage

        } catch {
            print("Failed to save header image: \(error)")
        }
    }

    /// Clear the custom header image for a page
    func clearImage(for page: PageIdentifier) {
        // Remove from cache
        imageCache.removeValue(forKey: page)

        // Get the file path
        guard let filename = customHeaderPaths[page.rawValue] else {
            return
        }

        let fileURL = getDocumentsDirectory().appendingPathComponent(filename)

        // Delete file
        try? fileManager.removeItem(at: fileURL)

        // Update paths dictionary
        customHeaderPaths.removeValue(forKey: page.rawValue)
        savePaths()
    }

    /// Clear all custom header images
    func clearAllImages() {
        for page in PageIdentifier.allCases {
            clearImage(for: page)
        }
    }

    /// Get pages that have custom headers
    var pagesWithCustomHeaders: [PageIdentifier] {
        PageIdentifier.allCases.filter { hasCustomImage(for: $0) }
    }

    // MARK: - Private Methods

    private func getDocumentsDirectory() -> URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func loadSavedPaths() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let paths = try? JSONDecoder().decode([String: String].self, from: data) {
            customHeaderPaths = paths
        }
    }

    private func savePaths() {
        if let data = try? JSONEncoder().encode(customHeaderPaths) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    private func resizeImageIfNeeded(_ image: UIImage, maxWidth: CGFloat) -> UIImage {
        guard image.size.width > maxWidth else {
            return image
        }

        let scale = maxWidth / image.size.width
        let newHeight = image.size.height * scale
        let newSize = CGSize(width: maxWidth, height: newHeight)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - SwiftUI Image Extension
extension UserHeaderOverrides {
    /// Get a SwiftUI Image for a page's custom header
    func swiftUIImage(for page: PageIdentifier) -> Image? {
        guard let uiImage = image(for: page) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }
}
