import Foundation

// MARK: - Tutorial Category
enum TutorialCategory: String, CaseIterable {
    case gettingStarted  = "Getting Started"
    case calendar        = "Calendar"
    case medications     = "Medications"
    case appointments    = "Appointments"
    case events          = "Events"
    case family          = "Family Sharing"
    case tasks           = "To-Do Lists"
    case notes           = "Notes"
    case accounts        = "Important Accounts"
    case mealPlanner     = "Meal Planner"
    case contacts        = "Contacts"
    case reminders       = "Reminders"
    case members         = "Manage Members"
    case birthdays       = "Birthdays"
    case profiles        = "Family and Friends"

}

// MARK: - Tutorial
struct Tutorial: Identifiable {
    let id: String          // Unique identifier
    let videoURL: String    // Full URL to hosted MP4 (e.g. "https://unforgottenapp.com/tutorials/welcome.mp4")
    let title: String
    let description: String
    let duration: String    // e.g. "1:20"
    let category: TutorialCategory
    let iconName: String    // SF Symbol name
}

// MARK: - Tutorial Data
extension Tutorial {

    /// Base URL for all tutorial videos
    private static let baseURL = "https://unforgottenapp.com/tutorials"

    static let allTutorials: [Tutorial] = [

        // Getting Started
        Tutorial(id: "welcome", videoURL: "\(baseURL)/Unforgotten.mp4",
                 title: "Welcome to Unforgotten",
                 description: "What is Unforgotten?",
                 duration: "1:30", category: .gettingStarted, iconName: "star.fill"),

    Tutorial(id: "Home", videoURL: "\(baseURL)/Home.mp4",
                 title: "The Home Screen",
                 description: "A quick tour of the home screen.",
                 duration: "0:51", category: .gettingStarted, iconName: "star.fill"),

        Tutorial(id: "calendar", videoURL: "\(baseURL)/Calendar.mp4",
                 title: "Using the Calendar",
                 description: "How to create an account and personalise your experience.",
                 duration: "0:44", category: .calendar, iconName: "calendar"),

        // Medications
        Tutorial(id: "adding-medications", videoURL: "\(baseURL)/Medications.mp4",
                 title: "Adding Medications",
                 description: "How to add a medication, set dosage, and choose reminder times.",
                 duration: "0:38", category: .medications, iconName: "pill.fill"),

        // Appointments
        Tutorial(id: "adding-appointments", videoURL: "\(baseURL)/Appointments.mp4",
                 title: "Adding Appointments",
                 description: "Schedule a doctor's visit or any appointment with reminders.",
                 duration: "0:29", category: .appointments, iconName: "calendar.badge.clock"),

        // Family Sharing
        Tutorial(id: "inviting-members", videoURL: "\(baseURL)/Invitations.mp4",
                 title: "Inviting members",
                 description: "How to invite a family member and set their access level.",
                 duration: "1:05", category: .family, iconName: "person.2.fill"),

        // Tutorial(id: "family-roles", videoURL: "\(baseURL)/FamilyRoles.mp4",
        //          title: "Family Roles",
        //          description: "Understand the difference between Owner, Caregiver, and Viewer roles.",
        //          duration: "1:15", category: .family, iconName: "lock.shield.fill"),

        // To-Do Lists
        Tutorial(id: "todo-lists", videoURL: "\(baseURL)/Todo.mp4",
                 title: "Using To-Do Lists",
                 description: "Create tasks, set due dates, and mark items complete.",
                 duration: "0:48", category: .tasks, iconName: "checklist"),

        // // Important Accounts
        // Tutorial(id: "important-accounts", videoURL: "\(baseURL)/ImportantAccounts.mp4",
        //          title: "Important Accounts",
        //          description: "Save references to bank, utility, or health insurance accounts.",
        //          duration: "1:05", category: .accounts, iconName: "creditcard.fill"),

        // Events
        Tutorial(id: "creating-event", videoURL: "\(baseURL)/Events.mp4",
                 title: "Creating an Event",
                 description: "Create an event and share it in the Family Calendar.",
                 duration: "0:34", category: .events, iconName: "party.popper.fill"),

        // Meal Planner
        Tutorial(id: "meal-planner", videoURL: "\(baseURL)/Meals.mp4",
                 title: "Plan Your Meals",
                 description: "How to add meals to the planner.",
                 duration: "0:27", category: .mealPlanner, iconName: "calendar.badge.plus"),

                // Reminders
        Tutorial(id: "sticky-reminders", videoURL: "\(baseURL)/Reminders.mp4",
                 title: "Sticky Reminders",
                 description: "How to create a sticky reminder.",
                 duration: "0:24", category: .reminders, iconName: "pin.fill"),

        // Profiles
        Tutorial(id: "family-and-friends", videoURL: "\(baseURL)/Profiles.mp4",
                 title: "Family and Friends",
                 description: "Never forget a birthday again.",
                 duration: "0:51", category: .profiles, iconName: "person.badge.minus"),

      // Profiles
        Tutorial(id: "about-me", videoURL: "\(baseURL)/AboutMe.mp4",
                 title: "About Me",
                 description: "A place for all of your details.",
                 duration: "0:33", category: .profiles, iconName: "person.badge.minus"),


        // Birthdays
        Tutorial(id: "birthdays", videoURL: "\(baseURL)/Birthdays.mp4",
                 title: "Birthdays",
                 description: "Never forget a birthday again.",
                 duration: "0:26", category: .birthdays, iconName: "person.badge.minus"),
    ]
}
