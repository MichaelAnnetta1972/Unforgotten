import SwiftUI

// MARK: - Category Type
enum ProfileCategoryType: Identifiable {
    case clothing
    case gifts
    case medical
    case hobbies
    case activities

    var id: String {
        switch self {
        case .clothing: return "clothing"
        case .gifts: return "gifts"
        case .medical: return "medical"
        case .hobbies: return "hobbies"
        case .activities: return "activities"
        }
    }

    var title: String {
        switch self {
        case .clothing: return "Clothing Sizes"
        case .gifts: return "Gift Ideas"
        case .medical: return "Medical Conditions"
        case .hobbies: return "Hobbies & Interests"
        case .activities: return "Activity Ideas"
        }
    }

    var icon: String {
        switch self {
        case .clothing: return "tshirt.fill"
        case .gifts: return "gift.fill"
        case .medical: return "cross.fill"
        case .hobbies: return "heart.circle.fill"
        case .activities: return "figure.walk"
        }
    }

    var color: Color {
        switch self {
        case .clothing: return .clothingBlue
        case .gifts: return .giftPurple
        case .medical: return .medicalRed
        case .hobbies: return .hobbyOrange
        case .activities: return .activityGreen
        }
    }

    /// Convert to DetailCategory for repository queries
    var detailCategory: DetailCategory {
        switch self {
        case .clothing: return .clothing
        case .gifts: return .giftIdea
        case .medical: return .medicalCondition
        case .hobbies: return .hobby
        case .activities: return .activityIdea
        }
    }

    /// Whether this category uses section-based organization
    var usesSections: Bool {
        switch self {
        case .hobbies, .activities: return true
        default: return false
        }
    }
}

// MARK: - Profile Category List View
struct ProfileCategoryListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.navigateToRoot) var navigateToRoot
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.iPadAddMedicalConditionAction) private var iPadAddMedicalConditionAction
    @Environment(\.iPadAddGiftIdeaAction) private var iPadAddGiftIdeaAction
    @Environment(\.iPadEditGiftIdeaAction) private var iPadEditGiftIdeaAction
    @Environment(\.iPadAddClothingSizeAction) private var iPadAddClothingSizeAction
    @Environment(\.iPadEditClothingSizeAction) private var iPadEditClothingSizeAction

    let profile: Profile
    let category: ProfileCategoryType
    let details: [ProfileDetail]

    @State private var showAddDetail = false
    @State private var showSettings = false
    @State private var currentDetails: [ProfileDetail]
    @State private var editingDetail: ProfileDetail?
    @State private var showEditClothing = false
    @State private var showEditGift = false

    /// Whether to use side panel presentation (iPad full-screen)
    private var useSidePanel: Bool {
        horizontalSizeClass == .regular
    }

    init(profile: Profile, category: ProfileCategoryType, details: [ProfileDetail]) {
        self.profile = profile
        self.category = category
        self.details = details
        self._currentDetails = State(initialValue: details)
    }

    private var emptyStateTitle: String {
        switch category {
        case .clothing:
            return "No clothing sizes yet"
        case .gifts:
            return "No gift ideas yet"
        case .medical:
            return "No medical conditions yet"
        case .hobbies:
            return "No hobbies yet"
        case .activities:
            return "No activity ideas yet"
        }
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header scrolls with content
                    CategoryHeaderView(
                        profile: profile,
                        category: category,
                        onBack: { dismiss() },
                        onAdd: {
                            // Use full-screen overlay action if available based on category
                            switch category {
                            case .medical:
                                if let addAction = iPadAddMedicalConditionAction {
                                    addAction(profile)
                                } else {
                                    showAddDetail = true
                                }
                            case .gifts:
                                if let addAction = iPadAddGiftIdeaAction {
                                    addAction(profile)
                                } else {
                                    showAddDetail = true
                                }
                            case .clothing:
                                if let addAction = iPadAddClothingSizeAction {
                                    addAction(profile)
                                } else {
                                    showAddDetail = true
                                }
                            case .hobbies, .activities:
                                // Hobbies and activities use SectionBasedCategoryView, not this view
                                break
                            }
                        }
                    )

                    // Content
                    VStack(spacing: AppDimensions.cardSpacing) {
                        // Section header card
                        //SectionHeaderCard(
                        //    title: category.title,
                        //    icon: category.icon
                        //)

                        // Details list
                        VStack(spacing: AppDimensions.cardSpacing) {
                            ForEach(currentDetails) { detail in
                                switch category {
                                case .clothing:
                                    ClothingCardWithOverlay(
                                        detail: detail,
                                        onEdit: {
                                            // Use iPad full-screen overlay if available
                                            if let iPadAction = iPadEditClothingSizeAction {
                                                iPadAction(detail)
                                            } else {
                                                editingDetail = detail
                                                showEditClothing = true
                                            }
                                        },
                                        onDelete: {
                                            Task {
                                                await deleteDetail(detail: detail)
                                            }
                                        }
                                    )

                                case .gifts:
                                    GiftCardWithOverlay(
                                        detail: detail,
                                        status: giftStatus(from: detail.status),
                                        isActive: false,
                                        onStatusChange: { newStatus in
                                            Task {
                                                await updateGiftStatus(detail: detail, newStatus: newStatus)
                                            }
                                        },
                                        onEdit: {
                                            // Use iPad full-screen action if available
                                            if let editAction = iPadEditGiftIdeaAction {
                                                editAction(detail)
                                            } else {
                                                editingDetail = detail
                                                showEditGift = true
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
                                        condition: detail.value.isEmpty ? detail.label : detail.value,
                                        onDelete: {
                                            Task {
                                                await deleteDetail(detail: detail)
                                            }
                                        }
                                    )

                                case .hobbies, .activities:
                                    // Hobbies and activities use SectionBasedCategoryView, not this view
                                    EmptyView()
                                }
                            }
                        }

                        // Empty state
                        if currentDetails.isEmpty {
                            VStack(spacing: 12) {
                                Text(emptyStateTitle)
                                    .font(.appCardTitle)
                                    .foregroundColor(.textPrimary)

                                Text("Tap + to add the first one")
                                    .font(.appBody)
                                    .foregroundColor(.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        }

                        // Bottom spacing for nav bar
                        Spacer()
                            .frame(height: 120)
                    }
                    .padding(.horizontal, AppDimensions.screenPadding(for: horizontalSizeClass))
                    .padding(.top, AppDimensions.cardSpacing)
                }
            }

            // Local overlay for editing clothing on iPhone (iPad uses full-screen overlay via iPadEditClothingSizeAction)
            if iPadEditClothingSizeAction == nil, showEditClothing, let detail = editingDetail {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showEditClothing = false
                                editingDetail = nil
                            }
                        }

                    EditClothingPanelOverlay(
                        detail: detail,
                        onDismiss: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showEditClothing = false
                                editingDetail = nil
                            }
                        },
                        onSave: { updatedDetail in
                            if let index = currentDetails.firstIndex(where: { $0.id == updatedDetail.id }) {
                                currentDetails[index] = updatedDetail
                            }
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showEditClothing = false
                                editingDetail = nil
                            }
                        }
                    )
                }
                .zIndex(200)
                .transition(.opacity)
            }

            // Local overlay for editing gift on iPhone
            if showEditGift, let detail = editingDetail {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showEditGift = false
                                editingDetail = nil
                            }
                        }

                    EditGiftPanelOverlay(
                        detail: detail,
                        onDismiss: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showEditGift = false
                                editingDetail = nil
                            }
                        },
                        onSave: { updatedDetail in
                            if let index = currentDetails.firstIndex(where: { $0.id == updatedDetail.id }) {
                                currentDetails[index] = updatedDetail
                            }
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showEditGift = false
                                editingDetail = nil
                            }
                        }
                    )
                }
                .zIndex(200)
                .transition(.opacity)
            }

        }
        .ignoresSafeArea(edges: .top)
        .background(Color.appBackgroundLight)
        .navigationBarHidden(true)
        .sidePanel(isPresented: $showSettings) {
            SettingsPanelView(onDismiss: { showSettings = false })
        }
        .sidePanel(isPresented: $showAddDetail) {
            AddProfileDetailView(
                profile: profile,
                category: category,
                onDismiss: { showAddDetail = false }
            ) { newDetail in
                currentDetails.append(newDetail)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileDetailsDidChange)) { notification in
            // Reload details when they change (e.g., from iPad full-screen overlay)
            if let profileId = notification.userInfo?["profileId"] as? UUID, profileId == profile.id {
                Task {
                    await reloadDetails()
                }
            }
        }
    }

    private func reloadDetails() async {
        do {
            let details = try await appState.profileRepository.getProfileDetails(
                profileId: profile.id,
                category: category.detailCategory
            )
            currentDetails = details
        } catch {
            #if DEBUG
            print("Failed to reload details: \(error)")
            #endif
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
            NotificationCenter.default.post(name: .profileDetailsDidChange, object: nil, userInfo: ["profileId": profile.id])
        } catch {
            #if DEBUG
            print("Failed to update gift status: \(error)")
            #endif
        }
    }

    private func deleteDetail(detail: ProfileDetail) async {
        do {
            try await appState.profileRepository.deleteProfileDetail(id: detail.id)
            currentDetails.removeAll { $0.id == detail.id }
            NotificationCenter.default.post(name: .profileDetailsDidChange, object: nil, userInfo: ["profileId": profile.id])
        } catch {
            #if DEBUG
            print("Failed to delete detail: \(error)")
            #endif
        }
    }
}

