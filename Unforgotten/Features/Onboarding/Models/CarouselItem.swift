import SwiftUI

// MARK: - Carousel Item Model
/// Represents a single feature card in the onboarding carousel
struct CarouselItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let cardImageName: String
    let expandedMedia: ExpandedMedia

    /// Media type for the expanded full-screen view
    enum ExpandedMedia: Equatable {
        case image(String)
        case video(String) // Video filename without extension

        var isVideo: Bool {
            if case .video = self { return true }
            return false
        }
    }

    /// Convenience initializer for image-only cards (same image for card and expanded)
    init(id: String, title: String, subtitle: String, imageName: String) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.cardImageName = imageName
        self.expandedMedia = .image(imageName)
    }

    /// Full initializer with separate expanded media
    init(id: String, title: String, subtitle: String, cardImageName: String, expandedMedia: ExpandedMedia) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.cardImageName = cardImageName
        self.expandedMedia = expandedMedia
    }
}

// MARK: - Carousel Configuration
/// Central configuration for onboarding carousel items
/// Add new items here to have them automatically appear in the carousel
struct CarouselConfiguration {

    /// All carousel items - add new features here
    /// The carousel will automatically pick up any new items added to this array
    static let items: [CarouselItem] = [
        CarouselItem(
            id: "themes",
            title: "Personalised Themes",
            subtitle: "Choose from preset themes or create your own personalised theme",
            cardImageName: "carousel-feature-themes",
            expandedMedia: .image("carousel-feature-themes-expanded")
        ),
        CarouselItem(
            id: "profiles",
            title: "Family Profiles",
            subtitle: "Keep important details about your loved ones all in one place",
            cardImageName: "carousel-feature-profiles",
            expandedMedia: .image("carousel-feature-profiles-expanded")
        ),
        CarouselItem(
            id: "calendar",
            title: "Smart Calendar",
            subtitle: "Track birthdays, appointments and important dates effortlessly",
            cardImageName: "carousel-feature-calendar",
            expandedMedia: .image("carousel-feature-calendar-expanded")
        ),
        CarouselItem(
            id: "medications",
            title: "Medication Tracking",
            subtitle: "Never miss a dose with smart reminders and easy logging",
            cardImageName: "carousel-feature-medications",
            expandedMedia: .image("carousel-feature-medications-expanded")
        ),

        CarouselItem(
            id: "birthdays",
            title: "Birthday Tracker",
            subtitle: "All of your upcoming birthdays in the one place, with notifications so you never forget someone's birthday again.",
            cardImageName: "carousel-feature-birthdays",
            expandedMedia: .image("carousel-feature-birthdays-expanded")
        ),
        CarouselItem(
            id: "notes",
            title: "Notes and To Do Lists",
            subtitle: "Keep track of things to do, or make a note and send it someone else",
            cardImageName: "carousel-feature-notes",
            expandedMedia: .image("carousel-feature-notes-expanded")
        ),
        CarouselItem(
            id: "reminders",
            title: "Sticky Reminders",
            subtitle: "Create reminders that repeat until you log in and switch them off!",
            cardImageName: "carousel-feature-reminders",
            expandedMedia: .image("carousel-feature-reminders-expanded")
        ),
        CarouselItem(
            id: "contacts",
            title: "Useful Contacts",
            subtitle: "Make a list of all your important contacts, like doctors or tradesmen.",
            cardImageName: "carousel-feature-contacts",
            expandedMedia: .image("carousel-feature-contacts-expanded")
        )


    ]

    /// Number of items (used for infinite scroll calculations)
    static var itemCount: Int { items.count }
}
