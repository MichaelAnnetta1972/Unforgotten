# Unforgotten Onboarding Redesign - Implementation Plan

## Overview

This plan outlines the complete replacement of the existing 3-step onboarding flow with a new 8-screen onboarding experience. The new flow emphasizes warmth, accessibility, personalization through dynamic theming, and optional premium subscription.

## Current State Analysis

### Existing Onboarding
- **Location**: `Features/Onboarding/Views/OnboardingView.swift`
- **Screens**: 3 steps (Welcome → Account Setup → Profile Setup)
- **Data collected**: Account name, primary profile name, optional birthday
- **Theme integration**: Uses `@Environment(\.appAccentColor)` for accent colors

### Existing Theme System
- **4 Header Styles**: StyleOne (Yellow), StyleTwo (Orange), StyleThree (Pink), StyleFour (Green)
- **Managers**: `HeaderStyleManager`, `UserPreferences`, `UserHeaderOverrides`
- **Persistence**: UserDefaults with keys like `selected_header_style_id`, `user_accent_color_index`
- **Environment injection**: Via `@Environment(\.appAccentColor)` and `@Environment` for managers

### Key Integration Points
- **RootView.swift**: Shows `OnboardingView()` when `!appState.hasCompletedOnboarding`
- **AppState**: `completeOnboarding()` creates account and primary profile
- **NotificationService**: Already exists, needs permission request integration

---

## New File Structure

```
Unforgotten/Features/Onboarding/
├── OnboardingContainerView.swift          // Main container, manages flow state
├── Models/
│   └── OnboardingData.swift               // Collected data model
├── Managers/
│   └── OnboardingThemeManager.swift       // Theme state during onboarding
├── Screens/
│   ├── WelcomeView.swift                  // Screen 1
│   ├── ProfileSetupView.swift             // Screen 2
│   ├── ThemeSelectionView.swift           // Screen 3
│   ├── FriendCodeView.swift               // Screen 4
│   ├── FreeTierView.swift                 // Screen 5
│   ├── PremiumView.swift                  // Screen 6 (optional)
│   ├── NotificationsView.swift            // Screen 7
│   └── CompletionView.swift               // Screen 8
├── Components/
│   ├── OnboardingProgressDots.swift       // Progress indicator
│   ├── ThemePreviewCard.swift             // Live preview for theme selection
│   ├── ThemeOptionCard.swift              // Theme selection card
│   ├── OnboardingFeatureRow.swift         // Feature display row
│   └── OnboardingActionCard.swift         // First action cards
└── Services/
    └── OnboardingService.swift            // Supabase & StoreKit interactions
```

---

## Implementation Steps

### Phase 1: Foundation (Models & Managers)

#### Step 1.1: Create OnboardingData Model
**File**: `Features/Onboarding/Models/OnboardingData.swift`

```swift
// Data collected throughout onboarding
@Observable class OnboardingData {
    // Profile Setup (Screen 2)
    var firstName: String = ""
    var lastName: String = ""
    var profilePhoto: UIImage? = nil
    var photoURL: String? = nil

    // Theme Selection (Screen 3)
    var selectedHeaderStyle: HeaderStyle = .defaultStyle

    // Friend Code (Screen 4)
    var friendCode: String? = nil
    var connectedInviterName: String? = nil
    var hasAdminPermission: Bool = false

    // Subscription (Screen 6)
    var isPremium: Bool = false
    var subscriptionProductId: String? = nil

    // Notifications (Screen 7)
    var notificationsEnabled: Bool = false

    // Computed
    var fullName: String { "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces) }
    var isProfileValid: Bool { !firstName.isBlank && !lastName.isBlank }
}
```

#### Step 1.2: Create OnboardingThemeManager
**File**: `Features/Onboarding/Managers/OnboardingThemeManager.swift`

```swift
// Manages theme state during onboarding, syncs to main theme on completion
@Observable class OnboardingThemeManager {
    var selectedStyle: HeaderStyle = .defaultStyle

    var accentColor: Color { selectedStyle.defaultAccentColor }
    var previewImageName: String { selectedStyle.previewImageName }

    func selectStyle(_ style: HeaderStyle) {
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedStyle = style
        }
    }

    func applyToMainTheme(headerStyleManager: HeaderStyleManager, userPreferences: UserPreferences) {
        headerStyleManager.selectStyle(selectedStyle)
        userPreferences.resetToStyleDefault()
    }
}
```

