import SwiftUI
import PhotosUI

// MARK: - Onboarding Profile Setup View
/// Screen 2: Collect user's profile information (photo, first name, last name)
/// Features a background image in the upper portion with form below
struct OnboardingProfileSetupView: View {
    @Bindable var onboardingData: OnboardingData
    let accentColor: Color
    let onContinue: () -> Void

    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isLoadingPhoto = false
    @State private var hasAppeared = false
    @FocusState private var focusedField: Field?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    private enum Field: Hashable {
        case firstName
        case lastName
    }

    // Button gradient colors matching design
    private let buttonGradient = LinearGradient(
        colors: [Color(hex: "79A5D7"), Color(hex: "8CBFD3")],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background with image in top portion
                profileBackground(geometry: geometry)

                // Content anchored to bottom
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer()

                        // Form content
                        VStack(spacing: isRegularWidth ? 32 : 24) {
                            // Header
                            VStack(spacing: 12) {
                                Text("Let's set up your profile")
                                    .font(.appLargeTitle)
                                    .foregroundColor(.textPrimary)
                                    .multilineTextAlignment(.center)
                                    .opacity(hasAppeared ? 1 : 0)
                                    .offset(y: hasAppeared ? 0 : 15)

                                Text("This helps personalise your experience")
                                    .font(.appBody)
                                    .foregroundColor(.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .opacity(hasAppeared ? 1 : 0)
                                    .offset(y: hasAppeared ? 0 : 15)
                            }
                            .padding(.horizontal, AppDimensions.screenPadding)
                            .animation(
                                reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8),
                                value: hasAppeared
                            )

                            // Photo picker
                            photoPicker
                                .padding(.top, isRegularWidth ? 12 : 8)
                                .opacity(hasAppeared ? 1 : 0)
                                .scaleEffect(hasAppeared ? 1 : 0.9)
                                .animation(
                                    reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.1),
                                    value: hasAppeared
                                )

                            // Name fields
                            VStack(spacing: 16) {
                                // First name
                                OnboardingTextField(
                                    placeholder: "First Name",
                                    text: $onboardingData.firstName,
                                    isFocused: focusedField == .firstName,
                                    accentColor: accentColor
                                )
                                .focused($focusedField, equals: .firstName)
                                .textContentType(.givenName)
                                .submitLabel(.next)
                                .onSubmit {
                                    focusedField = .lastName
                                }
                                .opacity(hasAppeared ? 1 : 0)
                                .offset(y: hasAppeared ? 0 : 20)
                                .animation(
                                    reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.2),
                                    value: hasAppeared
                                )

                                // Last name
                                OnboardingTextField(
                                    placeholder: "Last Name",
                                    text: $onboardingData.lastName,
                                    isFocused: focusedField == .lastName,
                                    accentColor: accentColor
                                )
                                .focused($focusedField, equals: .lastName)
                                .textContentType(.familyName)
                                .submitLabel(.done)
                                .onSubmit {
                                    focusedField = nil
                                }
                                .opacity(hasAppeared ? 1 : 0)
                                .offset(y: hasAppeared ? 0 : 20)
                                .animation(
                                    reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.3),
                                    value: hasAppeared
                                )
                            }
                            .padding(.horizontal, AppDimensions.screenPadding)
                            .frame(maxWidth: isRegularWidth ? 500 : .infinity)

                            // Continue button
                            Button(action: onContinue) {
                                Text("Continue")
                                    .font(.appBodyMedium)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: AppDimensions.buttonHeight)
                                    .background(accentColor)
                                    .cornerRadius(AppDimensions.buttonCornerRadius)
                            }
                            .disabled(!onboardingData.isProfileValid)
                            .opacity(onboardingData.isProfileValid ? 1 : 0.6)
                            .frame(maxWidth: isRegularWidth ? 400 : .infinity)
                            .padding(.horizontal, AppDimensions.screenPadding)
                            .padding(.top, isRegularWidth ? 24 : 16)
                            .offset(y: hasAppeared ? 0 : 20)
                            .animation(
                                reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.4),
                                value: hasAppeared
                            )
                        }
                        .padding(.bottom, geometry.safeAreaInsets.bottom + (isRegularWidth ? 48 : 32))
                    }
                    .frame(minHeight: geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .ignoresSafeArea()
        }
        .onAppear {
            guard !hasAppeared else { return }
            if reduceMotion {
                hasAppeared = true
            } else {
                withAnimation {
                    hasAppeared = true
                }
            }
        }
    }

    // MARK: - Profile Background
    @ViewBuilder
    private func profileBackground(geometry: GeometryProxy) -> some View {
        ZStack(alignment: .top) {
            // Base dark background
            Color.appBackground

            // Background image - aligned to top, fixed position
            Image("onboarding-profile-bg")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geometry.size.width)
                .frame(maxHeight: .infinity, alignment: .top)
                .clipped()

            // Gradient overlay for smooth transition to content area
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: geometry.size.height * 0.3)

                LinearGradient(
                    colors: [
                        Color.appBackground.opacity(0),
                        Color.appBackground.opacity(0.5),
                        Color.appBackground.opacity(0.9),
                        Color.appBackground
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }

    // MARK: - Photo Picker
    private var photoPicker: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                ZStack {
                    // Background circle
                    Circle()
                        .fill(Color.white)
                        .frame(width: 100, height: 100)

                    if isLoadingPhoto {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: accentColor))
                    } else if let photo = onboardingData.profilePhoto {
                        Image(uiImage: photo)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } else {
                        // Person icon placeholder
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.black.opacity(0.3))
                    }

                    // Edit badge when photo is set
                    if onboardingData.profilePhoto != nil && !isLoadingPhoto {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: "pencil")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                            )
                            .offset(x: 35, y: 35)
                    }
                }
            }
            .accessibilityLabel(onboardingData.profilePhoto != nil ? "Change profile photo" : "Add profile photo")

            // Helper text
            Text("Add your photo")
                .font(.appCaption)
                .foregroundColor(.textSecondary)
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem = newItem else { return }
            loadPhoto(from: newItem)
        }
    }

    // MARK: - Photo Loading
    private func loadPhoto(from item: PhotosPickerItem) {
        isLoadingPhoto = true

        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        onboardingData.profilePhoto = image
                        isLoadingPhoto = false
                    }
                } else {
                    await MainActor.run {
                        isLoadingPhoto = false
                    }
                }
            } catch {
                #if DEBUG
                print("Error loading photo: \(error)")
                #endif
                await MainActor.run {
                    isLoadingPhoto = false
                }
            }
        }
    }
}

// MARK: - Onboarding Text Field
/// Styled text field for onboarding screens
struct OnboardingTextField: View {
    let placeholder: String
    @Binding var text: String
    var isFocused: Bool = false
    var accentColor: Color = .accentYellow

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.appBody)
            .foregroundColor(.textPrimary)
            .padding(.horizontal, 20)
            .frame(height: AppDimensions.textFieldHeight)
            .background(Color.cardBackground.opacity(0.8))
            .cornerRadius(AppDimensions.buttonCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                    .stroke(isFocused ? accentColor : Color.clear, lineWidth: 2)
            )
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        OnboardingProfileSetupView(
            onboardingData: OnboardingData(),
            accentColor: Color(hex: "FFC93A"),
            onContinue: {}
        )
    }
}