// MARK: - Category Header View
struct CategoryHeaderView: View {
    let profile: Profile
    let category: ProfileCategoryType
    let onBack: () -> Void
    let onAdd: (() -> Void)?

    init(profile: Profile, category: ProfileCategoryType, onBack: @escaping () -> Void, onAdd: (() -> Void)? = nil) {
        self.profile = profile
        self.category = category
        self.onBack = onBack
        self.onAdd = onAdd
    }

    var body: some View {
        CustomizableHeaderView(
            pageIdentifier: .profileDetail,
            title: profile.fullName,
            subtitle: category.title,
            showBackButton: true,
            backAction: onBack,
            showAddButton: onAdd != nil,
            addAction: onAdd
        )
    }
}

// MARK: - Add Profile Detail View
struct AddProfileDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.appAccentColor) private var appAccentColor

    let profile: Profile
    let category: ProfileCategoryType
    var onDismiss: (() -> Void)? = nil
    let onSave: (ProfileDetail) -> Void

    @State private var label = ""
    @State private var value = ""
    @State private var status = "idea"
    @State private var favouriteBrands = ""
    @State private var websiteUrl = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSizePicker = false

    // Preset options for clothing
    private let clothingTypes = ["Jacket", "Pants", "Shoes", "T-Shirt", "Dress Shirt", "Belt", "Hat", "Gloves", "Socks", "Underwear", "Other"]

    private func dismissView() {
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom header with icons
                HStack {
                    Button {
                        dismissView()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.5))
                            )
                    }

                    Spacer()

                    Text("Add \(category.title)")
                        .font(.headline)
                        .foregroundColor(.textPrimary)

                    Spacer()

                    Button {
                        Task { await saveDetail() }
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 48, height: 48)
                            .background(
                                Circle()
                                    .fill(label.isBlank || isLoading ? Color.gray.opacity(0.3) : appAccentColor)
                            )
                    }
                    .disabled(label.isBlank || isLoading)
                }
                .padding(.horizontal, AppDimensions.screenPadding)
                .padding(.vertical, 16)
                .background(Color.appBackground)

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
                            case .hobbies, .activities:
                                // Hobbies and activities use SectionBasedCategoryView
                                EmptyView()
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
            }
            .background(Color.appBackground)
            .navigationBarHidden(true)
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
                                .background(label == type ? appAccentColor : Color.cardBackgroundSoft)
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

            // Status picker in a row container
            HStack {
                Text("Status")
                    .font(.appBody)
                    .foregroundColor(.textSecondary)

                Spacer()

                HStack(spacing: 6) {
                    StatusButtonCompact(title: "Idea", isSelected: status == "idea") {
                        status = "idea"
                    }
                    StatusButtonCompact(title: "Bought", isSelected: status == "bought") {
                        status = "bought"
                    }
                    StatusButtonCompact(title: "Given", isSelected: status == "given") {
                        status = "given"
                    }
                }
            }
            .padding()
            .frame(height: AppDimensions.textFieldHeight)
            .background(Color.cardBackgroundSoft)
            .cornerRadius(AppDimensions.buttonCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                    .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
            )

            // Favourite brands field
            AppTextField(placeholder: "Favourite brands", text: $favouriteBrands)

            // Website URL field with open button
            HStack(spacing: 12) {
                AppTextField(placeholder: "Website URL", text: $websiteUrl)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)

                Button {
                    openWebsite()
                } label: {
                    Image(systemName: "safari")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(websiteUrl.isBlank ? .textSecondary : appAccentColor)
                        .frame(width: 48, height: 48)
                        .background(Color.cardBackgroundSoft)
                        .cornerRadius(AppDimensions.buttonCornerRadius)
                }
                .disabled(websiteUrl.isBlank)
            }
        }
    }

    private func openWebsite() {
        var urlString = websiteUrl.trimmingCharacters(in: .whitespaces)

        // Add https:// if no scheme is present
        if !urlString.lowercased().hasPrefix("http://") && !urlString.lowercased().hasPrefix("https://") {
            urlString = "https://" + urlString
        }

        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
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
                                .background(label == item ? appAccentColor : Color.cardBackgroundSoft)
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
        case .hobbies:
            detailCategory = .hobby
        case .activities:
            detailCategory = .activityIdea
        }

        // Build metadata for gifts
        var metadata: [String: String]? = nil
        if category == .gifts {
            var giftMetadata: [String: String] = [:]
            if !favouriteBrands.isBlank {
                giftMetadata["favourite_brands"] = favouriteBrands.trimmingCharacters(in: .whitespaces)
            }
            if !websiteUrl.isBlank {
                giftMetadata["website_url"] = websiteUrl.trimmingCharacters(in: .whitespaces)
            }
            if !giftMetadata.isEmpty {
                metadata = giftMetadata
            }
        }

        let insert = ProfileDetailInsert(
            accountId: account.id,
            profileId: profile.id,
            category: detailCategory,
            label: label,
            value: category == .clothing ? value : label,
            status: category == .gifts ? status : nil,
            metadata: metadata
        )

        do {
            let newDetail = try await appState.profileRepository.createProfileDetail(insert)
            onSave(newDetail)
            // Post notification so ProfileDetailView can reload its data
            NotificationCenter.default.post(name: .profileDetailsDidChange, object: nil, userInfo: ["profileId": profile.id])
            dismissView()
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
    @Environment(\.sidePanelDismiss) var sidePanelDismiss
    @Environment(\.appAccentColor) private var appAccentColor

    let detail: ProfileDetail
    var onDismiss: (() -> Void)? = nil
    let onSave: (ProfileDetail) -> Void

    @State private var label: String
    @State private var value: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSizePicker = false

    private let clothingTypes = ["Jacket", "Pants", "Shoes", "T-Shirt", "Dress Shirt", "Belt", "Hat", "Gloves", "Socks", "Underwear", "Other"]

    init(detail: ProfileDetail, onDismiss: (() -> Void)? = nil, onSave: @escaping (ProfileDetail) -> Void) {
        self.detail = detail
        self.onDismiss = onDismiss
        self.onSave = onSave
        self._label = State(initialValue: detail.label)
        self._value = State(initialValue: detail.value)
    }

    private func dismissView() {
        if let onDismiss = onDismiss {
            onDismiss()
        } else if let sidePanelDismiss = sidePanelDismiss {
            sidePanelDismiss()
        } else {
            dismiss()
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom header with icons
                HStack {
                    Button {
                        dismissView()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.5))
                            )
                    }

                    Spacer()

                    Text("Edit Clothing")
                        .font(.headline)
                        .foregroundColor(.textPrimary)

                    Spacer()

                    Button {
                        Task { await saveChanges() }
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 48, height: 48)
                            .background(
                                Circle()
                                    .fill(label.isBlank || isLoading ? Color.gray.opacity(0.3) : appAccentColor)
                            )
                    }
                    .disabled(label.isBlank || isLoading)
                }
                .padding(.horizontal, AppDimensions.screenPadding)
                .padding(.vertical, 16)
                .background(Color.appBackground)

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
                                                .background(label == type ? appAccentColor : Color.cardBackgroundSoft)
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
            }
            .background(Color.appBackground)
            .navigationBarHidden(true)
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
            NotificationCenter.default.post(name: .profileDetailsDidChange, object: nil, userInfo: ["profileId": detail.profileId])
            dismissView()
        } catch {
            errorMessage = "Failed to save. Please try again."
        }

        isLoading = false
    }
}

