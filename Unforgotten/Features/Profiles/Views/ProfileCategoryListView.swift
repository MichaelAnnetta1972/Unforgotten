import SwiftUI

// MARK: - Category Type
enum ProfileCategoryType: Identifiable {
    case clothing
    case gifts
    case medical

    var id: String {
        switch self {
        case .clothing: return "clothing"
        case .gifts: return "gifts"
        case .medical: return "medical"
        }
    }

    var title: String {
        switch self {
        case .clothing: return "Clothing Sizes"
        case .gifts: return "Gift Ideas"
        case .medical: return "Medical Conditions"
        }
    }
    
    var icon: String {
        switch self {
        case .clothing: return "tshirt.fill"
        case .gifts: return "gift.fill"
        case .medical: return "cross.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .clothing: return .clothingBlue
        case .gifts: return .giftPurple
        case .medical: return .medicalRed
        }
    }
}

// MARK: - Profile Category List View
struct ProfileCategoryListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.navigateToRoot) var navigateToRoot

    let profile: Profile
    let category: ProfileCategoryType
    let details: [ProfileDetail]

    @State private var showAddDetail = false
    @State private var showSettings = false
    @State private var currentDetails: [ProfileDetail]
    @State private var editingDetail: ProfileDetail?

    init(profile: Profile, category: ProfileCategoryType, details: [ProfileDetail]) {
        self.profile = profile
        self.category = category
        self.details = details
        self._currentDetails = State(initialValue: details)
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header at the top - fully interactive
                CategoryHeaderView(
                    profile: profile,
                    category: category,
                    onBack: { dismiss() }
                )

                // Content scrolls below header
                ScrollView {
                    VStack(spacing: AppDimensions.cardSpacing) {
                        // Section header card
                        SectionHeaderCard(
                            title: category.title,
                            icon: category.icon,
                            backgroundColor: category.color
                        )

                        // Details list
                        VStack(spacing: AppDimensions.cardSpacing) {
                            ForEach(currentDetails) { detail in
                                switch category {
                                case .clothing:
                                    ValuePillCard(
                                        category: "Clothing",
                                        label: detail.label,
                                        value: detail.value,
                                        onEdit: {
                                            editingDetail = detail
                                        },
                                        onDelete: {
                                            Task {
                                                await deleteDetail(detail: detail)
                                            }
                                        }
                                    )

                                case .gifts:
                                    GiftItemCard(
                                        label: detail.label,
                                        status: giftStatus(from: detail.status),
                                        onStatusChange: { newStatus in
                                            Task {
                                                await updateGiftStatus(detail: detail, newStatus: newStatus)
                                            }
                                        },
                                        onDelete: {
                                            Task {
                                                await deleteDetail(detail: detail)
                                            }
                                        }
                                    )

                                case .medical:
                                    MedicalConditionCard(
                                        type: detail.category == .allergy ? "Allergy" : "Medical Condition",
                                        condition: detail.value.isEmpty ? detail.label : detail.value
                                    )
                                }
                            }
                        }

                        // Empty state
                        if currentDetails.isEmpty {
                            VStack(spacing: 12) {
                                Text("No medical conditions yet")
                                    .font(.appCardTitle)
                                    .foregroundColor(.textPrimary)

                                Text("Tap + to add the first one")
                                    .font(.appBody)
                                    .foregroundColor(.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        }

                        Spacer()
                            .frame(height: 140)
                    }
                    .padding(.horizontal, AppDimensions.screenPadding)
                    .padding(.top, AppDimensions.cardSpacing)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        .sheet(isPresented: $showAddDetail) {
            AddProfileDetailView(
                profile: profile,
                category: category
            ) { newDetail in
                currentDetails.append(newDetail)
            }
        }
        .sheet(item: $editingDetail) { detail in
            EditClothingDetailView(
                detail: detail,
                onSave: { updatedDetail in
                    if let index = currentDetails.firstIndex(where: { $0.id == detail.id }) {
                        currentDetails[index] = updatedDetail
                    }
                }
            )
        }
    }
    
    private func giftStatus(from status: String?) -> GiftItemCard.GiftStatus {
        switch status {
        case "bought": return .bought
        case "given": return .given
        default: return .idea
        }
    }

    private func updateGiftStatus(detail: ProfileDetail, newStatus: GiftItemCard.GiftStatus) async {
        var updatedDetail = detail
        updatedDetail.status = newStatus.rawValue

        do {
            let saved = try await appState.profileRepository.updateProfileDetail(updatedDetail)
            if let index = currentDetails.firstIndex(where: { $0.id == detail.id }) {
                currentDetails[index] = saved
            }
        } catch {
            print("Failed to update gift status: \(error)")
        }
    }

    private func deleteDetail(detail: ProfileDetail) async {
        do {
            try await appState.profileRepository.deleteProfileDetail(id: detail.id)
            currentDetails.removeAll { $0.id == detail.id }
        } catch {
            print("Failed to delete detail: \(error)")
        }
    }
}

// MARK: - Category Header View
struct CategoryHeaderView: View {
    let profile: Profile
    let category: ProfileCategoryType
    let onBack: () -> Void

    init(profile: Profile, category: ProfileCategoryType, onBack: @escaping () -> Void) {
        self.profile = profile
        self.category = category
        self.onBack = onBack
    }

    private var headerImageName: String {
        switch category {
        case .clothing: return "header-clothing"
        case .gifts: return "header-gifts"
        case .medical: return "header-medical"
        }
    }

    var body: some View {
        HeaderImageView(
            imageName: headerImageName,
            title: profile.fullName,
            subtitle: category.title,
            showBackButton: true,
            backAction: onBack
        )
    }
}

// MARK: - Add Profile Detail View
struct AddProfileDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    let profile: Profile
    let category: ProfileCategoryType
    let onSave: (ProfileDetail) -> Void
    
    @State private var label = ""
    @State private var value = ""
    @State private var status = "idea"
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSizePicker = false

    // Preset options for clothing
    private let clothingTypes = ["Jacket", "Pants", "Shoes", "T-Shirt", "Dress Shirt", "Belt", "Hat", "Gloves", "Socks", "Underwear", "Other"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Category-specific form
                        switch category {
                        case .clothing:
                            clothingForm
                        case .gifts:
                            giftForm
                        case .medical:
                            medicalForm
                        }
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.appCaption)
                                .foregroundColor(.medicalRed)
                        }
                    }
                    .padding(AppDimensions.screenPadding)
                }
            }
            .navigationTitle("Add \(category.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveDetail() }
                    }
                    .foregroundColor(.accentYellow)
                    .disabled(label.isBlank || isLoading)
                }
            }
        }
    }
    
    // MARK: - Clothing Form
    private var clothingForm: some View {
        VStack(spacing: 16) {
            // Type picker with flow layout
            VStack(alignment: .leading, spacing: 8) {
                Text("Clothing Type")
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)

                FlowLayout(spacing: 8) {
                    ForEach(clothingTypes, id: \.self) { type in
                        Button {
                            label = type
                        } label: {
                            Text(type)
                                .font(.appCaption)
                                .foregroundColor(label == type ? .black : .textPrimary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(label == type ? Color.accentYellow : Color.cardBackgroundSoft)
                                .cornerRadius(20)
                        }
                    }
                }
            }

            // Custom type
            AppTextField(placeholder: "Or enter custom type", text: $label)

            // Size value with picker button
            VStack(alignment: .leading, spacing: 8) {
                Text("Size")
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)

                SizeFieldWithPicker(size: $value, showPicker: $showSizePicker)
            }
        }
        .sheet(isPresented: $showSizePicker) {
            SizePickerSheet(selectedSize: $value, isPresented: $showSizePicker)
        }
    }
    
    // MARK: - Gift Form
    private var giftForm: some View {
        VStack(spacing: 16) {
            AppTextField(placeholder: "Gift idea", text: $label)
            
            // Status picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Status")
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
                
                HStack(spacing: 12) {
                    StatusButton(title: "Idea", isSelected: status == "idea") {
                        status = "idea"
                    }
                    StatusButton(title: "Bought", isSelected: status == "bought") {
                        status = "bought"
                    }
                    StatusButton(title: "Given", isSelected: status == "given") {
                        status = "given"
                    }
                }
            }
        }
    }
    
    // Common medical conditions for quick select
    private let commonConditions = ["Dementia", "Alzheimer's", "Diabetes", "Heart Disease", "High Blood Pressure", "Arthritis", "Parkinson's", "Stroke", "Osteoporosis", "Hearing Loss" , "Vision Impairment" , "Anxiety", "Incontenence", "Tinnitus", "Asthma", "Cancer", "Depression"]
    private let commonAllergies = ["Penicillin", "Sulfa Drugs", "Aspirin", "Ibuprofen", "Latex", "Peanuts", "Tree Nuts", "Shellfish", "Eggs", "Dairy", "Gluten", "Soy", "Bee Stings" , "Pollen"]

    // MARK: - Medical Form
    private var medicalForm: some View {
        VStack(spacing: 16) {
            // Type picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Type")
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)

                HStack(spacing: 12) {
                    StatusButton(title: "Condition", isSelected: value == "condition") {
                        value = "condition"
                    }
                    StatusButton(title: "Allergy", isSelected: value == "allergy") {
                        value = "allergy"
                    }
                }
            }

            // Quick select options
            VStack(alignment: .leading, spacing: 8) {
                Text(value == "allergy" ? "COMMON ALLERGIES" : "COMMON CONDITIONS")
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)

                FlowLayout(spacing: 8) {
                    ForEach(value == "allergy" ? commonAllergies : commonConditions, id: \.self) { item in
                        Button {
                            label = item
                        } label: {
                            Text(item)
                                .font(.appCaption)
                                .foregroundColor(label == item ? .black : .textPrimary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(label == item ? Color.accentYellow : Color.cardBackgroundSoft)
                                .cornerRadius(20)
                        }
                    }
                }
            }

            AppTextField(placeholder: "Or enter custom \(value == "allergy" ? "allergy" : "condition")", text: $label)
        }
    }
    
    // MARK: - Save
    private func saveDetail() async {
        guard let account = appState.currentAccount else { return }
        guard !label.isBlank else {
            errorMessage = "Please fill in all required fields"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let detailCategory: DetailCategory
        switch category {
        case .clothing:
            detailCategory = .clothing
        case .gifts:
            detailCategory = .giftIdea
        case .medical:
            detailCategory = value == "allergy" ? .allergy : .medicalCondition
        }
        
        let insert = ProfileDetailInsert(
            accountId: account.id,
            profileId: profile.id,
            category: detailCategory,
            label: label,
            value: category == .clothing ? value : label,
            status: category == .gifts ? status : nil
        )
        
        do {
            let newDetail = try await appState.profileRepository.createProfileDetail(insert)
            onSave(newDetail)
            dismiss()
        } catch {
            errorMessage = "Failed to save. Please try again."
        }
        
        isLoading = false
    }
}