---

### Phase 2: Core Container

#### Step 2.1: Create OnboardingContainerView
**File**: `Features/Onboarding/OnboardingContainerView.swift`

- Manages flow state with `currentScreen` enum
- Injects `OnboardingData` and `OnboardingThemeManager` into environment
- Handles navigation (back button, swipe gestures)
- Shows progress dots (6 main steps)
- Handles screen transitions with horizontal slide animation

**Screen enum**:
```swift
enum OnboardingScreen: Int, CaseIterable {
    case welcome = 0
    case profileSetup = 1
    case themeSelection = 2
    case friendCode = 3
    case freeTier = 4
    case premium = 5      // Branch, not in main count
    case notifications = 6
    case completion = 7
}
```

**Progress calculation**: Welcome & Completion excluded; Premium is a branch from FreeTier

---

### Phase 3: Individual Screens

#### Step 3.1: WelcomeView (Screen 1)
**File**: `Features/Onboarding/Screens/WelcomeView.swift`

- Hero image (placeholder for user-provided asset `onboarding_welcome_hero`)
- App logo (`unforgotten-logo-stacked` or `unforgotten-logo`)
- Headline: "Never forget what matters most"
- Subheadline: "Keep track of medications, birthdays, appointments..."
- "Get Started" button
- Uses default theme colors initially
- Gentle fade-in animation on load

#### Step 3.2: ProfileSetupView (Screen 2)
**File**: `Features/Onboarding/Screens/ProfileSetupView.swift`

- Circular photo picker (PHPickerViewController integration)
  - Default: silhouette icon + "Add Photo" label
  - "Skip" option below
- First name text field (required)
- Last name text field (required)
- Continue button (disabled until both fields filled)
- Keyboard handling (scroll when keyboard appears)

#### Step 3.3: ThemeSelectionView (Screen 3)
**File**: `Features/Onboarding/Screens/ThemeSelectionView.swift`

- Live preview card (ThemePreviewCard component)
  - Shows mini home screen with selected theme
  - Theme header image
  - Mock medication reminder, mock birthday
  - Accent-colored UI elements
- 2x2 grid of theme options (ThemeOptionCard)
  - Header image as card background
  - Theme name overlay
  - Selected state: accent border + checkmark
- All color transitions animated (0.3s ease-in-out)

**Dynamic behavior**:
- When theme selected, update:
  - Preview card header image
  - All accent-colored elements
  - Progress dots
  - Continue button

#### Step 3.4: FriendCodeView (Screen 4)
**File**: `Features/Onboarding/Screens/FriendCodeView.swift`

- Headline: "Were you invited by family or a friend?"
- Text field for code entry
- "Connect" button (enabled when code has content)
- "I don't have a code" skip button
- Validation against Supabase `invitations` table
- Success state shows inviter name
- Admin permission notice if applicable
- Error handling with inline message and retry

#### Step 3.5: FreeTierView (Screen 5)
**File**: `Features/Onboarding/Screens/FreeTierView.swift`

- Headline: "Start with our Free plan"
- Feature list using icon + card layout (not bullets):
  - 1 Friend profile
  - 1 Reminder
  - 1 Note
  - 1 Medication tracker
  - All themes included
- Friendly upgrade note
- Two CTAs:
  - Primary: "See Premium options" → Screen 6
  - Secondary: "Continue with Free" → Screen 7

#### Step 3.6: PremiumView (Screen 6)
**File**: `Features/Onboarding/Screens/PremiumView.swift`

- Headline: "Unlock everything with Premium"
- Premium features list (contrast with free)
- Pricing display (monthly/annual with savings)
- StoreKit 2 integration:
  - Product fetching
  - Purchase handling
  - Transaction states (loading, success, error, cancelled)
- "Restore Purchases" link
- "Maybe later" skip link
- Required subscription disclosures
- On success: brief confirmation, then continue

#### Step 3.7: NotificationsView (Screen 7)
**File**: `Features/Onboarding/Screens/NotificationsView.swift`