// MARK: - Edit Clothing Panel Overlay (Full-screen for iPad)
struct EditClothingPanelOverlay: View {
    let detail: ProfileDetail
    let onDismiss: () -> Void
    let onSave: (ProfileDetail) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var offsetX: CGFloat = 680
    @State private var opacity: Double = 0

    /// Panel width - wider on iPad
    private var panelWidth: CGFloat {
        horizontalSizeClass == .regular ? 550 : 350
    }

    /// Panel height
    private var panelHeight: CGFloat {
        horizontalSizeClass == .regular ? 600 : 500
    }

    var body: some View {
        GeometryReader { geometry in
            HStack {
                Spacer()

                EditClothingDetailView(
                    detail: detail,
                    onDismiss: onDismiss,
                    onSave: onSave
                )
                .frame(width: panelWidth, height: min(panelHeight, geometry.size.height - 80))
                .background(Color.appBackgroundLight)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 20, x: -5, y: 0)
                .offset(x: offsetX)
                .opacity(opacity)
                .padding(.top, 40)
                .padding(.trailing, 20)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                offsetX = 0
                opacity = 1.0
            }
        }
    }
}

// MARK: - Edit Gift Detail View
struct EditGiftDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.sidePanelDismiss) var sidePanelDismiss
    @Environment(\.appAccentColor) private var appAccentColor

    let detail: ProfileDetail
    var onDismiss: (() -> Void)? = nil
    let onSave: (ProfileDetail) -> Void

    @State private var label: String
    @State private var status: String
    @State private var favouriteBrands: String
    @State private var websiteUrl: String
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(detail: ProfileDetail, onDismiss: (() -> Void)? = nil, onSave: @escaping (ProfileDetail) -> Void) {
        self.detail = detail
        self.onDismiss = onDismiss
        self.onSave = onSave
        self._label = State(initialValue: detail.label)
        self._status = State(initialValue: detail.status ?? "idea")
        self._favouriteBrands = State(initialValue: detail.metadata?["favourite_brands"] ?? "")
        self._websiteUrl = State(initialValue: detail.metadata?["website_url"] ?? "")
    }

    private func dismissView() {
        if let onDismiss = onDismiss {
            onDismiss()
        } else if let sidePanelDismiss = sidePanelDismiss {
            sidePanelDismiss()
        } else {
            dismiss()
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom header with icons
                HStack {
                    Button {
                        dismissView()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.5))
                            )
                    }

                    Spacer()

                    Text("Edit Gift Idea")
                        .font(.headline)
                        .foregroundColor(.textPrimary)

                    Spacer()

                    Button {
                        Task { await saveChanges() }
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 48, height: 48)
                            .background(
                                Circle()
                                    .fill(label.isBlank || isLoading ? Color.gray.opacity(0.3) : appAccentColor)
                            )
                    }
                    .disabled(label.isBlank || isLoading)
                }
                .padding(.horizontal, AppDimensions.screenPadding)
                .padding(.vertical, 16)
                .background(Color.appBackground)

                ZStack {
                    Color.appBackground.ignoresSafeArea()

                    ScrollView {
                        VStack(spacing: 16) {
                            AppTextField(placeholder: "Gift idea", text: $label)

                            // Status picker in a row container
                            HStack {
                                Text("Status")
                                    .font(.appBody)
                                    .foregroundColor(.textSecondary)

                                Spacer()

                                HStack(spacing: 6) {
                                    StatusButtonCompact(title: "Idea", isSelected: status == "idea") {
                                        status = "idea"
                                    }
                                    StatusButtonCompact(title: "Bought", isSelected: status == "bought") {
                                        status = "bought"
                                    }
                                    StatusButtonCompact(title: "Given", isSelected: status == "given") {
                                        status = "given"
                                    }
                                }
                            }
                            .padding()
                            .frame(height: AppDimensions.textFieldHeight)
                            .background(Color.cardBackgroundSoft)
                            .cornerRadius(AppDimensions.buttonCornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                                    .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
                            )

                            // Favourite brands field
                            AppTextField(placeholder: "Favourite brands", text: $favouriteBrands)

                            // Website URL field with open button
                            HStack(spacing: 12) {
                                AppTextField(placeholder: "Website URL", text: $websiteUrl)
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.URL)

                                Button {
                                    openWebsite()
                                } label: {
                                    Image(systemName: "safari")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(websiteUrl.isBlank ? .textSecondary : appAccentColor)
                                        .frame(width: 48, height: 48)
                                        .background(Color.cardBackgroundSoft)
                                        .cornerRadius(AppDimensions.buttonCornerRadius)
                                }
                                .disabled(websiteUrl.isBlank)
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
            }
            .background(Color.appBackground)
            .navigationBarHidden(true)
        }
    }

    private func openWebsite() {
        var urlString = websiteUrl.trimmingCharacters(in: .whitespaces)

        // Add https:// if no scheme is present
        if !urlString.lowercased().hasPrefix("http://") && !urlString.lowercased().hasPrefix("https://") {
            urlString = "https://" + urlString
        }

        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }

    private func saveChanges() async {
        guard !label.isBlank else {
            errorMessage = "Please enter a gift idea"
            return
        }

        isLoading = true
        errorMessage = nil

        var updatedDetail = detail
        updatedDetail.label = label
        updatedDetail.value = label
        updatedDetail.status = status

        // Build metadata dictionary
        var metadata: [String: String] = updatedDetail.metadata ?? [:]
        if !favouriteBrands.isBlank {
            metadata["favourite_brands"] = favouriteBrands.trimmingCharacters(in: .whitespaces)
        } else {
            metadata.removeValue(forKey: "favourite_brands")
        }
        if !websiteUrl.isBlank {
            metadata["website_url"] = websiteUrl.trimmingCharacters(in: .whitespaces)
        } else {
            metadata.removeValue(forKey: "website_url")
        }
        updatedDetail.metadata = metadata.isEmpty ? nil : metadata

        do {
            let saved = try await appState.profileRepository.updateProfileDetail(updatedDetail)
            onSave(saved)
            NotificationCenter.default.post(name: .profileDetailsDidChange, object: nil, userInfo: ["profileId": detail.profileId])
            dismissView()
        } catch {
            errorMessage = "Failed to save. Please try again."
        }

        isLoading = false
    }
}

