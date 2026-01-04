# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Unforgotten is an iOS app built with SwiftUI to help users manage information about loved ones with memory conditions. The app tracks profiles, medications, appointments, birthdays, and useful contacts using a Supabase backend.

## Building and Testing

### Build the App
```bash
xcodebuild -project Unforgotten.xcodeproj -scheme Unforgotten -sdk iphoneos
```

### Run Tests
```bash
# Run unit tests
xcodebuild test -project Unforgotten.xcodeproj -scheme Unforgotten -destination 'platform=iOS Simulator,name=iPhone 15'

# Run UI tests
xcodebuild test -project Unforgotten.xcodeproj -scheme UnforgottenUITests -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Open in Xcode
```bash
open Unforgotten.xcodeproj
```

## Architecture

### App Structure

The codebase follows a feature-based modular architecture:

- **App/**: Application entry point and root view management
  - `UnforgottenApp.swift`: Main app entry with `AppState` observable object
  - `AppState`: Central state manager holding repositories, authentication state, current account, user role, and onboarding status
  - `RootView.swift`: Navigation logic for loading/auth/onboarding/main flows

- **Features/**: Feature modules organized by domain
  - Each feature has a `Views/` directory for SwiftUI views
  - Features: Auth, Home, Profiles, Medications, Appointments, Birthdays, Mood, Settings, Onboarding

- **Data/**: Data layer with models and repositories
  - `Models/Models.swift`: All domain models (Account, Profile, Medication, Appointment, etc.)
  - `Repositories/`: Repository pattern implementations for each domain
  - `Supabase/SupabaseClient.swift`: Supabase configuration and manager singleton

- **Core/**: Shared utilities and components
  - `Theme/Theme.swift`: App-wide colors, typography, dimensions, and gradients
  - `Components/Components.swift`: Reusable SwiftUI components
  - `Extensions/Extensions.swift`: Extensions for View, Date, String, etc.

### State Management

The app uses `AppState` as the central observable object that:
- Manages authentication state (`isAuthenticated`, `currentUser`)
- Holds the current account and user role
- Provides repository instances to all features
- Manages onboarding completion state
- Controls mood prompt display
- Handles account data loading and sign-out

All feature views receive `AppState` via `@EnvironmentObject` and access repositories through it.

### Repository Pattern

Each domain has a repository that:
- Defines a protocol for testability (`AccountRepositoryProtocol`, etc.)
- Implements CRUD operations using Supabase client
- Handles database table interactions via `TableName` constants
- Returns domain models (not DTOs)
- Uses private `Insert` and `Update` structs for mutations

Repository instances are created in `AppState` and injected into views via environment objects.

### Supabase Integration

- **SupabaseManager**: Singleton providing `SupabaseClient` instance
- **SupabaseConfig**: Contains project URL, anon key, and storage bucket names
- **TableName**: Centralized database table name constants
- **SupabaseError**: Custom error types with localized descriptions

All repository operations use async/await with Supabase Swift SDK v2.37.0+.

### Authentication Flow

1. App launches → `AppState.checkAuthState()` runs
2. If authenticated → Load account data → Check mood prompt → Show main app
3. If no account exists → Show onboarding
4. If not authenticated → Show auth view
5. Auth methods: Email/password, magic link, Apple Sign-In

### UI Components

Reusable components in `Core/Components/Components.swift`:
- **Cards**: NavigationCard, ProfileListCard, DetailItemCard, ValuePillCard, GiftItemCard, MedicalConditionCard, CategoryCard
- **Buttons**: PrimaryButton, SecondaryButton, FloatingAddButton
- **Inputs**: AppTextField
- **Headers**: HeaderImageView, SectionHeaderCard
- **States**: EmptyStateView, LoadingView

### Theme System

All styling defined in `Core/Theme/Theme.swift`:
- **Colors**: Dark theme with accent yellow (#FFC93A), organized by purpose (background, text, status, feature-specific)
- **Typography**: Semantic font styles (appLargeTitle, appTitle, appCardTitle, etc.)
- **Dimensions**: Standardized spacing, corner radius, and component sizes
- **Gradients**: Predefined gradients for headers and features

Always use theme constants instead of hardcoded values.

### Date and Time Handling

The app uses UTC timestamps from Supabase and relies on:
- `Date` extensions for formatting, age calculation, and birthday logic
- Account-level timezone stored in `Account.timezone`
- `Date.startOfDay` and `Date.endOfDay` for date-range queries

## Common Patterns

### Creating a New Feature View

1. Create view file in `Features/[Feature]/Views/`
2. Inject `AppState` via `@EnvironmentObject`
3. Use `@StateObject` for view-specific ViewModels
4. Access repositories through `appState.[repository]`
5. Use theme constants from `Core/Theme/Theme.swift`
6. Apply `.task {}` modifier for async data loading

### Adding a New Repository

1. Create protocol defining operations
2. Implement repository with `SupabaseManager.shared.client`
3. Add private Insert/Update structs with proper `CodingKeys`
4. Instantiate in `AppState` initialization
5. Add table name constant to `TableName` enum

### Working with Models

All models are in `Data/Models/Models.swift`:
- Use `Codable` for Supabase serialization
- Define `CodingKeys` for snake_case mapping
- Add computed properties for display logic (e.g., `displayName`, `age`)
- Keep models immutable where possible (`let` for properties that shouldn't change)

### Error Handling

- Use `SupabaseError` enum for custom errors
- Catch and log errors in repositories
- Display error messages to users using `error.localizedDescription`
- ViewModels should have `@Published var error: String?` for error state

## Database Schema Notes

The Supabase backend has these key tables:
- `accounts`: Account records (one per family/group)
- `account_members`: Join table for account access with roles (owner, admin, helper, viewer)
- `profiles`: People records with types (primary, relative, friend, doctor, carer)
- `profile_details`: Flexible key-value details (clothing, gifts, medical, allergies, likes/dislikes)
- `medications`: Medication records
- `medication_schedules`: When medications should be taken
- `medication_logs`: Daily logs for tracking medication intake
- `appointments`: Appointment records
- `useful_contacts`: Contact directory (doctors, services, etc.)
- `mood_entries`: Daily mood tracking entries

Row-level security (RLS) is enabled. All queries use authenticated user ID from Supabase session.

## Dependencies

Managed via Swift Package Manager:
- **Supabase Swift SDK** (v2.37.0+): Backend integration including Auth, Database, Storage
- Includes transitive dependencies: swift-crypto, swift-http-types, swift-concurrency-extras

Dependencies are resolved in `Package.resolved` and referenced in project file.

## Configuration

**Supabase credentials** are in `Data/Supabase/SupabaseClient.swift`:
- Project URL and anon key are currently hardcoded
- Storage buckets for profile photos and medication photos
- Image upload limits (5MB max, 800px max dimension)

## iOS Requirements

- **Deployment Target**: iOS 18.5+
- **Swift Version**: 5.0
- **Xcode**: 16.4+
- **Supported Devices**: iPhone and iPad (iPhone-first design)

## Key Behaviors

### Onboarding
On first launch, users must:
1. Sign up or sign in
2. Create account with display name
3. Create primary profile with optional birthday
4. Only then access the main app

### Mood Tracking
- Daily mood prompt shown automatically if not yet answered today
- Checked on app launch via `AppState.checkMoodPrompt()`
- Stored per user per account

### Medication Logs
- Generated daily from medication schedules
- `AppState.generateTodaysMedicationLogs()` creates logs for current date
- Logs track scheduled, taken, missed, or skipped status

### Home View
Displays "Today" card showing:
- Medications due today with quick "Take" button
- Appointments scheduled today
- Birthdays occurring today

Navigates to all feature sections (My Card, Family and Friends, Medicines, Appointments, Birthdays, Useful Contacts).


# Unforgotten - iPad Development Guidelines

## Platform Strategy

Unforgotten uses an **adaptive approach** rather than separate iPhone/iPad implementations. All views should respond intelligently to available screen space using SwiftUI's environment values and native layout systems.

## Size Class Detection

Use environment values for layout decisions, never device type checks:

```swift
@Environment(\.horizontalSizeClass) private var horizontalSizeClass
@Environment(\.verticalSizeClass) private var verticalSizeClass
```

- **Regular width**: iPad full screen, iPad split view (large side), large iPhones in landscape
- **Compact width**: iPhone portrait, iPad slide-over, iPad split view (small side)

## Navigation Patterns

**Primary navigation structure:**
- Use `NavigationSplitView` for features with list/detail relationships (Medications, Contacts, To Do Lists, Birthdays, Appointments)
- Provide two-column layout on regular width, collapsing to stack navigation on compact
- Sidebar should remain functional when shown in narrow split view contexts

**Example pattern:**
```swift
NavigationSplitView {
    ListContentView()
} detail: {
    DetailContentView()
}
.navigationSplitViewStyle(.balanced)
```

## Layout Considerations

**Adaptive grids:**
- Use `LazyVGrid` with adaptive columns rather than fixed counts
- Minimum item width: 300pt for content cards, 160pt for compact items
- Let the system determine column count based on available width

**Content width:**
- On very wide displays, constrain content to a readable maximum width (approximately 700pt for text-heavy views)
- Center constrained content horizontally
- Allow full width for grids and collection-style layouts

**Spacing and margins:**
- Use slightly larger margins on iPad (20-24pt) compared to iPhone (16pt)
- Increase spacing between interactive elements to prevent accidental taps

## Touch Targets and Accessibility

Given our target demographic of older adults:
- Minimum touch target: 44x44pt on iPhone, 48x48pt on iPad
- Interactive elements should have generous padding
- Maintain all existing accessibility labels and hints
- Test with larger text sizes — iPad has more room to accommodate Dynamic Type gracefully

## Pointer and Keyboard Support

iPad users may use trackpad, mouse, or keyboard:
- Add `.hoverEffect()` to interactive elements where appropriate
- Implement keyboard shortcuts for common actions using `.keyboardShortcut()`
- Support standard shortcuts: ⌘N (new item), ⌘F (search), Delete key (remove selected)

## Theming System

The existing theming system (accent colors, header customization) should apply consistently across iPhone and iPad. No iPad-specific theme variations unless explicitly requested.

## Multitasking Support

Unforgotten should work correctly in all iPad multitasking modes:
- Full screen
- Split View (both sides)
- Slide Over

Test layouts at all possible widths. Views must remain functional even at the narrowest Slide Over width (approximately 320pt).

## Feature-Specific Guidance

**To Do Lists:**
- Two-column layout: list sidebar on left, selected list's items on right
- Drag-to-reorder should work via both touch and pointer
- Search and filter controls visible in sidebar header

**Medications:**
- Split view with medication list and selected medication's full details/schedule
- Consider showing weekly schedule visualization in detail view on iPad

**Contacts:**
- Alphabetical list in sidebar, full contact card in detail pane
- Show more contact fields simultaneously on iPad detail view

**Appointments/Birthdays:**
- Calendar or timeline view possible on iPad given additional space
- List view in sidebar, selected event details on right

## Local-First Behavior

iPad implementation maintains the same local-first approach with background Supabase sync. No changes to data architecture for iPad — SwiftData and sync logic remain unified.

## Debugging Approach

When troubleshooting iPad layouts:
- Use colored borders (`.border(Color.red)`) to visualize frame boundaries
- Test in all size class combinations using Xcode's preview device variants
- Verify behavior when rotating device and when entering/exiting split view
- Check that animations perform smoothly on older supported iPad models

## File Organization

iPad-adaptive code should remain in existing view files. Avoid creating separate `*_iPad.swift` variants. Use internal `ViewBuilder` methods or extracted subviews when conditional layouts become complex:

```swift
@ViewBuilder
private var contentLayout: some View {
    if horizontalSizeClass == .regular {
        regularWidthLayout
    } else {
        compactWidthLayout
    }
}
```

## Minimum Deployment

iPad support follows the same iOS 17+ minimum as iPhone. Use modern SwiftUI APIs freely.