- Headline: "Stay on top of what matters"
- Subheadline explaining notification value
- Illustration placeholder (`onboarding_notifications`)
- Primary: "Enable Notifications" → triggers system prompt
- Secondary: "Not now" skip link
- Uses existing `NotificationService.shared.requestPermission()`

#### Step 3.8: CompletionView (Screen 8)
**File**: `Features/Onboarding/Screens/CompletionView.swift`

- Celebration visual (subtle confetti or illustration)
- Personalized headline: "You're all set, [First Name]!"
- Three action cards:
  - "Add a friend" → Profiles
  - "Create a reminder" → Medications
  - "Explore the app" → Home
- Tapping any card:
  1. Syncs all data to Supabase
  2. Applies theme to main app
  3. Marks onboarding complete
  4. Dismisses onboarding and navigates

---

### Phase 4: Components

#### Step 4.1: OnboardingProgressDots
**File**: `Features/Onboarding/Components/OnboardingProgressDots.swift`

- 6 dots total (Profile → Theme → Friend → FreeTier → Notifications → Complete)
- Current = filled with accent color
- Others = dimmed
- 0.2s fill animation
- Respects dynamic theme from OnboardingThemeManager

#### Step 4.2: ThemePreviewCard
**File**: `Features/Onboarding/Components/ThemePreviewCard.swift`

- Mini home screen mockup
- Shows:
  - Header image from selected theme
  - "Today" card with mock content
  - Sample medication pill
  - Sample birthday
- All UI elements use selected accent color
- Crossfade animation on theme change

#### Step 4.3: ThemeOptionCard
**File**: `Features/Onboarding/Components/ThemeOptionCard.swift`

- Displays theme header image as background
- Theme name overlaid (with blur/gradient for readability)
- Selection state:
  - Accent-colored border
  - Checkmark badge
- Press animation (0.97 scale)
- Haptic feedback on selection

#### Step 4.4: OnboardingFeatureRow
**File**: `Features/Onboarding/Components/OnboardingFeatureRow.swift`

- Icon (SF Symbol) + title + optional description
- Card style background
- Uses accent color for icon

#### Step 4.5: OnboardingActionCard
**File**: `Features/Onboarding/Components/OnboardingActionCard.swift`

- Icon + title + brief description
- Card style with accent color highlight
- Press animation
- Used on completion screen

---

### Phase 5: Services

#### Step 5.1: OnboardingService
**File**: `Features/Onboarding/Services/OnboardingService.swift`

**Responsibilities**:
1. **Friend code validation**
   - Check `invitations` table in Supabase
   - Return inviter name and permission level

2. **Profile photo upload**
   - Compress image
   - Upload to Supabase Storage (`profile-photos` bucket)
   - Return public URL

3. **Complete onboarding sync**
   - Create account (extend current `completeOnboarding`)
   - Create primary profile with photo URL
   - Apply friend invitation if present
   - Record subscription status (local preference initially)
   - Mark onboarding complete

4. **StoreKit 2 subscription handling**
   - Fetch products
   - Purchase flow
   - Restore purchases
   - Verify transactions

---

### Phase 6: Integration

#### Step 6.1: Update RootView
**File**: `App/RootView.swift`

Replace:
```swift
OnboardingView()
```
With:
```swift
OnboardingContainerView()
```

#### Step 6.2: Update AppState
**File**: `App/UnforgottenApp.swift`

Extend `completeOnboarding` method or create new method to:
- Accept additional data (photo URL, friend code connection)
- Handle new data points

#### Step 6.3: Clean Up Old Onboarding
- Delete or archive old `OnboardingView.swift` content
- Keep file for backwards compatibility but redirect to new container

---

## Accessibility Requirements

1. **Dynamic Type**: All text uses `.font(.app*)` semantic styles that scale
2. **Touch targets**: Minimum 44x44pt, prefer 48pt for primary actions
3. **VoiceOver**:
   - All images have accessibility labels
   - Interactive elements have proper hints
   - Progress dots announce current position
4. **Reduce Motion**:
   - Check `UIAccessibility.isReduceMotionEnabled`
   - Use fades instead of slides/confetti
   - Skip celebration animation
5. **High contrast**: Test all color combinations

---

## Animation Specifications