// MARK: - Edit Gift Panel Overlay (Full-screen for iPad)
struct EditGiftPanelOverlay: View {
    let detail: ProfileDetail
    let onDismiss: () -> Void
    let onSave: (ProfileDetail) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var offsetX: CGFloat = 680
    @State private var opacity: Double = 0

    /// Panel width - wider on iPad
    private var panelWidth: CGFloat {
        horizontalSizeClass == .regular ? 550 : 350
    }

    var body: some View {
        GeometryReader { geometry in
            HStack {
                Spacer()

                EditGiftDetailView(
                    detail: detail,
                    onDismiss: onDismiss,
                    onSave: onSave
                )
                .frame(width: panelWidth, height: geometry.size.height - 80)
                .background(Color.appBackgroundLight)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 20, x: -5, y: 0)
                .offset(x: offsetX)
                .opacity(opacity)
                .padding(.top, 40)
                .padding(.trailing, 20)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                offsetX = 0
                opacity = 1.0
            }
        }
    }
}

// MARK: - Status Button
struct StatusButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.appCaption)
                .foregroundColor(isSelected ? .black : .textPrimary)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(isSelected ? appAccentColor : Color.cardBackgroundSoft)
                .cornerRadius(AppDimensions.buttonCornerRadius)
        }
    }
}

// MARK: - Status Button Compact (for Edit Gift modal)
struct StatusButtonCompact: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.appCaption)
                .foregroundColor(isSelected ? .black : .textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? appAccentColor : Color.appBackground)
                .cornerRadius(AppDimensions.pillCornerRadius)
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
        case .hobby: return "heart.circle.fill"
        case .activityIdea: return "figure.walk"
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
        case .hobby: return .hobbyOrange
        case .activityIdea: return .activityGreen
        }
    }
}

