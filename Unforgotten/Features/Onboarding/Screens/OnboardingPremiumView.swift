import SwiftUI
import StoreKit

// MARK: - Onboarding Premium View
/// Screen 6: Premium subscription offering with StoreKit 2 integration
/// Shows both Premium and Family Plus tiers
struct OnboardingPremiumView: View {
    @Bindable var onboardingData: OnboardingData
    let accentColor: Color
    let onContinue: () -> Void

    @State private var products: [Product] = []
    @State private var selectedProduct: Product? = nil
    @State private var purchaseState: PurchaseState = .idle
    @State private var errorMessage: String? = nil
    @State private var hasAppeared = false
    @State private var selectedTier: SelectedTier = .premium
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum PurchaseState {
        case idle
        case loading
        case purchasing
        case success
    }

    private enum SelectedTier {
        case premium
        case familyPlus
    }

    // Product IDs for StoreKit
    private let productIds = [
        "com.unforgotten.premium.monthly",
        "com.unforgotten.premium.annual",
        "com.unforgotten.family.monthly",
        "com.unforgotten.family.annual"
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 24)

                // Header
                VStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 60))
                        .foregroundColor(accentColor)
                        .scaleEffect(hasAppeared ? 1 : 0.5)
                        .opacity(hasAppeared ? 1 : 0)

                    Text("Unlock more with a subscription")
                        .font(.appLargeTitle)
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.center)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 10)
                }
                .padding(.horizontal, AppDimensions.screenPadding)
                .animation(
                    reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8),
                    value: hasAppeared
                )

                // Success state
                if purchaseState == .success {
                    successView
                } else {
                    // Tier selection and pricing
                    premiumContent
                }

                Spacer()
                    .frame(minHeight: 40)

                // Bottom buttons
                bottomButtons
                    .padding(.horizontal, AppDimensions.screenPadding)
                    .padding(.bottom, 48)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.5),
                        value: hasAppeared
                    )
            }
        }
        .task {
            await loadProducts()
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

    // MARK: - Premium Features List
    private let premiumFeatures: [(icon: String, text: String)] = [
        ("infinity", "Unlimited profiles, medications, notes & more"),
        ("calendar", "Unlimited appointments (no 30-day limit)"),
        ("photo.on.rectangle", "Custom header images"),
        ("bell.badge", "Unlimited reminders & countdowns")
    ]

    // MARK: - Family Plus Features List
    private let familyPlusFeatures: [(icon: String, text: String)] = [
        ("checkmark.circle.fill", "Everything in Premium"),
        ("person.badge.plus", "Invite family members"),
        ("arrow.left.arrow.right", "Switch between family accounts"),
        ("person.2", "Manage account members")
    ]

    // MARK: - Premium Content
    private var premiumContent: some View {
        VStack(spacing: 20) {
            // Tier selector
            tierSelector
                .padding(.horizontal, AppDimensions.screenPadding)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 20)
                .animation(
                    reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.1),
                    value: hasAppeared
                )

            // Features for selected tier
            VStack(spacing: 10) {
                let features = selectedTier == .premium ? premiumFeatures : familyPlusFeatures
                ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                    HStack(spacing: 12) {
                        Image(systemName: feature.icon)
                            .font(.system(size: 16))
                            .foregroundColor(selectedTier == .premium ? accentColor : .purple)
                            .frame(width: 24)

                        Text(feature.text)
                            .font(.appBody)
                            .foregroundColor(.textPrimary)

                        Spacer()
                    }
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.05 + 0.15),
                        value: hasAppeared
                    )
                }
            }
            .padding(.horizontal, AppDimensions.screenPadding)

            // Pricing options
            if purchaseState == .loading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: accentColor))
                    .padding()
            } else {
                pricingSection
                    .padding(.horizontal, AppDimensions.screenPadding)
            }

            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.appCaption)
                    .foregroundColor(.medicalRed)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppDimensions.screenPadding)
            }

            // Subscription terms
            subscriptionTerms
        }
    }

    // MARK: - Tier Selector
    private var tierSelector: some View {
        HStack(spacing: 0) {
            // Premium tab
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTier = .premium
                    updateSelectedProduct()
                }
            } label: {
                VStack(spacing: 4) {
                    Text("Premium")
                        .font(.appBodyMedium)
                        .foregroundColor(selectedTier == .premium ? .textPrimary : .textSecondary)
                    Text("$4.99/mo")
                        .font(.appCaption)
                        .foregroundColor(selectedTier == .premium ? accentColor : .textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selectedTier == .premium ? accentColor.opacity(0.15) : Color.clear)
                .cornerRadius(12)
            }

            // Family Plus tab
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTier = .familyPlus
                    updateSelectedProduct()
                }
            } label: {
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Text("Family Plus")
                            .font(.appBodyMedium)
                            .foregroundColor(selectedTier == .familyPlus ? .textPrimary : .textSecondary)
                    }
                    Text("$7.99/mo")
                        .font(.appCaption)
                        .foregroundColor(selectedTier == .familyPlus ? .purple : .textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selectedTier == .familyPlus ? Color.purple.opacity(0.15) : Color.clear)
                .cornerRadius(12)
            }
        }
        .padding(4)
        .background(Color.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Pricing Section
    private var pricingSection: some View {
        VStack(spacing: 12) {
            let tierProducts = productsForSelectedTier
            if tierProducts.isEmpty {
                // Fallback pricing
                if selectedTier == .premium {
                    pricingCard(
                        title: "Monthly",
                        price: "$4.99/month",
                        isSelected: true,
                        isBestValue: false,
                        tierColor: accentColor
                    )
                    pricingCard(
                        title: "Annual",
                        price: "$39.99/year",
                        subtitle: "Save 33%",
                        isSelected: false,
                        isBestValue: true,
                        tierColor: accentColor
                    )
                } else {
                    pricingCard(
                        title: "Monthly",
                        price: "$7.99/month",
                        isSelected: true,
                        isBestValue: false,
                        tierColor: .purple
                    )
                    pricingCard(
                        title: "Annual",
                        price: "$63.99/year",
                        subtitle: "Save 33%",
                        isSelected: false,
                        isBestValue: true,
                        tierColor: .purple
                    )
                }
            } else {
                ForEach(tierProducts.sorted { $0.price < $1.price }) { product in
                    productCard(product)
                }
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(
            reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.35),
            value: hasAppeared
        )
    }

    private var productsForSelectedTier: [Product] {
        let prefix = selectedTier == .premium ? "com.unforgotten.premium" : "com.unforgotten.family"
        return products.filter { $0.id.hasPrefix(prefix) }
    }

    private func updateSelectedProduct() {
        let tierProducts = productsForSelectedTier
        // Default to annual if available
        selectedProduct = tierProducts.first { $0.id.contains("annual") } ?? tierProducts.first
    }

    // MARK: - Success View
    private var successView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.badgeGreen)

            Text(selectedTier == .premium ? "Welcome to Premium!" : "Welcome to Family Plus!")
                .font(.appTitle)
                .foregroundColor(.textPrimary)

            Text("You now have access to all \(selectedTier == .premium ? "premium" : "family plus") features")
                .font(.appBody)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }

    // MARK: - Pricing Card
    private func pricingCard(
        title: String,
        price: String,
        subtitle: String? = nil,
        isSelected: Bool,
        isBestValue: Bool,
        tierColor: Color
    ) -> some View {
        VStack(spacing: 0) {
            if isBestValue {
                Text("BEST VALUE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(tierColor)
                    .clipShape(Capsule())
                    .offset(y: 12)
                    .zIndex(1)
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.appBodyMedium)
                        .foregroundColor(.textPrimary)

                    Text(price)
                        .font(.appTitle)
                        .foregroundColor(.textPrimary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.appCaption)
                            .foregroundColor(tierColor)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(tierColor)
                }
            }
            .padding(20)
            .background(Color.cardBackground)
            .cornerRadius(AppDimensions.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius)
                    .stroke(isSelected ? tierColor : Color.cardBackgroundLight, lineWidth: isSelected ? 2 : 1)
            )
        }
    }

    // MARK: - Product Card
    private func productCard(_ product: Product) -> some View {
        let isSelected = selectedProduct?.id == product.id
        let isAnnual = product.id.contains("annual")
        let tierColor: Color = selectedTier == .premium ? accentColor : .purple

        return Button {
            selectedProduct = product
        } label: {
            pricingCard(
                title: isAnnual ? "Annual" : "Monthly",
                price: product.displayPrice + (isAnnual ? "/year" : "/month"),
                subtitle: isAnnual ? "Save 33%" : nil,
                isSelected: isSelected,
                isBestValue: isAnnual,
                tierColor: tierColor
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Subscription Terms
    private var subscriptionTerms: some View {
        VStack(spacing: 8) {
            Text("Subscription auto-renews unless cancelled at least 24 hours before the end of the current period. Manage subscriptions in Settings.")
                .font(.system(size: 10))
                .foregroundColor(.textMuted)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button("Terms of Use") {
                    // Open terms URL
                }
                .font(.system(size: 10))
                .foregroundColor(.textSecondary)

                Button("Privacy Policy") {
                    // Open privacy URL
                }
                .font(.system(size: 10))
                .foregroundColor(.textSecondary)
            }
        }
        .padding(.horizontal, AppDimensions.screenPadding)
    }

    // MARK: - Bottom Buttons
    private var bottomButtons: some View {
        VStack(spacing: 12) {
            if purchaseState == .success {
                PrimaryButton(
                    title: "Continue",
                    backgroundColor: selectedTier == .premium ? accentColor : .purple,
                    action: onContinue
                )
            } else {
                // Subscribe button
                PrimaryButton(
                    title: "Subscribe to \(selectedTier == .premium ? "Premium" : "Family Plus")",
                    isLoading: purchaseState == .purchasing,
                    backgroundColor: selectedTier == .premium ? accentColor : .purple,
                    action: purchase
                )
                .disabled(selectedProduct == nil && products.isEmpty)

                // Restore purchases
                Button {
                    Task {
                        await restorePurchases()
                    }
                } label: {
                    Text("Restore Purchases")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }

                // Maybe later
                Button {
                    onContinue()
                } label: {
                    Text("Maybe later")
                        .font(.appBodyMedium)
                        .foregroundColor(.textSecondary)
                }
            }
        }
    }

    // MARK: - StoreKit Methods

    private func loadProducts() async {
        purchaseState = .loading
        do {
            let storeProducts = try await Product.products(for: productIds)
            await MainActor.run {
                products = storeProducts
                // Select annual premium by default
                selectedProduct = storeProducts.first { $0.id == "com.unforgotten.premium.annual" }
                    ?? storeProducts.first { $0.id.contains("premium") }
                purchaseState = .idle
            }
        } catch {
            #if DEBUG
            print("Failed to load products: \(error)")
            #endif
            await MainActor.run {
                purchaseState = .idle
            }
        }
    }

    private func purchase() {
        guard let product = selectedProduct ?? productsForSelectedTier.first else {
            // If no StoreKit products available, just continue
            onContinue()
            return
        }

        purchaseState = .purchasing
        errorMessage = nil

        Task {
            do {
                let result = try await product.purchase()

                switch result {
                case .success(let verification):
                    switch verification {
                    case .verified(let transaction):
                        await transaction.finish()
                        await MainActor.run {
                            // Determine tier from product ID
                            let tier: SubscriptionTier = product.id.contains("family") ? .familyPlus : .premium
                            onboardingData.isPremium = true
                            onboardingData.subscriptionProductId = product.id
                            onboardingData.subscriptionTier = tier
                            purchaseState = .success
                        }

                    case .unverified(_, let error):
                        await MainActor.run {
                            errorMessage = "Purchase verification failed. Please try again."
                            purchaseState = .idle
                        }
                        #if DEBUG
                        print("Unverified transaction: \(error)")
                        #endif
                    }

                case .userCancelled:
                    await MainActor.run {
                        purchaseState = .idle
                    }

                case .pending:
                    await MainActor.run {
                        errorMessage = "Purchase is pending approval."
                        purchaseState = .idle
                    }

                @unknown default:
                    await MainActor.run {
                        purchaseState = .idle
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Purchase failed. Please try again."
                    purchaseState = .idle
                }
                #if DEBUG
                print("Purchase error: \(error)")
                #endif
            }
        }
    }

    private func restorePurchases() async {
        do {
            try await AppStore.sync()

            // Check for active subscriptions
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result {
                    if productIds.contains(transaction.productID) {
                        await MainActor.run {
                            let tier: SubscriptionTier = transaction.productID.contains("family") ? .familyPlus : .premium
                            onboardingData.isPremium = true
                            onboardingData.subscriptionProductId = transaction.productID
                            onboardingData.subscriptionTier = tier
                            selectedTier = tier == .familyPlus ? .familyPlus : .premium
                            purchaseState = .success
                        }
                        return
                    }
                }
            }

            await MainActor.run {
                errorMessage = "No active subscription found."
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to restore purchases."
            }
            #if DEBUG
            print("Restore error: \(error)")
            #endif
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        OnboardingPremiumView(
            onboardingData: OnboardingData(),
            accentColor: Color(hex: "FFC93A"),
            onContinue: {}
        )
    }
}