// MARK: - Edit Clothing Detail View
struct EditClothingDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    let detail: ProfileDetail
    let onSave: (ProfileDetail) -> Void

    @State private var label: String
    @State private var value: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSizePicker = false

    private let clothingTypes = ["Jacket", "Pants", "Shoes", "T-Shirt", "Dress Shirt", "Belt", "Hat", "Gloves", "Socks", "Underwear", "Other"]

    init(detail: ProfileDetail, onSave: @escaping (ProfileDetail) -> Void) {
        self.detail = detail
        self.onSave = onSave
        self._label = State(initialValue: detail.label)
        self._value = State(initialValue: detail.value)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Type picker with flow layout
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Clothing Type")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)

                            FlowLayout(spacing: 8) {
                                ForEach(clothingTypes, id: \.self) { type in
                                    Button {
                                        label = type
                                    } label: {
                                        Text(type)
                                            .font(.appCaption)
                                            .foregroundColor(label == type ? .black : .textPrimary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(label == type ? Color.accentYellow : Color.cardBackgroundSoft)
                                            .cornerRadius(20)
                                    }
                                }
                            }
                        }

                        // Custom type
                        AppTextField(placeholder: "Or enter custom type", text: $label)

                        // Size value with picker button
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Size")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)

                            SizeFieldWithPicker(size: $value, showPicker: $showSizePicker)
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.appCaption)
                                .foregroundColor(.medicalRed)
                        }
                    }
                    .padding(AppDimensions.screenPadding)
                }
            }
            .navigationTitle("Edit Clothing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveChanges() }
                    }
                    .foregroundColor(.accentYellow)
                    .disabled(label.isBlank || isLoading)
                }
            }
            .sheet(isPresented: $showSizePicker) {
                SizePickerSheet(selectedSize: $value, isPresented: $showSizePicker)
            }
        }
    }

    private func saveChanges() async {
        guard !label.isBlank else {
            errorMessage = "Please enter a clothing type"
            return
        }

        isLoading = true
        errorMessage = nil

        var updatedDetail = detail
        updatedDetail.label = label
        updatedDetail.value = value

        do {
            let saved = try await appState.profileRepository.updateProfileDetail(updatedDetail)
            onSave(saved)
            dismiss()
        } catch {
            errorMessage = "Failed to save. Please try again."
        }

        isLoading = false
    }
}