// MARK: - Add Profile View
struct AddProfileView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.appAccentColor) private var appAccentColor

    var onDismiss: (() -> Void)? = nil
    let onSave: (Profile) -> Void

    private func dismissView() {
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }

    @State private var fullName = ""
    @State private var preferredName = ""
    @State private var relationship = ""
    @State private var connectedToProfileId: UUID? = nil
    @State private var includeInFamilyTree = true
    @State private var phone = ""
    @State private var email = ""
    @State private var address = ""
    @State private var birthday: Date? = nil
    @State private var isDeceased = false
    @State private var dateOfDeath: Date? = nil
    @State private var showDatePicker = false
    @State private var showDeathDatePicker = false
    @State private var showRelationshipPicker = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var allProfiles: [Profile] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom header with icons
                HStack {
                    Button {
                        dismissView()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.5))
                            )
                    }

                    Spacer()

                    Text("Add Person")
                        .font(.headline)
                        .foregroundColor(.textPrimary)

                    Spacer()

                    Button {
                        Task { await saveProfile() }
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 48, height: 48)
                            .background(
                                Circle()
                                    .fill(fullName.isBlank || isLoading ? Color.gray.opacity(0.3) : appAccentColor)
                            )
                    }
                    .disabled(fullName.isBlank || isLoading)
                }
                .padding(.horizontal, AppDimensions.screenPadding)
                .padding(.vertical, 16)

                ScrollView {
                    VStack(spacing: 20) {

                        AppTextField(placeholder: "Full Name *", text: $fullName)
                        AppTextField(placeholder: "Preferred Name (optional)", text: $preferredName)

                        // Relationship field with quick-add button
                        RelationshipFieldWithPicker(
                            relationship: $relationship,
                            showPicker: $showRelationshipPicker
                        )

                        // Connected To picker for family tree
                        if !allProfiles.isEmpty {
                            ConnectedToPickerField(
                                selectedProfileId: $connectedToProfileId,
                                profiles: allProfiles,
                                currentProfileId: nil  // New profile has no ID yet
                            )
                        }

                        // Include in Family Tree toggle
                        HStack {
                            Text("Include in Family Tree")
                                .font(.appBody)
                                .foregroundColor(.textPrimary)

                            Spacer()

                            Toggle("", isOn: $includeInFamilyTree)
                                .tint(appAccentColor)
                                .labelsHidden()
                        }
                        .padding()
                        .background(Color.cardBackgroundSoft)
                        .cornerRadius(AppDimensions.buttonCornerRadius)

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

                        // MARK: - Memorial Status Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Memorial Status")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)
                                .padding(.horizontal, 4)

                            // Deceased toggle
                            HStack {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.textSecondary)
                                    .frame(width: 24)

                                Text("Person has passed away")
                                    .font(.appBody)
                                    .foregroundColor(.textPrimary)

                                Spacer()

                                Toggle("", isOn: $isDeceased)
                                    .tint(appAccentColor)
                                    .labelsHidden()
                            }
                            .padding()
                            .background(Color.cardBackgroundSoft)
                            .cornerRadius(AppDimensions.buttonCornerRadius)

                            // Date of death picker (only shown when deceased is true)
                            if isDeceased {
                                Button {
                                    showDeathDatePicker = true
                                } label: {
                                    HStack {
                                        Image(systemName: "calendar")
                                            .foregroundColor(.textSecondary)
                                            .frame(width: 24)

                                        Text(dateOfDeath != nil ? dateOfDeath!.formatted(date: .long, time: .omitted) : "Date of Death (optional)")
                                            .foregroundColor(dateOfDeath != nil ? .textPrimary : .textSecondary)

                                        Spacer()

                                        if dateOfDeath != nil {
                                            Button {
                                                dateOfDeath = nil
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.textSecondary)
                                            }
                                        }
                                    }
                                    .padding()
                                    .frame(height: AppDimensions.textFieldHeight)
                                    .background(Color.cardBackgroundSoft)
                                    .cornerRadius(AppDimensions.buttonCornerRadius)
                                }
                            }
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
            .background(Color.clear)
            .navigationBarHidden(true)
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(selectedDate: $birthday, isPresented: $showDatePicker)
            }
            .sheet(isPresented: $showDeathDatePicker) {
                DatePickerSheet(selectedDate: $dateOfDeath, isPresented: $showDeathDatePicker, title: "Date of Death")
            }
            .sheet(isPresented: $showRelationshipPicker) {
                RelationshipPickerSheet(selectedRelationship: $relationship, isPresented: $showRelationshipPicker)
            }
            .task {
                await loadProfiles()
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .toolbarBackground(.clear, for: .navigationBar)
        .containerBackground(.clear, for: .navigation)
    }

    private func loadProfiles() async {
        guard let accountId = appState.currentAccount?.id else { return }
        do {
            allProfiles = try await appState.profileRepository.getProfiles(accountId: accountId)
        } catch {
            #if DEBUG
            print("Failed to load profiles: \(error)")
            #endif
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
            connectedToProfileId: connectedToProfileId,
            includeInFamilyTree: includeInFamilyTree,
            birthday: birthday,
            isDeceased: isDeceased,
            dateOfDeath: isDeceased ? dateOfDeath : nil,
            address: address.isBlank ? nil : address,
            phone: phone.isBlank ? nil : phone,
            email: email.isBlank ? nil : email
        )

        do {
            let newProfile = try await appState.profileRepository.createProfile(insert)

            // Schedule birthday reminder if birthday was set (skip for deceased profiles)
            if newProfile.birthday != nil && !newProfile.isDeceased {
                await appState.scheduleBirthdayReminder(for: newProfile)
            }

            onSave(newProfile)
            dismiss()
        } catch {
            #if DEBUG
            print("❌ Profile creation error: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            #endif
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }

        isLoading = false
    }
}