| Element | Duration | Curve | Notes |
|---------|----------|-------|-------|
| Screen transitions | 0.3s | easeInOut | Horizontal slide |
| Theme color changes | 0.3s | easeInOut | Crossfade |
| Button press | 0.1s | easeOut | Scale to 0.97 |
| Progress dots | 0.2s | easeInOut | Fill animation |
| Welcome fade-in | 0.5s | easeOut | Initial load |
| Completion confetti | 1.5s | - | Then fade out |

---

## Data Flow Summary

```
OnboardingContainerView
├── @State onboardingData: OnboardingData
├── @State themeManager: OnboardingThemeManager
├── @EnvironmentObject appState: AppState
├── @Environment headerStyleManager
├── @Environment userPreferences
│
├── Screens inject via @Bindable / @Environment
│
└── On completion:
    1. OnboardingService.completeOnboarding(data)
    2. themeManager.applyToMainTheme(...)
    3. appState.hasCompletedOnboarding = true
```

---

## Error Handling Strategy

| Scenario | Handling |
|----------|----------|
| Network error (non-critical) | Show inline message, allow skip/retry |
| Invalid friend code | Inline error, keep field active, show skip option |
| StoreKit error | Appropriate message per error type, allow skip |
| Photo picker error | Graceful fallback, continue without photo |
| Profile save failure | Block with retry option |

---

## Testing Checklist

- [ ] VoiceOver enabled navigation
- [ ] Largest Dynamic Type size
- [ ] Reduce Motion enabled
- [ ] Offline scenarios
- [ ] Theme switching performance
- [ ] StoreKit sandbox testing
- [ ] Friend code validation (valid/invalid)
- [ ] Oldest supported iOS version (18.5)
- [ ] Smallest screen (iPhone SE)
- [ ] iPad layouts

---

## Assets Required (Placeholders)

| Asset Name | Usage | Notes |
|------------|-------|-------|
| `onboarding_welcome_hero` | Welcome screen | Hero image |
| `onboarding_notifications` | Notifications screen | Illustration |
| `onboarding_complete` | Completion screen | Celebration visual |
| Theme headers | Already exist | `style_*_preview` |

---

## Estimated Scope

| Phase | Files | Complexity |
|-------|-------|------------|
| Phase 1: Foundation | 2 | Low |
| Phase 2: Container | 1 | Medium |
| Phase 3: Screens | 8 | High |
| Phase 4: Components | 5 | Medium |
| Phase 5: Services | 1 | Medium-High |
| Phase 6: Integration | 2 | Low |

**Total new files**: ~19
**Modified files**: 2-3

---

## Questions for Clarification

1. **Subscription product IDs**: What are the App Store Connect product IDs for monthly/annual subscriptions? (Need these to configure StoreKit 2)

2. **Account name**: The current flow asks for "account name" (e.g., "Mum's Account"). Should this still be collected as a separate step, or should we:
   - Derive it from the profile name (e.g., "[First Name]'s Account")
   - Skip it entirely and let the user set it later in Settings
   - Add it as an optional field on the profile setup screen

3. **Hero/illustration assets**: You mentioned you will provide:
   - `onboarding_welcome_hero` - Welcome screen hero image
   - `onboarding_notifications` - Notifications explanation illustration
   - `onboarding_complete` - Completion celebration illustration

   Should I proceed with placeholder images for now, or wait for these assets?

### Already Resolved (from codebase analysis):

- **Friend code format**: Uses 6-character alphanumeric codes (uppercase, excludes confusing chars I/O/0/1). Already implemented in `InvitationRepository.swift`.

- **Invitation system**: Fully implemented with `AccountInvitation` model and `InvitationRepository`. Includes:
  - `getInvitationByCode()` for validation
  - `acceptInvitation()` for connecting users
  - Role-based permissions (owner, admin, helper, viewer)

- **Photo upload**: Can use existing Supabase Storage bucket (`profile-photos`). Will upload on completion.

---

## Recommendation

I recommend implementing in the following order:
1. Foundation models first (enables type-safe data flow)
2. Container view (establishes navigation structure)
3. Welcome + Profile screens (can test early flow)
4. Theme selection (core differentiator)
5. Remaining screens in order
6. Services (can stub initially)
7. Integration and cleanup

This allows incremental testing and user feedback throughout development.