// MARK: - Status Button
struct StatusButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.appCaption)
                .foregroundColor(isSelected ? .black : .textPrimary)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(isSelected ? Color.accentYellow : Color.cardBackgroundSoft)
                .cornerRadius(AppDimensions.buttonCornerRadius)
        }
    }
}

// MARK: - Profile Detail Row View
struct ProfileDetailRowView: View {
    let detail: ProfileDetail

    var body: some View {
        HStack {
            // Icon based on category
            Image(systemName: iconForCategory)
                .font(.system(size: 16))
                .foregroundColor(colorForCategory)
                .frame(width: 32, height: 32)
                .background(colorForCategory.opacity(0.2))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(detail.label)
                    .font(.appBodyMedium)
                    .foregroundColor(.textPrimary)

                if !detail.value.isEmpty && detail.value != detail.label {
                    Text(detail.value)
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }
            }

            Spacer()

            if let status = detail.status {
                Text(status.capitalized)
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.cardBackgroundSoft)
                    .cornerRadius(8)
            }
        }
        .padding(12)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }

    private var iconForCategory: String {
        switch detail.category {
        case .clothing: return "tshirt.fill"
        case .giftIdea: return "gift.fill"
        case .medicalCondition: return "cross.fill"
        case .allergy: return "exclamationmark.triangle.fill"
        case .like: return "hand.thumbsup.fill"
        case .dislike: return "hand.thumbsdown.fill"
        case .note: return "note.text"
        }
    }

    private var colorForCategory: Color {
        switch detail.category {
        case .clothing: return .clothingBlue
        case .giftIdea: return .giftPurple
        case .medicalCondition, .allergy: return .medicalRed
        case .like: return .badgeGreen
        case .dislike: return .textSecondary
        case .note: return .accentYellow
        }
    }
}

