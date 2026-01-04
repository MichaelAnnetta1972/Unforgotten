import SwiftUI
import PhotosUI

// MARK: - Onboarding Profile Setup View
/// Screen 2: Collect user's profile information (photo, first name, last name)
struct OnboardingProfileSetupView: View {
    @Bindable var onboardingData: OnboardingData
    let accentColor: Color
    let onContinue: () -> Void

    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isLoadingPhoto = false
    @State private var hasAppeared = false
    @FocusState private var focusedField: Field?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Field: Hashable {
        case firstName
        case lastName
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer()
                    .frame(height: 40)

                // Header
                VStack(spacing: 12) {
                    Text("Let's set up your profile")
                        .font(.appLargeTitle)
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("This helps personalize your experience")
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, AppDimensions.screenPadding)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 15)
                .animation(
                    reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8),
                    value: hasAppeared
                )

                // Photo picker
                photoPicker
                    .padding(.top, 16)
                    .opacity(hasAppeared ? 1 : 0)
                    .scaleEffect(hasAppeared ? 1 : 0.9)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.1),
                        value: hasAppeared
                    )

                // Name fields
                VStack(spacing: 16) {
                    // First name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("First name")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)

                        TextField("", text: $onboardingData.firstName)
                            .font(.appBody)
                            .foregroundColor(.textPrimary)
                            .padding()
                            .frame(height: AppDimensions.textFieldHeight)
                            .background(Color.cardBackgroundSoft)
                            .cornerRadius(AppDimensions.buttonCornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                                    .stroke(focusedField == .firstName ? accentColor : Color.textSecondary.opacity(0.3), lineWidth: 1)
                            )
                            .focused($focusedField, equals: .firstName)
                            .textContentType(.givenName)
                            .submitLabel(.next)
                            .onSubmit {
                                focusedField = .lastName
                            }
                    }
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.2),
                        value: hasAppeared
                    )

                    // Last name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Last name")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)

                        TextField("", text: $onboardingData.lastName)
                            .font(.appBody)
                            .foregroundColor(.textPrimary)
                            .padding()
                            .frame(height: AppDimensions.textFieldHeight)
                            .background(Color.cardBackgroundSoft)
                            .cornerRadius(AppDimensions.buttonCornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                                    .stroke(focusedField == .lastName ? accentColor : Color.textSecondary.opacity(0.3), lineWidth: 1)
                            )
                            .focused($focusedField, equals: .lastName)
                            .textContentType(.familyName)
                            .submitLabel(.done)
                            .onSubmit {
                                focusedField = nil
                            }
                    }
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.3),
                        value: hasAppeared
                    )
                }
                .padding(.horizontal, AppDimensions.screenPadding)

                Spacer()
                    .frame(minHeight: 60)

                // Continue button
                PrimaryButton(
                    title: "Continue",
                    backgroundColor: accentColor,
                    action: onContinue
                )
                .disabled(!onboardingData.isProfileValid)
                .opacity(onboardingData.isProfileValid ? 1 : 0.6)
                .padding(.horizontal, AppDimensions.screenPadding)
                .padding(.bottom, 48)
                .offset(y: hasAppeared ? 0 : 20)
                .animation(
                    reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.4),
                    value: hasAppeared
                )
            }
        }
        .scrollDismissesKeyboard(.interactively)
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

    // MARK: - Photo Picker
    private var photoPicker: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                ZStack {
                    // Background circle
                    Circle()
                        .fill(Color.cardBackgroundSoft)
                        .frame(width: 120, height: 120)

                    if isLoadingPhoto {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: accentColor))
                    } else if let photo = onboardingData.profilePhoto {
                        Image(uiImage: photo)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.textSecondary)

                            Text("Add Photo")
                                .font(.appCaption)
                                .foregroundColor(accentColor)
                        }
                    }

                    // Edit badge when photo is set
                    if onboardingData.profilePhoto != nil && !isLoadingPhoto {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "pencil")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                            )
                            .offset(x: 40, y: 40)
                    }
                }
            }
            .accessibilityLabel(onboardingData.profilePhoto != nil ? "Change profile photo" : "Add profile photo")

            // Skip option
            if onboardingData.profilePhoto == nil {
                Text("You can add a photo later")
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
            } else {
                Button {
                    onboardingData.profilePhoto = nil
                    selectedPhotoItem = nil
                } label: {
                    Text("Remove photo")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }
            }
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
                print("Error loading photo: \(error)")
                await MainActor.run {
                    isLoadingPhoto = false
                }
            }
        }
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
