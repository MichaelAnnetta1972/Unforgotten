import SwiftUI

// MARK: - Onboarding First Profile View
/// Screen 5: Optional first profile (a relative or friend) the user can add during onboarding.
/// Stores data on OnboardingData; the profile row is created in OnboardingService after the
/// account and primary profile exist.
struct OnboardingFirstProfileView: View {
    @Bindable var onboardingData: OnboardingData
    let accentColor: Color
    let onContinue: () -> Void

    @State private var hasAppeared = false
    @State private var showRelationshipPicker = false
    @State private var showBirthdayPicker = false
    @FocusState private var focusedField: Field?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    private enum Field: Hashable {
        case name
        case email
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        Spacer()
                            .frame(height: geometry.safeAreaInsets.top + 72)

                        VStack(spacing: isRegularWidth ? 32 : 24) {
                            header

                            form

                            buttons
                        }
                        .frame(maxWidth: isRegularWidth ? 500 : .infinity)
                        .padding(.bottom, geometry.safeAreaInsets.bottom + (isRegularWidth ? 48 : 32))
                    }
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .ignoresSafeArea(.container, edges: .top)
        }
        .environment(\.appAccentColor, accentColor)
        .sheet(isPresented: $showRelationshipPicker) {
            RelationshipPickerSheet(
                selectedRelationship: $onboardingData.firstProfileRelationship,
                isPresented: $showRelationshipPicker
            )
            .environment(\.appAccentColor, accentColor)
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

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            Text("Add a family member\nor friend")
                .font(.appLargeTitle)
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 10)

            Text("Start building your network.")
                .font(.appBody)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 10)
        }
        .padding(.horizontal, AppDimensions.screenPadding)
        .animation(
            reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8),
            value: hasAppeared
        )
    }

    // MARK: - Form

    private var form: some View {
        VStack(spacing: 16) {
            Spacer()
            // Name
            TextField("Name", text: $onboardingData.firstProfileName)
                .font(.appBody)
                .foregroundColor(.textPrimary)
                .padding()
                .frame(height: AppDimensions.textFieldHeight)
                .background(Color.cardBackground)
                .cornerRadius(AppDimensions.buttonCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                        .stroke(
                            focusedField == .name ? accentColor : Color.textSecondary.opacity(0.3),
                            lineWidth: focusedField == .name ? 2 : 1
                        )
                )
                .focused($focusedField, equals: .name)
                .textInputAutocapitalization(.words)
                .submitLabel(.next)
                .onSubmit { focusedField = .email }

            // Relationship
            RelationshipFieldWithPicker(
                relationship: $onboardingData.firstProfileRelationship,
                showPicker: $showRelationshipPicker
            )

            // Birthday (optional)
            birthdayField

            // Email (optional)
            TextField("Email (optional)", text: $onboardingData.firstProfileEmail)
                .font(.appBody)
                .foregroundColor(.textPrimary)
                .padding()
                .frame(height: AppDimensions.textFieldHeight)
                .background(Color.cardBackground)
                .cornerRadius(AppDimensions.buttonCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                        .stroke(
                            focusedField == .email ? accentColor : Color.textSecondary.opacity(0.3),
                            lineWidth: focusedField == .email ? 2 : 1
                        )
                )
                .focused($focusedField, equals: .email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit { focusedField = nil }
            Spacer()
        }
        .padding(.horizontal, AppDimensions.screenPadding)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(
            reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.15),
            value: hasAppeared
        )
        
    }

    private var birthdayField: some View {
        Button {
            focusedField = nil
            showBirthdayPicker.toggle()
        } label: {
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.textSecondary)

                Text(birthdayDisplayText)
                    .font(.appBody)
                    .foregroundColor(onboardingData.firstProfileBirthday == nil ? .textSecondary : .textPrimary)

                Spacer()

                if onboardingData.firstProfileBirthday != nil {
                    Button {
                        onboardingData.firstProfileBirthday = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .frame(height: AppDimensions.textFieldHeight)
            .background(Color.cardBackground)
            .cornerRadius(AppDimensions.buttonCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                    .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showBirthdayPicker) {
            BirthdayPickerSheet(
                birthday: $onboardingData.firstProfileBirthday,
                accentColor: accentColor,
                isPresented: $showBirthdayPicker
            )
            .presentationDetents([.medium])
        }
    }

    private var birthdayDisplayText: String {
        if let birthday = onboardingData.firstProfileBirthday {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: birthday)
        }
        return "Birthday (optional)"
    }

    // MARK: - Buttons

    private var buttons: some View {
        VStack(spacing: isRegularWidth ? 20 : 16) {
            Button(action: continueTapped) {
                Text("Continue")
                    .font(.appBodyMedium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: AppDimensions.buttonHeight)
                    .background(accentColor)
                    .cornerRadius(AppDimensions.buttonCornerRadius)
            }

            Button {
                skipTapped()
            } label: {
                Text("Skip for now")
                    .font(.appBodyMedium)
                    .foregroundColor(.textSecondary)
            }
        }
        .frame(maxWidth: isRegularWidth ? 400 : .infinity)
        .padding(.horizontal, AppDimensions.screenPadding)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(
            reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.25),
            value: hasAppeared
        )
    }

    // MARK: - Actions

    private func continueTapped() {
        focusedField = nil
        // If the name is blank, treat this as a skip — no profile will be created.
        onContinue()
    }

    private func skipTapped() {
        focusedField = nil
        // Clear any partially entered data so OnboardingService doesn't try to create a profile.
        onboardingData.firstProfileName = ""
        onboardingData.firstProfileRelationship = ""
        onboardingData.firstProfileBirthday = nil
        onboardingData.firstProfileEmail = ""
        onContinue()
    }
}

// MARK: - Birthday Picker Sheet

private struct BirthdayPickerSheet: View {
    @Binding var birthday: Date?
    let accentColor: Color
    @Binding var isPresented: Bool

    @State private var workingDate: Date = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack {
                    DatePicker(
                        "Birthday",
                        selection: $workingDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .tint(accentColor)

                    Spacer()
                }
                .padding(.top, 16)
            }
            .navigationTitle("Birthday")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        birthday = workingDate
                        isPresented = false
                    }
                    .foregroundColor(accentColor)
                }
            }
        }
        .onAppear {
            if let existing = birthday {
                workingDate = existing
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        OnboardingFirstProfileView(
            onboardingData: OnboardingData(),
            accentColor: Color(hex: "FFC93A"),
            onContinue: {}
        )
    }
}