// MARK: - Add Profile View
struct AddProfileView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    let onSave: (Profile) -> Void
    
    @State private var fullName = ""
    @State private var preferredName = ""
    @State private var relationship = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var address = ""
    @State private var birthday: Date? = nil
    @State private var showDatePicker = false
    @State private var showRelationshipPicker = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        HeaderImageView(
                            imageName: "header-add-profile",
                            title: "Add Person"
                        )
                        .padding(.horizontal, AppDimensions.screenPadding)

                        AppTextField(placeholder: "Full Name *", text: $fullName)
                        AppTextField(placeholder: "Preferred Name (optional)", text: $preferredName)

                        // Relationship field with quick-add button
                        RelationshipFieldWithPicker(
                            relationship: $relationship,
                            showPicker: $showRelationshipPicker
                        )

                        AppTextField(placeholder: "Phone", text: $phone, keyboardType: .phonePad)
                        AppTextField(placeholder: "Email", text: $email, keyboardType: .emailAddress)
                        AppTextField(placeholder: "Address", text: $address)
                        
                        // Birthday picker
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
                        }
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.appCaption)
                                .foregroundColor(.medicalRed)
                        }
                    }
                    .padding(AppDimensions.screenPadding)
                }
            }
            .navigationTitle("Add Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveProfile() }
                    }
                    .foregroundColor(.accentYellow)
                    .disabled(fullName.isBlank || isLoading)
                }
            }
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(selectedDate: $birthday, isPresented: $showDatePicker)
            }
            .sheet(isPresented: $showRelationshipPicker) {
                RelationshipPickerSheet(selectedRelationship: $relationship, isPresented: $showRelationshipPicker)
            }
        }
    }

    private func saveProfile() async {
        guard let account = appState.currentAccount else { return }
        guard !fullName.isBlank else {
            errorMessage = "Please enter a name"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let insert = ProfileInsert(
            accountId: account.id,
            type: .relative,
            fullName: fullName,
            preferredName: preferredName.isBlank ? nil : preferredName,
            relationship: relationship.isBlank ? nil : relationship,
            birthday: birthday,
            address: address.isBlank ? nil : address,
            phone: phone.isBlank ? nil : phone,
            email: email.isBlank ? nil : email
        )
        
        do {
            let newProfile = try await appState.profileRepository.createProfile(insert)

            // Schedule birthday reminder if birthday was set
            if newProfile.birthday != nil {
                await appState.scheduleBirthdayReminder(for: newProfile)
            }

            onSave(newProfile)
            dismiss()
        } catch {
            print("❌ Profile creation error: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }

        isLoading = false
    }
}

// MARK: - Edit Profile View
struct EditProfileView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    let profile: Profile
    let onSave: (Profile) -> Void

    @State private var fullName: String
    @State private var preferredName: String
    @State private var relationship: String
    @State private var phone: String
    @State private var email: String
    @State private var address: String
    @State private var birthday: Date?
    @State private var selectedImage: UIImage?
    @State private var showDatePicker = false
    @State private var showRelationshipPicker = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showAddCustomField = false
    @State private var customFields: [ProfileDetail] = []

    init(profile: Profile, onSave: @escaping (Profile) -> Void) {
        self.profile = profile
        self.onSave = onSave
        self._fullName = State(initialValue: profile.fullName)
        self._preferredName = State(initialValue: profile.preferredName ?? "")
        self._relationship = State(initialValue: profile.relationship ?? "")
        self._phone = State(initialValue: profile.phone ?? "")
        self._email = State(initialValue: profile.email ?? "")
        self._address = State(initialValue: profile.address ?? "")
        self._birthday = State(initialValue: profile.birthday)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Profile Photo
                        PhotoPickerButton(
                            selectedImage: $selectedImage,
                            currentPhotoURL: profile.photoUrl,
                            size: 120
                        )
                        .padding(.bottom, 8)

                        AppTextField(placeholder: "Full Name *", text: $fullName)
                        AppTextField(placeholder: "Preferred Name", text: $preferredName)

                        // Relationship field with quick-add button
                        RelationshipFieldWithPicker(
                            relationship: $relationship,
                            showPicker: $showRelationshipPicker
                        )

                        AppTextField(placeholder: "Phone", text: $phone, keyboardType: .phonePad)
                        AppTextField(placeholder: "Email", text: $email, keyboardType: .emailAddress)
                        AppTextField(placeholder: "Address", text: $address)

                        Button {
                            showDatePicker = true
                        } label: {
                            HStack {
                                Text(birthday != nil ? birthday!.formattedBirthday() : "Birthday")
                                    .foregroundColor(birthday != nil ? .textPrimary : .textSecondary)

                                Spacer()

                                Image(systemName: "calendar")
                                    .foregroundColor(.textSecondary)
                            }
                            .padding()
                            .frame(height: AppDimensions.textFieldHeight)
                            .background(Color.cardBackgroundSoft)
                            .cornerRadius(AppDimensions.buttonCornerRadius)
                        }

                        // Custom Fields Section
                        if !customFields.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("ADDITIONAL INFORMATION")
                                    .font(.appCaption)
                                    .foregroundColor(.textSecondary)

                                ForEach(customFields) { field in
                                    CustomFieldRowView(detail: field)
                                }
                            }
                            .padding(.top, 8)
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.appCaption)
                                .foregroundColor(.medicalRed)
                        }

                        // Extra space for floating button
                        Spacer()
                            .frame(height: 80)
                    }
                    .padding(AppDimensions.screenPadding)
                }

                // Floating add button with fade
                FloatingButtonContainer {
                    FloatingAddButton {
                        showAddCustomField = true
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await updateProfile() }
                    }
                    .foregroundColor(.accentYellow)
                    .disabled(fullName.isBlank || isLoading)
                }
            }
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(selectedDate: $birthday, isPresented: $showDatePicker)
            }
            .sheet(isPresented: $showRelationshipPicker) {
                RelationshipPickerSheet(selectedRelationship: $relationship, isPresented: $showRelationshipPicker)
            }
            .sheet(isPresented: $showAddCustomField) {
                AddCustomFieldView(profile: profile) { newField in
                    customFields.append(newField)
                }
            }
            .task {
                await loadCustomFields()
            }
        }
    }

    private func loadCustomFields() async {
        do {
            // Load only note-type details (custom fields)
            let allDetails = try await appState.profileRepository.getProfileDetails(profileId: profile.id)
            customFields = allDetails.filter { $0.category == .note }
        } catch {
            print("Failed to load custom fields: \(error)")
        }
    }
    
    private func updateProfile() async {
        guard !fullName.isBlank else {
            errorMessage = "Please enter a name"
            return
        }

        isLoading = true
        errorMessage = nil

        var updatedProfile = profile
        updatedProfile.fullName = fullName
        updatedProfile.preferredName = preferredName.isBlank ? nil : preferredName
        updatedProfile.relationship = relationship.isBlank ? nil : relationship
        updatedProfile.phone = phone.isBlank ? nil : phone
        updatedProfile.email = email.isBlank ? nil : email
        updatedProfile.address = address.isBlank ? nil : address
        updatedProfile.birthday = birthday

        do {
            // Upload photo if selected (skip if storage not configured)
            if let image = selectedImage {
                do {
                    let photoURL = try await ImageUploadService.shared.uploadProfilePhoto(
                        image: image,
                        profileId: profile.id
                    )
                    updatedProfile.photoUrl = photoURL
                } catch {
                    // Photo upload failed - continue saving profile without photo
                    print("Photo upload failed: \(error.localizedDescription)")
                }
            }

            let saved = try await appState.profileRepository.updateProfile(updatedProfile)

            // Update birthday reminder
            if saved.birthday != nil {
                await appState.scheduleBirthdayReminder(for: saved)
            } else {
                // Cancel if birthday was removed
                appState.cancelBirthdayReminder(for: saved.id)
            }

            onSave(saved)
            dismiss()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }

        isLoading = false
    }
}

// MARK: - Custom Field Row View
struct CustomFieldRowView: View {
    let detail: ProfileDetail

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(detail.label)
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)

                Text(detail.value)
                    .font(.appBodyMedium)
                    .foregroundColor(.textPrimary)
            }

            Spacer()
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Add Custom Field View
struct AddCustomFieldView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    let profile: Profile
    let onSave: (ProfileDetail) -> Void

    @State private var label = ""
    @State private var value = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Common field suggestions
    private let suggestions = [
        "Driver's License",
        "Work Phone",
        "Mobile Phone",
        "Passport Number",
        "Medicare Number",
        "Insurance Policy",
        "Emergency Contact",
        "Blood Type",
        "Social Security",
        "Tax File Number"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Quick suggestions
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Quick Add")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)

                            FlowLayout(spacing: 8) {
                                ForEach(suggestions, id: \.self) { suggestion in
                                    Button {
                                        label = suggestion
                                    } label: {
                                        Text(suggestion)
                                            .font(.appCaption)
                                            .foregroundColor(label == suggestion ? .black : .textPrimary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(label == suggestion ? Color.accentYellow : Color.cardBackgroundSoft)
                                            .cornerRadius(16)
                                    }
                                }
                            }
                        }

                        // Custom label input
                        AppTextField(placeholder: "Label (e.g., Driver's License)", text: $label)

                        // Value input
                        AppTextField(placeholder: "Value", text: $value)

                        if let error = errorMessage {
                            Text(error)
                                .font(.appCaption)
                                .foregroundColor(.medicalRed)
                        }
                    }
                    .padding(AppDimensions.screenPadding)
                }
            }
            .navigationTitle("Add Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveField() }
                    }
                    .foregroundColor(.accentYellow)
                    .disabled(label.isBlank || value.isBlank || isLoading)
                }
            }
        }
    }

    private func saveField() async {
        guard let account = appState.currentAccount else { return }
        guard !label.isBlank && !value.isBlank else {
            errorMessage = "Please fill in both fields"
            return
        }

        isLoading = true
        errorMessage = nil

        let insert = ProfileDetailInsert(
            accountId: account.id,
            profileId: profile.id,
            category: .note,
            label: label,
            value: value,
            status: nil
        )

        do {
            let newDetail = try await appState.profileRepository.createProfileDetail(insert)
            onSave(newDetail)
            dismiss()
        } catch {
            errorMessage = "Failed to save. Please try again."
        }

        isLoading = false
    }
}

