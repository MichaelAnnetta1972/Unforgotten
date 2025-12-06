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