// MARK: - Edit Profile View
struct EditProfileView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.appAccentColor) private var appAccentColor

    let profile: Profile
    let onSave: (Profile) -> Void
    var onDismiss: (() -> Void)?

    @State private var fullName: String
    @State private var preferredName: String
    @State private var relationship: String
    @State private var connectedToProfileId: UUID?
    @State private var includeInFamilyTree: Bool
    @State private var phone: String
    @State private var email: String
    @State private var address: String
    @State private var birthday: Date?
    @State private var isDeceased: Bool
    @State private var dateOfDeath: Date?
    @State private var selectedImage: UIImage?
    @State private var showDatePicker = false
    @State private var showDeathDatePicker = false
    @State private var showRelationshipPicker = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showAddCustomField = false
    @State private var customFields: [ProfileDetail] = []
    @State private var allProfiles: [Profile] = []

    init(profile: Profile, onDismiss: (() -> Void)? = nil, onSave: @escaping (Profile) -> Void) {
        self.profile = profile
        self.onDismiss = onDismiss
        self.onSave = onSave
        self._fullName = State(initialValue: profile.fullName)
        self._preferredName = State(initialValue: profile.preferredName ?? "")
        self._relationship = State(initialValue: profile.relationship ?? "")
        self._connectedToProfileId = State(initialValue: profile.connectedToProfileId)
        self._includeInFamilyTree = State(initialValue: profile.includeInFamilyTree)
        self._phone = State(initialValue: profile.phone ?? "")
        self._email = State(initialValue: profile.email ?? "")
        self._address = State(initialValue: profile.address ?? "")
        self._birthday = State(initialValue: profile.birthday)
        self._isDeceased = State(initialValue: profile.isDeceased)
        self._dateOfDeath = State(initialValue: profile.dateOfDeath)
    }

    /// Dismisses the view using the onDismiss callback if provided, otherwise uses the environment dismiss
    private func dismissView() {
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom header with icons
            HStack {
                Button {
                    dismissView()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.5))
                        )
                }

                Spacer()

                Text("Edit Profile")
                    .font(.headline)
                    .foregroundColor(.textPrimary)

                Spacer()

                Button {
                    Task { await updateProfile() }
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(fullName.isBlank || isLoading ? Color.gray.opacity(0.3) : appAccentColor)
                        )
                }
                .disabled(fullName.isBlank || isLoading)
            }
            .padding(.horizontal, AppDimensions.screenPadding)
            .padding(.vertical, 16)
            .background(Color.appBackgroundLight)

            ZStack {
                Color.appBackgroundLight

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

                            // Connected To picker for family tree
                            if !allProfiles.isEmpty {
                                ConnectedToPickerField(
                                    selectedProfileId: $connectedToProfileId,
                                    profiles: allProfiles,
                                    currentProfileId: profile.id
                                )
                            }

                            // Include in Family Tree toggle
                            HStack {
                                Text("Include in Family Tree")
                                    .font(.appBody)
                                    .foregroundColor(.textPrimary)

                                Spacer()

                                Toggle("", isOn: $includeInFamilyTree)
                                    .tint(appAccentColor)
                                    .labelsHidden()
                            }
                            .padding()
                            .background(Color.cardBackgroundSoft)
                            .cornerRadius(AppDimensions.buttonCornerRadius)

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

                            // Deceased Section (only show for non-primary profiles)
                            if profile.type != .primary {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("MEMORIAL STATUS")
                                        .font(.appCaption)
                                        .foregroundColor(.textSecondary)

                                    // Deceased toggle
                                    HStack {
                                        Text("Deceased")
                                            .font(.appBody)
                                            .foregroundColor(.textPrimary)

                                        Spacer()

                                        Toggle("", isOn: $isDeceased)
                                            .tint(appAccentColor)
                                            .labelsHidden()
                                            .onChange(of: isDeceased) { _, newValue in
                                                if !newValue {
                                                    // Clear date of death when unchecking
                                                    dateOfDeath = nil
                                                }
                                            }
                                    }
                                    .padding()
                                    .background(Color.cardBackgroundSoft)
                                    .cornerRadius(AppDimensions.buttonCornerRadius)

                                    // Date of Death picker (only shown if deceased)
                                    if isDeceased {
                                        Button {
                                            showDeathDatePicker = true
                                        } label: {
                                            HStack {
                                                Text(dateOfDeath != nil ? dateOfDeath!.formattedBirthday() : "Date of Passing")
                                                    .foregroundColor(dateOfDeath != nil ? .textPrimary : .textSecondary)

                                                Spacer()

                                                Image(systemName: "calendar")
                                                    .foregroundColor(.textSecondary)
                                            }
                                            .padding()
                                            .frame(height: AppDimensions.textFieldHeight)
                                            .background(Color.cardBackgroundSoft)
                                            .cornerRadius(AppDimensions.buttonCornerRadius)
                                        }

                                        Text("Deceased profiles show a simplified memorial view with essential information only.")
                                            .font(.appCaption)
                                            .foregroundColor(.textSecondary)
                                    }
                                }
                                .padding(.top, 8)
                            }

                            // Custom Fields Section
                            if !customFields.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("ADDITIONAL INFORMATION")
                                        .font(.appCaption)
                                        .foregroundColor(.textSecondary)

                                    ForEach(customFields) { field in
                                        CustomFieldRowView(
                                            detail: field,
                                            onDelete: {
                                                Task {
                                                    await deleteCustomField(field)
                                                }
                                            }
                                        )
                                    }
                                }
                                .padding(.top, 8)
                            }

                            // Add new information button
                            Button {
                                showAddCustomField = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20))
                                    Text("Add new information")
                                        .font(.appButtonText)
                                }
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(appAccentColor)
                                .cornerRadius(AppDimensions.buttonCornerRadius)
                            }
                            .padding(.top, 8)

                            if let error = errorMessage {
                                Text(error)
                                    .font(.appCaption)
                                    .foregroundColor(.medicalRed)
                            }

                            // Bottom spacing
                            Spacer()
                                .frame(height: 40)
                        }
                        .padding(AppDimensions.screenPadding)
                    }
            }
        }
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(selectedDate: $birthday, isPresented: $showDatePicker)
        }
        .sheet(isPresented: $showDeathDatePicker) {
            DatePickerSheet(selectedDate: $dateOfDeath, isPresented: $showDeathDatePicker)
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
            await loadProfiles()
        }
    }

    private func loadProfiles() async {
        guard let accountId = appState.currentAccount?.id else { return }
        do {
            allProfiles = try await appState.profileRepository.getProfiles(accountId: accountId)
        } catch {
            #if DEBUG
            print("Failed to load profiles: \(error)")
            #endif
        }
    }

    private func loadCustomFields() async {
        do {
            // Load only note-type details (custom fields)
            let allDetails = try await appState.profileRepository.getProfileDetails(profileId: profile.id)
            customFields = allDetails.filter { $0.category == .note }
        } catch {
            #if DEBUG
            print("Failed to load custom fields: \(error)")
            #endif
        }
    }

    private func deleteCustomField(_ field: ProfileDetail) async {
        do {
            try await appState.profileRepository.deleteProfileDetail(id: field.id)
            customFields.removeAll { $0.id == field.id }
        } catch {
            errorMessage = "Failed to delete field: \(error.localizedDescription)"
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
        updatedProfile.connectedToProfileId = connectedToProfileId
        updatedProfile.includeInFamilyTree = includeInFamilyTree
        updatedProfile.phone = phone.isBlank ? nil : phone
        updatedProfile.email = email.isBlank ? nil : email
        updatedProfile.address = address.isBlank ? nil : address
        updatedProfile.birthday = birthday
        updatedProfile.isDeceased = isDeceased
        updatedProfile.dateOfDeath = isDeceased ? dateOfDeath : nil

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
                    #if DEBUG
                    print("Photo upload failed: \(error.localizedDescription)")
                    #endif
                }
            }

            let saved = try await appState.profileRepository.updateProfile(updatedProfile)

            // Update birthday reminder - skip for deceased profiles
            if saved.birthday != nil && !saved.isDeceased {
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
    let onDelete: () -> Void

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

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundColor(.red)
                    .frame(width: 44, height: 44)
            }
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
    @Environment(\.appAccentColor) private var appAccentColor

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
            VStack(spacing: 0) {
                // Custom header with icons
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.5))
                            )
                    }

                    Spacer()

                    Text("Add Information")
                        .font(.headline)
                        .foregroundColor(.textPrimary)

                    Spacer()

                    Button {
                        Task { await saveField() }
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 48, height: 48)
                            .background(
                                Circle()
                                    .fill(label.isBlank || value.isBlank || isLoading ? Color.gray.opacity(0.3) : appAccentColor)
                            )
                    }
                    .disabled(label.isBlank || value.isBlank || isLoading)
                }
                .padding(.horizontal, AppDimensions.screenPadding)
                .padding(.vertical, 16)
                .background(Color.appBackground)

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
                                                .background(label == suggestion ? appAccentColor : Color.cardBackgroundSoft)
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
            }
            .background(Color.appBackground)
            .navigationBarHidden(true)
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

    @State private var relatedProfiles: [Profile] = []
    @State private var isLoading = false
    @State private var showSettings = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header scrolls with content
                ConnectionsHeaderView(
                    profile: profile,
                    onBack: { dismiss() }
                )

                // Content
                VStack(spacing: AppDimensions.cardSpacing) {
                        // Section header card
                        SectionHeaderCard(
                            title: "Connections",
                            icon: "person.2.fill"
                        )

                        // Connections list - auto-populated from other profiles in the account
                        if !relatedProfiles.isEmpty {
                            VStack(spacing: AppDimensions.cardSpacing) {
                                ForEach(relatedProfiles) { relatedProfile in
                                    NavigationLink(destination: ProfileDetailView(profile: relatedProfile)) {
                                        SimpleConnectionCard(profile: relatedProfile)
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
                        if relatedProfiles.isEmpty && !isLoading {
                            VStack(spacing: 12) {
                                Image(systemName: "person.2.slash")
                                    .font(.system(size: 48))
                                    .foregroundColor(.textSecondary)

                                Text("No connections yet")
                                    .font(.appCardTitle)
                                    .foregroundColor(.textPrimary)

                                Text("Add family members or friends from the Profiles page")
                                    .font(.appBody)
                                    .foregroundColor(.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        }

                        // Bottom spacing for nav bar
                        Spacer()
                            .frame(height: 120)
                }
                .padding(.horizontal, AppDimensions.screenPadding)
                .padding(.top, AppDimensions.cardSpacing)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Color.appBackground)
        .navigationBarHidden(true)
        .sidePanel(isPresented: $showSettings) {
            SettingsPanelView(onDismiss: { showSettings = false })
        }
        .task {
            await loadRelatedProfiles()
        }
        .refreshable {
            await loadRelatedProfiles()
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

    private func loadRelatedProfiles() async {
        guard let account = appState.currentAccount else { return }

        isLoading = true

        do {
            // Get all profiles in the account except the current one
            let allProfiles = try await appState.profileRepository.getProfiles(accountId: account.id)
            relatedProfiles = allProfiles.filter { $0.id != profile.id }
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

    init(profile: Profile, onBack: @escaping () -> Void) {
        self.profile = profile
        self.onBack = onBack
    }

    var body: some View {
        CustomizableHeaderView(
            pageIdentifier: .profileDetail,
            title: profile.fullName,
            subtitle: "Connections",
            showBackButton: true,
            backAction: onBack
        )
    }
}

// MARK: - Simple Connection Card (uses profile's relationship field)
struct SimpleConnectionCard: View {
    let profile: Profile

    var body: some View {
        HStack(spacing: 16) {
            // Profile photo
            AsyncProfileImage(url: profile.photoUrl, size: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(profile.displayName)
                    .font(.appCardTitle)
                    .foregroundColor(.textPrimary)

                if let relationship = profile.relationship, !relationship.isEmpty {
                    Text(relationship)
                        .font(.appCaption)
                        .foregroundColor(.connectionsGreen)
                }
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

// MARK: - Relationship Field With Picker
struct RelationshipFieldWithPicker: View {
    @Binding var relationship: String
    @Binding var showPicker: Bool
    @Environment(\.appAccentColor) private var appAccentColor
    @State private var isButtonPressed = false

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
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                showPicker = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.black)
                    .frame(width: AppDimensions.textFieldHeight, height: AppDimensions.textFieldHeight)
                    .background(appAccentColor)
                    .cornerRadius(AppDimensions.buttonCornerRadius)
                    .scaleEffect(isButtonPressed ? 0.9 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isButtonPressed)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isButtonPressed = true }
                    .onEnded { _ in isButtonPressed = false }
            )
        }
    }
}

// MARK: - Relationship Picker Sheet
struct RelationshipPickerSheet: View {
    @Binding var selectedRelationship: String
    @Binding var isPresented: Bool
    @Environment(\.appAccentColor) private var appAccentColor

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
                                    RelationshipPillButton(
                                        title: type.displayName,
                                        isSelected: selectedRelationship == type.displayName,
                                        accentColor: appAccentColor
                                    ) {
                                        selectedRelationship = type.displayName
                                        isPresented = false
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
                                    RelationshipPillButton(
                                        title: type.displayName,
                                        isSelected: selectedRelationship == type.displayName,
                                        accentColor: appAccentColor
                                    ) {
                                        selectedRelationship = type.displayName
                                        isPresented = false
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
                                    RelationshipPillButton(
                                        title: type.displayName,
                                        isSelected: selectedRelationship == type.displayName,
                                        accentColor: appAccentColor
                                    ) {
                                        selectedRelationship = type.displayName
                                        isPresented = false
                                    }
                                }
                            }
                        }

                        // Other
                        VStack(alignment: .leading, spacing: 8) {
                            Text("OTHER")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)

                            RelationshipPillButton(
                                title: "Other",
                                isSelected: selectedRelationship == "Other",
                                accentColor: appAccentColor
                            ) {
                                selectedRelationship = "Other"
                                isPresented = false
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
        .presentationDetents([.large])
    }
}

// MARK: - Relationship Pill Button
/// An animated pill button for selecting a relationship
struct RelationshipPillButton: View {
    let title: String
    let isSelected: Bool
    let accentColor: Color
    let onSelect: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            onSelect()
        } label: {
            Text(title)
                .font(.appCaption)
                .foregroundColor(isSelected ? .black : .textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? accentColor : Color.cardBackgroundSoft)
                .cornerRadius(20)
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Size Field With Picker
struct SizeFieldWithPicker: View {
    @Binding var size: String
    @Binding var showPicker: Bool
    @Environment(\.appAccentColor) private var appAccentColor

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
                    .background(appAccentColor)
                    .cornerRadius(AppDimensions.buttonCornerRadius)
            }
        }
    }
}

// MARK: - Size Picker Sheet
struct SizePickerSheet: View {
    @Binding var selectedSize: String
    @Binding var isPresented: Bool
    @Environment(\.appAccentColor) private var appAccentColor

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
                                            .background(selectedSize == size ? appAccentColor : Color.cardBackgroundSoft)
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
                                            .background(selectedSize == size ? appAccentColor : Color.cardBackgroundSoft)
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
                                            .background(selectedSize == size ? appAccentColor : Color.cardBackgroundSoft)
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

// MARK: - Gift Card With Overlay Support
struct GiftCardWithOverlay: View {
    let detail: ProfileDetail
    let status: GiftItemCard.GiftStatus
    let isActive: Bool
    let onStatusChange: (GiftItemCard.GiftStatus) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @Environment(\.appAccentColor) private var appAccentColor

    private func nextStatus() -> GiftItemCard.GiftStatus {
        switch status {
        case .idea: return .bought
        case .bought: return .given
        case .given: return .idea
        }
    }

    var body: some View {
        HStack {
            // Tappable content area for editing
            HStack {
                VStack(alignment: .leading, spacing: 4) {


                    Text(detail.label)
                        .font(.appCardTitle)
                        .foregroundColor(.textPrimary)
                }

                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onEdit()
            }

            // Status badge - tappable to cycle through Idea → Bought → Given
            Button {
                onStatusChange(nextStatus())
            } label: {
                Text(status.displayName)
                    .font(.appCaption)
                    .fontWeight(.medium)
                    .foregroundColor(status.textColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(status.color(accent: appAccentColor))
                    .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.red)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(AppDimensions.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
        .opacity(isActive ? 0 : 1)
    }
}

// MARK: - Clothing Card
struct ClothingCardWithOverlay: View {
    let detail: ProfileDetail
    let onEdit: () -> Void
    let onDelete: () -> Void

    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        Button(action: onEdit) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Clothing")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)

                    Text(detail.label)
                        .font(.appCardTitle)
                        .foregroundColor(.textPrimary)
                }

                Spacer()

                // Size value pill
                Text(detail.value)
                    .font(.appValuePill)
                    .foregroundColor(.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.cardBackgroundSoft)
                    .cornerRadius(AppDimensions.pillCornerRadius)

                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(.medicalRed)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(AppDimensions.cardPadding)
            .background(Color.cardBackground)
            .cornerRadius(AppDimensions.cardCornerRadius)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Connected To Picker Field
/// A picker field that allows selecting another profile as a family tree connection
struct ConnectedToPickerField: View {
    @Binding var selectedProfileId: UUID?
    let profiles: [Profile]
    let currentProfileId: UUID?  // Exclude current profile from selection
    @Environment(\.appAccentColor) private var appAccentColor
    @State private var showPicker = false

    /// Filtered profiles (excludes current profile and primary profile)
    private var availableProfiles: [Profile] {
        profiles.filter { profile in
            profile.id != currentProfileId && profile.type != .primary
        }
    }

    /// The full name of the selected profile
    private var selectedProfileFullName: String? {
        guard let id = selectedProfileId else { return nil }
        return profiles.first { $0.id == id }?.fullName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("FAMILY CONNECTION")
                .font(.appCaption)
                .foregroundColor(.textSecondary)

            Button {
                showPicker = true
            } label: {
                HStack {
                    if let name = selectedProfileFullName {
                        Text("Connected to: \(name)")
                            .foregroundColor(.textPrimary)
                    } else {
                        Text("Connect to family member (optional)")
                            .foregroundColor(.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "person.2.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                }
                .padding()
                .frame(height: AppDimensions.textFieldHeight)
                .background(Color.cardBackgroundSoft)
                .cornerRadius(AppDimensions.buttonCornerRadius)
            }

            // Helper text
            if selectedProfileId != nil {
                Text("This helps build the family tree by linking related people")
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary)
                    .padding(.top, 2)
            }
        }
        .sheet(isPresented: $showPicker) {
            FamilyConnectionPickerSheet(
                selectedProfileId: $selectedProfileId,
                profiles: availableProfiles,
                isPresented: $showPicker
            )
        }
    }
}

// MARK: - Family Connection Picker Sheet
/// A sheet for selecting a family connection with nice animations
struct FamilyConnectionPickerSheet: View {
    @Binding var selectedProfileId: UUID?
    let profiles: [Profile]
    @Binding var isPresented: Bool
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedDetent: PresentationDetent = .large
    @State private var searchText: String = ""

    /// Profiles filtered by search text and sorted alphabetically
    private var filteredProfiles: [Profile] {
        let sorted = profiles.sorted { $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending }
        if searchText.isEmpty {
            return sorted
        }
        return sorted.filter { $0.fullName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Search field
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.textSecondary)
                            TextField("Search family members", text: $searchText)
                                .font(.appBody)
                                .foregroundColor(.textPrimary)
                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.textSecondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color.cardBackgroundSoft)
                        .cornerRadius(AppDimensions.buttonCornerRadius)

                        // None option
                        Button {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            selectedProfileId = nil
                            isPresented = false
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(selectedProfileId == nil ? appAccentColor : Color.cardBackgroundSoft)
                                        .frame(width: 44, height: 44)

                                    Image(systemName: "minus.circle")
                                        .font(.system(size: 20))
                                        .foregroundColor(selectedProfileId == nil ? .black : .textSecondary)
                                }

                                Text("None")
                                    .font(.appBody)
                                    .foregroundColor(selectedProfileId == nil ? appAccentColor : .textPrimary)

                                Spacer()

                                if selectedProfileId == nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(appAccentColor)
                                }
                            }
                            .padding()
                            .background(Color.cardBackground)
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())

                        if !filteredProfiles.isEmpty {
                            Text("FAMILY MEMBERS")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)
                                .padding(.top, 8)

                            // Profile options
                            ForEach(filteredProfiles) { profile in
                                ProfileConnectionRow(
                                    profile: profile,
                                    isSelected: selectedProfileId == profile.id,
                                    accentColor: appAccentColor,
                                    onSelect: {
                                        let impact = UIImpactFeedbackGenerator(style: .light)
                                        impact.impactOccurred()
                                        selectedProfileId = profile.id
                                        isPresented = false
                                    }
                                )
                            }
                        } else if !searchText.isEmpty {
                            // No results for search
                            VStack(spacing: 8) {
                                Image(systemName: "person.slash")
                                    .font(.system(size: 32))
                                    .foregroundColor(.textSecondary)
                                Text("No family members found")
                                    .font(.appBody)
                                    .foregroundColor(.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 32)
                        }
                    }
                    .padding(AppDimensions.screenPadding)
                }
            }
            .navigationTitle("Family Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.textSecondary)
                }
            }
        }
        .presentationDetents([.fraction(0.6), .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Profile Connection Row
/// A row displaying a profile option in the family connection picker
struct ProfileConnectionRow: View {
    let profile: Profile
    let isSelected: Bool
    let accentColor: Color
    let onSelect: () -> Void

    var body: some View {
        Button {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            onSelect()
        } label: {
            HStack(spacing: 12) {
                // Profile avatar
                ZStack {
                    Circle()
                        .fill(isSelected ? accentColor : Color.cardBackgroundSoft)
                        .frame(width: 44, height: 44)

                    if let photoUrl = profile.photoUrl, let url = URL(string: photoUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Text(profile.fullName.prefix(1).uppercased())
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(isSelected ? .black : .textPrimary)
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                    } else {
                        Text(profile.fullName.prefix(1).uppercased())
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(isSelected ? .black : .textPrimary)
                    }
                }

                // Profile info
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.fullName)
                        .font(.appBody)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(isSelected ? accentColor : .textPrimary)

                    if let relationship = profile.relationship {
                        Text(relationship)
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                    }
                }

                Spacer()

                // Selected indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(accentColor)
                }
            }
            .padding()
            .background(isSelected ? accentColor.opacity(0.1) : Color.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? accentColor : Color.clear, lineWidth: 2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Scale Button Style
/// A button style that provides a subtle scale animation on press
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
