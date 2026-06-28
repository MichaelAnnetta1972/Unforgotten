import SwiftUI

// MARK: - Carousel Item Model
/// Represents a single feature card in the onboarding carousel
struct CarouselItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let cardImageName: String
    let expandedMedia: ExpandedMedia
    let tutorialId: String?

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
    init(id: String, title: String, subtitle: String, imageName: String, tutorialId: String? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.cardImageName = imageName
        self.expandedMedia = .image(imageName)
        self.tutorialId = tutorialId
    }

    /// Full initializer with separate expanded media
    init(id: String, title: String, subtitle: String, cardImageName: String, expandedMedia: ExpandedMedia, tutorialId: String? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.cardImageName = cardImageName
        self.expandedMedia = expandedMedia
        self.tutorialId = tutorialId
    }
}

// MARK: - Carousel Configuration
/// Central configuration for onboarding carousel items
/// Cards mirror the tutorials available in Settings. Tapping a card plays the matching tutorial video.
struct CarouselConfiguration {

    /// All carousel items - one per tutorial in `Tutorial.allTutorials`
    static let items: [CarouselItem] = [
        CarouselItem(
            id: "welcome",
            title: "Welcome to Unforgotten",
            subtitle: "What is Unforgotten?",
            imageName: "carousel-feature-unforgotten",
            tutorialId: "welcome"
        ),
        CarouselItem(
            id: "home",
            title: "The Home Screen",
            subtitle: "A quick tour of the home screen.",
            imageName: "carousel-feature-home",
            tutorialId: "Home"
        ),
        CarouselItem(
            id: "calendar",
            title: "Using the Calendar",
            subtitle: "The Calendar shows you all of your upcoming dates.",
            imageName: "carousel-feature-calendar",
            tutorialId: "calendar"
        ),
        CarouselItem(
            id: "adding-medications",
            title: "Adding Medications",
            subtitle: "Add medications, set dosage, and choose reminder times.",
            imageName: "carousel-feature-medications",
            tutorialId: "adding-medications"
        ),
        CarouselItem(
            id: "adding-appointments",
            title: "Adding Appointments",
            subtitle: "Schedule an appointment, create a reminders, and even share it.",
            imageName: "carousel-feature-appointments",
            tutorialId: "adding-appointments"
        ),
        CarouselItem(
            id: "todo-lists",
            title: "Using To-Do Lists",
            subtitle: "Create tasks, set due dates, and mark items complete.",
            imageName: "carousel-feature-todo",
            tutorialId: "todo-lists"
        ),
        CarouselItem(
            id: "creating-event",
            title: "Creating an Event",
            subtitle: "Create an event and share it in the Family Calendar.",
            imageName: "carousel-feature-events",
            tutorialId: "creating-event"
        ),
        CarouselItem(
            id: "meal-planner",
            title: "Plan Your Meals",
            subtitle: "Create a Meal Planner",
            imageName: "carousel-feature-meals",
            tutorialId: "meal-planner"
        ),
        CarouselItem(
            id: "sticky-reminders",
            title: "Sticky Reminders",
            subtitle: "Create reminders that stick!",
            imageName: "carousel-feature-reminders",
            tutorialId: "sticky-reminders"
        ),
        CarouselItem(
            id: "family-and-friends",
            title: "Family and Friends",
            subtitle: "Create profiles for your Family and Friends",
            imageName: "carousel-feature-profiles",
            tutorialId: "family-and-friends"
        ),
        CarouselItem(
            id: "birthdays",
            title: "Birthdays",
            subtitle: "Never forget a birthday again.",
            imageName: "carousel-feature-birthdays",
            tutorialId: "birthdays"
        )
    ]

    /// Number of items (used for infinite scroll calculations)
    static var itemCount: Int { items.count }
}
