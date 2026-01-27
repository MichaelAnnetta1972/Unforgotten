import SwiftUI

// MARK: - Onboarding View
struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appAccentColor) private var appAccentColor
    @State private var currentStep = 0

    // Form data
    @State private var accountName = ""
    @State private var primaryName = ""
    @State private var birthday: Date? = nil
    @State private var showDatePicker = false
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress indicator
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(index <= currentStep ? appAccentColor : Color.cardBackgroundSoft)
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal, AppDimensions.screenPadding)
                .padding(.top, 16)
                
                // Content
                TabView(selection: $currentStep) {
                    WelcomeStep(onContinue: { currentStep = 1 })
                        .tag(0)
                    
                    AccountSetupStep(
                        accountName: $accountName,
                        onContinue: { currentStep = 2 }
                    )
                    .tag(1)
                    
                    ProfileSetupStep(
                        primaryName: $primaryName,
                        birthday: $birthday,
                        showDatePicker: $showDatePicker,
                        isLoading: isLoading,
                        errorMessage: errorMessage,
                        onComplete: completeOnboarding
                    )
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
            }
        }
    }
    
    private func completeOnboarding() {
        guard !accountName.isBlank, !primaryName.isBlank else {
            errorMessage = "Please fill in all required fields"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await appState.completeOnboarding(
                    accountName: accountName,
                    primaryProfileName: primaryName,
                    birthday: birthday
                )
            } catch {
                #if DEBUG
                print("❌ Onboarding error: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                #endif
                errorMessage = "Failed to create account: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}

// MARK: - Welcome Step
struct WelcomeStep: View {
    @Environment(\.appAccentColor) private var appAccentColor
    let onContinue: () -> Void

    var body: some View{
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            Image(systemName: "brain.head.profile")
                .font(.system(size: 100))
                .foregroundColor(appAccentColor)
            
            VStack(spacing: 16) {
                Text("Welcome to\nUnforgotten")
                    .font(.appLargeTitle)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("Help yourself or your loved ones remember what matters most.")
                    .font(.appBody)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // Features preview
            VStack(spacing: 16) {
                FeatureRow(icon: "pills.fill", title: "Medications", description: "Track and remember medication schedules")
                FeatureRow(icon: "calendar", title: "Appointments", description: "Never miss an important appointment")
                FeatureRow(icon: "gift.fill", title: "Gift Ideas", description: "Remember gift ideas for loved ones")
                FeatureRow(icon: "person.2.fill", title: "Family Network", description: "Share access with family members")
            }
            .padding(.horizontal)
            
            Spacer()
            
            PrimaryButton(title: "Get Started", action: onContinue)
                .padding(.horizontal, AppDimensions.screenPadding)
                .padding(.bottom, 32)
        }
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    @Environment(\.appAccentColor) private var appAccentColor
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(appAccentColor)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.appBodyMedium)
                    .foregroundColor(.textPrimary)
                
                Text(description)
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Account Setup Step
struct AccountSetupStep: View {
    @Environment(\.appAccentColor) private var appAccentColor
    @Binding var accountName: String
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(appAccentColor)
                
                Text("Who is this account for?")
                    .font(.appTitle)
                    .foregroundColor(.textPrimary)
                
                Text("This helps us personalize the experience.")
                    .font(.appBody)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                AppTextField(placeholder: "e.g., Mum's Account, My Health", text: $accountName)
                
                Text("You can change this later in Settings")
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
            }
            .padding(.horizontal, AppDimensions.screenPadding)
            
            Spacer()
            
            VStack(spacing: 12) {
                PrimaryButton(title: "Continue", action: onContinue)
                    .disabled(accountName.isBlank)
            }
            .padding(.horizontal, AppDimensions.screenPadding)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - Profile Setup Step
struct ProfileSetupStep: View {
    @Environment(\.appAccentColor) private var appAccentColor
    @Binding var primaryName: String
    @Binding var birthday: Date?
    @Binding var showDatePicker: Bool
    let isLoading: Bool
    let errorMessage: String?
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(appAccentColor)
                
                Text("Create the primary profile")
                    .font(.appTitle)
                    .foregroundColor(.textPrimary)
                
                Text("This is the main person this account is helping.")
                    .font(.appBody)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                AppTextField(placeholder: "Full Name", text: $primaryName)
                
                // Birthday picker button
                Button {
                    showDatePicker = true
                } label: {
                    HStack {
                        Text(birthday != nil ? birthday!.formattedBirthday() : "Birthday (optional)")
                            .foregroundColor(birthday != nil ? .textPrimary : .textSecondary)
                        
                        Spacer()
                        
                        Image(systemName: "calendar")
                            .foregroundColor(.textSecondary)
                    }
                    .padding()
                    .frame(height: AppDimensions.textFieldHeight)
                    .background(Color.cardBackgroundSoft)
                    .cornerRadius(AppDimensions.buttonCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                            .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
                    )
                }
                
                if let error = errorMessage {
                    Text(error)
                        .font(.appCaption)
                        .foregroundColor(.medicalRed)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, AppDimensions.screenPadding)
            
            Spacer()
            
            PrimaryButton(title: "Complete Setup", isLoading: isLoading, action: onComplete)
                .disabled(primaryName.isBlank)
                .padding(.horizontal, AppDimensions.screenPadding)
                .padding(.bottom, 32)
        }
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(selectedDate: $birthday, isPresented: $showDatePicker)
        }
    }
}

// MARK: - Date Picker Sheet
struct DatePickerSheet: View {
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Binding var selectedDate: Date?
    @Binding var isPresented: Bool
    var title: String = "Birthday"

    @State private var tempDate = Date()

    /// Custom height for date picker - taller on iPad to fit the full calendar
    private var datePickerHeight: PresentationDetent {
        horizontalSizeClass == .regular ? .fraction(0.7) : .height(480)
    }

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    title,
                    selection: $tempDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(appAccentColor)
                .padding()

                Spacer()
            }
            .background(Color.appBackground)
            .navigationTitle("Select \(title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        selectedDate = tempDate
                        isPresented = false
                    }
                    .foregroundColor(appAccentColor)
                }
            }
        }
        .presentationDetents([datePickerHeight, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            if let date = selectedDate {
                tempDate = date
            }
        }
    }
}

// MARK: - Preview
#Preview {
    OnboardingView()
        .environmentObject(AppState.forPreview())
}