// MARK: - Flow Layout (for suggestion chips)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)

        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var positions: [CGPoint] = []

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: currentY + lineHeight), positions)
    }
}

// MARK: - Connections List View
struct ConnectionsListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.navigateToRoot) var navigateToRoot

    let profile: Profile

    @State private var connections: [ConnectionWithProfile] = []
    @State private var isLoading = false
    @State private var showAddConnection = false
    @State private var showFamilyTree = false
    @State private var showSettings = false
    @State private var error: String?

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header at the top - fully interactive
                ConnectionsHeaderView(
                    profile: profile,
                    onBack: { dismiss() },
                    onFamilyTree: { showFamilyTree = true }
                )

                // Content scrolls below header
                ScrollView {
                    VStack(spacing: AppDimensions.cardSpacing) {
                        // Section header card
                        SectionHeaderCard(
                            title: "Connections",
                            icon: "person.2.fill",
                            backgroundColor: .connectionsGreen
                        )

                        // Connections list
                        if !connections.isEmpty {
                            VStack(spacing: AppDimensions.cardSpacing) {
                                ForEach(connections) { connectionWithProfile in
                                    NavigationLink(destination: ConnectionsListView(profile: connectionWithProfile.connectedProfile)) {
                                        ConnectionCard(
                                            profile: connectionWithProfile.connectedProfile,
                                            relationshipType: connectionWithProfile.connection.relationshipType
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }

                        // Loading state
                        if isLoading {
                            LoadingView(message: "Loading connections...")
                                .padding(.top, 40)
                        }

                        // Empty state
                        if connections.isEmpty && !isLoading {
                            VStack(spacing: 12) {
                                Image(systemName: "person.2.slash")
                                    .font(.system(size: 48))
                                    .foregroundColor(.textSecondary)

                                Text("No connections yet")
                                    .font(.appCardTitle)
                                    .foregroundColor(.textPrimary)

                                Text("Add a connection from the menu below")
                                    .font(.appBody)
                                    .foregroundColor(.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        }

                        Spacer()
                            .frame(height: 140)
                    }
                    .padding(.horizontal, AppDimensions.screenPadding)
                    .padding(.top, AppDimensions.cardSpacing)
                }
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showFamilyTree) {
            FamilyTreeView(rootProfile: profile)
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        .sheet(isPresented: $showAddConnection) {
            AddConnectionView(profile: profile) { newConnection in
                Task {
                    await loadConnections()
                }
            }
        }
        .task {
            await loadConnections()
        }
        .refreshable {
            await loadConnections()
        }
        .alert("Error", isPresented: .init(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            if let err = error {
                Text(err)
            }
        }
    }

    private func loadConnections() async {
        isLoading = true

        do {
            connections = try await appState.profileRepository.getConnectionsWithProfiles(profileId: profile.id)
        } catch {
            if !error.isCancellation {
                self.error = error.localizedDescription
            }
        }

        isLoading = false
    }
}

// MARK: - Connections Header View
struct ConnectionsHeaderView: View {
    let profile: Profile
    let onBack: () -> Void
    let onFamilyTree: (() -> Void)?

    init(profile: Profile, onBack: @escaping () -> Void, onFamilyTree: (() -> Void)? = nil) {
        self.profile = profile
        self.onBack = onBack
        self.onFamilyTree = onFamilyTree
    }

    var body: some View {
        HeaderImageView(
            imageName: "header-connections",
            title: profile.fullName,
            subtitle: "Connections",
            showBackButton: true,
            backAction: onBack,
            customActionIcon: onFamilyTree != nil ? "figure.2.and.child.holdinghands" : nil,
            customActionColor: .connectionsGreen,
            customAction: onFamilyTree
        )
    }
}

// MARK: - Connection Card
struct ConnectionCard: View {
    let profile: Profile
    let relationshipType: ConnectionType

    var body: some View {
        HStack(spacing: 16) {
            // Profile photo
            AsyncProfileImage(url: profile.photoUrl, size: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(profile.displayName)
                    .font(.appCardTitle)
                    .foregroundColor(.textPrimary)

                Text(relationshipType.displayName)
                    .font(.appCaption)
                    .foregroundColor(.connectionsGreen)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.textSecondary)
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Family Tree View
struct FamilyTreeView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    let rootProfile: Profile

    @State private var treeData: FamilyTreeNode?
    @State private var expandedNodes: Set<UUID> = []
    @State private var isLoading = false
    @State private var error: String?

    private let maxDepth = 3 // Limit recursion depth

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header at the top - fully interactive
                HeaderImageView(
                    imageName: "header-connections",
                    title: rootProfile.fullName,
                    subtitle: "Family Tree",
                    showBackButton: true,
                    backAction: { dismiss() }
                )

                // Content scrolls below header
                ScrollView {
                    VStack(spacing: AppDimensions.cardSpacing) {
                        // Section header
                        SectionHeaderCard(
                            title: "Family Tree",
                            icon: "figure.2.and.child.holdinghands",
                            backgroundColor: .connectionsGreen
                        )

                        if isLoading {
                            LoadingView(message: "Building family tree...")
                                .padding(.top, 40)
                        } else if let node = treeData {
                            // Root node with tree
                            FamilyTreeNodeView(
                                node: node,
                                depth: 0,
                                expandedNodes: $expandedNodes
                            )
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "figure.2.and.child.holdinghands")
                                    .font(.system(size: 48))
                                    .foregroundColor(.textSecondary)

                                Text("No connections to display")
                                    .font(.appCardTitle)
                                    .foregroundColor(.textPrimary)

                                Text("Add connections to see your family tree")
                                    .font(.appBody)
                                    .foregroundColor(.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        }

                        Spacer()
                            .frame(height: 100)
                    }
                    .padding(.horizontal, AppDimensions.screenPadding)
                    .padding(.top, AppDimensions.cardSpacing)
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            await loadFamilyTree()
        }
        .alert("Error", isPresented: .init(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            if let err = error {
                Text(err)
            }
        }
    }

    private func loadFamilyTree() async {
        isLoading = true

        do {
            // Start with root profile in the ancestor chain
            let ancestorChain = Set<UUID>([rootProfile.id])
            treeData = try await buildTreeNode(
                for: rootProfile,
                relationshipToParent: nil,
                depth: 0,
                ancestorChain: ancestorChain
            )
            // Expand root node by default
            expandedNodes.insert(rootProfile.id)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func buildTreeNode(
        for profile: Profile,
        relationshipToParent: ConnectionType?,
        depth: Int,
        ancestorChain: Set<UUID>
    ) async throws -> FamilyTreeNode {
        var children: [FamilyTreeNode] = []

        // Only fetch children if we haven't reached max depth
        if depth < maxDepth {
            let connections = try await appState.profileRepository.getConnectionsWithProfiles(profileId: profile.id)

            for connection in connections {
                // Skip if this person is already in the ancestor chain (prevents cycles within a branch)
                if ancestorChain.contains(connection.connectedProfile.id) {
                    continue
                }

                // Create new ancestor chain for this branch
                var childAncestorChain = ancestorChain
                childAncestorChain.insert(connection.connectedProfile.id)

                let childNode = try await buildTreeNode(
                    for: connection.connectedProfile,
                    relationshipToParent: connection.connection.relationshipType,
                    depth: depth + 1,
                    ancestorChain: childAncestorChain
                )
                children.append(childNode)
            }
        }

        return FamilyTreeNode(
            profile: profile,
            relationshipToParent: relationshipToParent,
            children: children,
            depth: depth
        )
    }
}

// MARK: - Family Tree Node Model
struct FamilyTreeNode: Identifiable {
    let profile: Profile
    let relationshipToParent: ConnectionType?
    let children: [FamilyTreeNode]
    let depth: Int

    var id: UUID { profile.id }
    var hasChildren: Bool { !children.isEmpty }
}

// MARK: - Family Tree Node View
struct FamilyTreeNodeView: View {
    let node: FamilyTreeNode
    let depth: Int
    @Binding var expandedNodes: Set<UUID>

    private var isExpanded: Bool {
        expandedNodes.contains(node.profile.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Node card
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        expandedNodes.remove(node.profile.id)
                    } else {
                        expandedNodes.insert(node.profile.id)
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    // Indentation lines
                    if depth > 0 {
                        HStack(spacing: 0) {
                            ForEach(0..<depth, id: \.self) { _ in
                                Rectangle()
                                    .fill(Color.connectionsGreen.opacity(0.3))
                                    .frame(width: 2)
                                    .padding(.horizontal, 8)
                            }
                        }
                        .frame(width: CGFloat(depth) * 20)
                    }

                    // Expand/collapse indicator
                    if node.hasChildren {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.connectionsGreen)
                            .frame(width: 16)
                    } else {
                        Circle()
                            .fill(Color.connectionsGreen.opacity(0.5))
                            .frame(width: 8, height: 8)
                            .frame(width: 16)
                    }

                    // Profile photo
                    AsyncProfileImage(url: node.profile.photoUrl, size: 44)

                    // Name and relationship
                    VStack(alignment: .leading, spacing: 2) {
                        Text(node.profile.displayName)
                            .font(.appCardTitle)
                            .foregroundColor(.textPrimary)

                        if let relationship = node.relationshipToParent {
                            Text(relationship.displayName)
                                .font(.appCaption)
                                .foregroundColor(.connectionsGreen)
                        } else if depth == 0 {
                            Text("Root")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)
                        }
                    }

                    Spacer()

                    // Connection count badge
                    if node.hasChildren {
                        Text("\(node.children.count)")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.cardBackground.opacity(0.5))
                            .cornerRadius(8)
                    }
                }
                .padding(AppDimensions.cardPadding)
                .background(depth == 0 ? Color.connectionsGreen.opacity(0.15) : Color.cardBackground)
                .cornerRadius(AppDimensions.cardCornerRadius)
            }
            .buttonStyle(PlainButtonStyle())

            // Children (expanded)
            if isExpanded && node.hasChildren {
                VStack(alignment: .leading, spacing: AppDimensions.cardSpacing) {
                    ForEach(node.children) { childNode in
                        FamilyTreeNodeView(
                            node: childNode,
                            depth: depth + 1,
                            expandedNodes: $expandedNodes
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, AppDimensions.cardSpacing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Add Connection View
struct AddConnectionView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    let profile: Profile
    let onSave: (ProfileConnection) -> Void

    @State private var allProfiles: [Profile] = []
    @State private var selectedProfile: Profile?
    @State private var selectedRelationship: ConnectionType?
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var error: String?
    @State private var step: AddConnectionStep = .selectProfile

    enum AddConnectionStep {
        case selectProfile
        case selectRelationship
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        if step == .selectProfile {
                            profileSelectionView
                        } else {
                            relationshipSelectionView
                        }
                    }
                    .padding(AppDimensions.screenPadding)
                }
            }
            .navigationTitle(step == .selectProfile ? "Select Person" : "Select Relationship")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if step == .selectRelationship {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            Task { await saveConnection() }
                        }
                        .foregroundColor(.accentYellow)
                        .disabled(selectedRelationship == nil || isSaving)
                    }
                }
            }
            .task {
                await loadProfiles()
            }
        }
    }

    // MARK: - Profile Selection View
    private var profileSelectionView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Who would you like to connect to \(profile.displayName)?")
                .font(.appBody)
                .foregroundColor(.textSecondary)

            if isLoading {
                LoadingView(message: "Loading profiles...")
            } else if allProfiles.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.slash")
                        .font(.system(size: 32))
                        .foregroundColor(.textSecondary)

                    Text("No other profiles available")
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(allProfiles) { availableProfile in
                        Button {
                            selectedProfile = availableProfile
                            step = .selectRelationship
                        } label: {
                            ProfileSelectionCard(profile: availableProfile)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }

    // MARK: - Relationship Selection View
    private var relationshipSelectionView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Back button
            Button {
                step = .selectProfile
                selectedRelationship = nil
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back to profiles")
                }
                .font(.appCaption)
                .foregroundColor(.accentYellow)
            }

            // Selected profile summary
            if let selected = selectedProfile {
                HStack(spacing: 12) {
                    AsyncProfileImage(url: selected.photoUrl, size: 48)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Connecting to")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)

                        Text(selected.displayName)
                            .font(.appCardTitle)
                            .foregroundColor(.textPrimary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.cardBackgroundSoft)
                .cornerRadius(AppDimensions.cardCornerRadius)
            }

            Text("What is \(selectedProfile?.displayName ?? "this person") to \(profile.displayName)?")
                .font(.appBody)
                .foregroundColor(.textSecondary)

            // Family relationships
            RelationshipSection(
                title: "Family",
                types: ConnectionType.familyTypes,
                selectedType: selectedRelationship
            ) { type in
                selectedRelationship = type
            }

            // Professional relationships
            RelationshipSection(
                title: "Professional",
                types: ConnectionType.professionalTypes,
                selectedType: selectedRelationship
            ) { type in
                selectedRelationship = type
            }

            // Social relationships
            RelationshipSection(
                title: "Social",
                types: ConnectionType.socialTypes,
                selectedType: selectedRelationship
            ) { type in
                selectedRelationship = type
            }

            // Other
            Button {
                selectedRelationship = .other
            } label: {
                Text("Other")
                    .font(.appCaption)
                    .foregroundColor(selectedRelationship == .other ? .black : .textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(selectedRelationship == .other ? Color.accentYellow : Color.cardBackgroundSoft)
                    .cornerRadius(20)
            }

            if let err = error {
                Text(err)
                    .font(.appCaption)
                    .foregroundColor(.medicalRed)
            }
        }
    }

    // MARK: - Load Profiles
    private func loadProfiles() async {
        guard let account = appState.currentAccount else { return }

        isLoading = true

        do {
            let profiles = try await appState.profileRepository.getProfiles(accountId: account.id)
            // Get existing connections to filter out
            let existingConnections = try await appState.profileRepository.getConnections(profileId: profile.id)
            let connectedIds = Set(existingConnections.map { $0.toProfileId })

            // Filter out the current profile and already-connected profiles
            allProfiles = profiles.filter { p in
                p.id != profile.id && !connectedIds.contains(p.id)
            }
        } catch {
            if !error.isCancellation {
                self.error = error.localizedDescription
            }
        }

        isLoading = false
    }

    // MARK: - Save Connection
    private func saveConnection() async {
        guard let account = appState.currentAccount,
              let targetProfile = selectedProfile,
              let relationship = selectedRelationship else { return }

        isSaving = true
        error = nil

        let insert = ProfileConnectionInsert(
            accountId: account.id,
            fromProfileId: profile.id,
            toProfileId: targetProfile.id,
            relationshipType: relationship
        )

        do {
            let connection = try await appState.profileRepository.createConnection(insert, bidirectional: true)
            onSave(connection)
            dismiss()
        } catch {
            self.error = "Failed to create connection. Please try again."
        }

        isSaving = false
    }
}

// MARK: - Profile Selection Card
struct ProfileSelectionCard: View {
    let profile: Profile

    var body: some View {
        HStack(spacing: 16) {
            AsyncProfileImage(url: profile.photoUrl, size: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName)
                    .font(.appCardTitle)
                    .foregroundColor(.textPrimary)

                if let relationship = profile.relationship {
                    Text(relationship)
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.textSecondary)
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Relationship Section
struct RelationshipSection: View {
    let title: String
    let types: [ConnectionType]
    let selectedType: ConnectionType?
    let onSelect: (ConnectionType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.appCaption)
                .foregroundColor(.textSecondary)

            FlowLayout(spacing: 8) {
                ForEach(types, id: \.self) { type in
                    Button {
                        onSelect(type)
                    } label: {
                        Text(type.displayName)
                            .font(.appCaption)
                            .foregroundColor(selectedType == type ? .black : .textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(selectedType == type ? Color.accentYellow : Color.cardBackgroundSoft)
                            .cornerRadius(20)
                    }
                }
            }
        }
    }
}

// MARK: - Relationship Field With Picker
struct RelationshipFieldWithPicker: View {
    @Binding var relationship: String
    @Binding var showPicker: Bool

    var body: some View {
        HStack(spacing: 8) {
            TextField("Relationship (e.g., Son, Daughter)", text: $relationship)
                .font(.appBody)
                .foregroundColor(.textPrimary)
                .padding()
                .frame(height: AppDimensions.textFieldHeight)
                .background(Color.cardBackgroundSoft)
                .cornerRadius(AppDimensions.buttonCornerRadius)

            Button {
                showPicker = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.black)
                    .frame(width: AppDimensions.textFieldHeight, height: AppDimensions.textFieldHeight)
                    .background(Color.accentYellow)
                    .cornerRadius(AppDimensions.buttonCornerRadius)
            }
        }
    }
}

// MARK: - Relationship Picker Sheet
struct RelationshipPickerSheet: View {
    @Binding var selectedRelationship: String
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Family relationships
                        VStack(alignment: .leading, spacing: 8) {
                            Text("FAMILY")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)

                            FlowLayout(spacing: 8) {
                                ForEach(ConnectionType.familyTypes, id: \.self) { type in
                                    Button {
                                        selectedRelationship = type.displayName
                                        isPresented = false
                                    } label: {
                                        Text(type.displayName)
                                            .font(.appCaption)
                                            .foregroundColor(selectedRelationship == type.displayName ? .black : .textPrimary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(selectedRelationship == type.displayName ? Color.accentYellow : Color.cardBackgroundSoft)
                                            .cornerRadius(20)
                                    }
                                }
                            }
                        }

                        // Professional relationships
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PROFESSIONAL")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)

                            FlowLayout(spacing: 8) {
                                ForEach(ConnectionType.professionalTypes, id: \.self) { type in
                                    Button {
                                        selectedRelationship = type.displayName
                                        isPresented = false
                                    } label: {
                                        Text(type.displayName)
                                            .font(.appCaption)
                                            .foregroundColor(selectedRelationship == type.displayName ? .black : .textPrimary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(selectedRelationship == type.displayName ? Color.accentYellow : Color.cardBackgroundSoft)
                                            .cornerRadius(20)
                                    }
                                }
                            }
                        }

                        // Social relationships
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SOCIAL")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)

                            FlowLayout(spacing: 8) {
                                ForEach(ConnectionType.socialTypes, id: \.self) { type in
                                    Button {
                                        selectedRelationship = type.displayName
                                        isPresented = false
                                    } label: {
                                        Text(type.displayName)
                                            .font(.appCaption)
                                            .foregroundColor(selectedRelationship == type.displayName ? .black : .textPrimary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(selectedRelationship == type.displayName ? Color.accentYellow : Color.cardBackgroundSoft)
                                            .cornerRadius(20)
                                    }
                                }
                            }
                        }

                        // Other
                        VStack(alignment: .leading, spacing: 8) {
                            Text("OTHER")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)

                            Button {
                                selectedRelationship = "Other"
                                isPresented = false
                            } label: {
                                Text("Other")
                                    .font(.appCaption)
                                    .foregroundColor(selectedRelationship == "Other" ? .black : .textPrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(selectedRelationship == "Other" ? Color.accentYellow : Color.cardBackgroundSoft)
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(AppDimensions.screenPadding)
                }
            }
            .navigationTitle("Select Relationship")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Size Field With Picker
struct SizeFieldWithPicker: View {
    @Binding var size: String
    @Binding var showPicker: Bool

    var body: some View {
        HStack(spacing: 8) {
            TextField("Size (e.g., 42R, M, 10)", text: $size)
                .font(.appBody)
                .foregroundColor(.textPrimary)
                .padding()
                .frame(height: AppDimensions.textFieldHeight)
                .background(Color.cardBackgroundSoft)
                .cornerRadius(AppDimensions.buttonCornerRadius)

            Button {
                showPicker = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.black)
                    .frame(width: AppDimensions.textFieldHeight, height: AppDimensions.textFieldHeight)
                    .background(Color.accentYellow)
                    .cornerRadius(AppDimensions.buttonCornerRadius)
            }
        }
    }
}

// MARK: - Size Picker Sheet
struct SizePickerSheet: View {
    @Binding var selectedSize: String
    @Binding var isPresented: Bool

    private let letterSizes = ["XS", "S", "M", "L", "XL", "XXL", "XXXL"]
    private let numericSizes = ["6", "7", "8", "9", "10", "11", "12", "13", "14"]
    private let pantsSizes = ["28", "30", "32", "34", "36", "38", "40", "42", "44"]
    private let shoeSizes = ["6", "6.5", "7", "7.5", "8", "8.5", "9", "9.5", "10", "10.5", "11", "11.5", "12", "13"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Letter sizes
                        VStack(alignment: .leading, spacing: 8) {
                            Text("LETTER SIZES")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)

                            FlowLayout(spacing: 8) {
                                ForEach(letterSizes, id: \.self) { size in
                                    Button {
                                        selectedSize = size
                                        isPresented = false
                                    } label: {
                                        Text(size)
                                            .font(.appCaption)
                                            .foregroundColor(selectedSize == size ? .black : .textPrimary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(selectedSize == size ? Color.accentYellow : Color.cardBackgroundSoft)
                                            .cornerRadius(20)
                                    }
                                }
                            }
                        }

                        // Numeric sizes (shirts, dresses)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NUMERIC SIZES")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)

                            FlowLayout(spacing: 8) {
                                ForEach(numericSizes, id: \.self) { size in
                                    Button {
                                        selectedSize = size
                                        isPresented = false
                                    } label: {
                                        Text(size)
                                            .font(.appCaption)
                                            .foregroundColor(selectedSize == size ? .black : .textPrimary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(selectedSize == size ? Color.accentYellow : Color.cardBackgroundSoft)
                                            .cornerRadius(20)
                                    }
                                }
                            }
                        }

                        // Pants/Waist sizes
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PANTS / WAIST")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)

                            FlowLayout(spacing: 8) {
                                ForEach(pantsSizes, id: \.self) { size in
                                    Button {
                                        selectedSize = size
                                        isPresented = false
                                    } label: {
                                        Text(size)
                                            .font(.appCaption)
                                            .foregroundColor(selectedSize == size ? .black : .textPrimary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(selectedSize == size ? Color.accentYellow : Color.cardBackgroundSoft)
                                            .cornerRadius(20)
                                    }
                                }
                            }
                        }

                        // Shoe sizes
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SHOE SIZES")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)

                            FlowLayout(spacing: 8) {
                                ForEach(shoeSizes, id: \.self) { size in
                                    Button {
                                        selectedSize = size
                                        isPresented = false
                                    } label: {
                                        Text(size)
                                            .font(.appCaption)
                                            .foregroundColor(selectedSize == size ? .black : .textPrimary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(selectedSize == size ? Color.accentYellow : Color.cardBackgroundSoft)
                                            .cornerRadius(20)
                                    }
                                }
                            }
                        }
                    }
                    .padding(AppDimensions.screenPadding)
                }
            }
            .navigationTitle("Select Size")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Preview
#Preview {
    ProfileCategoryListView(
        profile: Profile(
            id: UUID(),
            accountId: UUID(),
            type: .relative,
            fullName: "Michael Annetta",
            preferredName: nil,
            relationship: "Son",
            birthday: nil,
            address: nil,
            phone: nil,
            email: nil,
            notes: nil,
            isFavourite: false,
            linkedUserId: nil,
            photoUrl: nil,
            createdAt: Date(),
            updatedAt: Date()
        ),
        category: .clothing,
        details: []
    )
    .environmentObject(AppState())
}
