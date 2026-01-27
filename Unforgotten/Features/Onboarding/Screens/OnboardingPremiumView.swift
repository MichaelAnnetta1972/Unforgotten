import SwiftUI
import StoreKit

// MARK: - Onboarding Premium View
/// Screen 6: Premium subscription offering with StoreKit 2 integration
/// Shows both Premium and Family Plus tiers with card-based design
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
    @State private var selectedBillingPeriod: BillingPeriod = .monthly
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

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

    private enum BillingPeriod {
        case monthly
        case annual
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
            VStack(spacing: isRegularWidth ? 32 : 24) {
                Spacer()
                    .frame(height: isRegularWidth ? 60 : 40)

                // Header
                Text("Try Unforgotten Pro for free")
                    .font(.appLargeTitle)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 10)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8),
                        value: hasAppeared
                    )

                // Success state
                if purchaseState == .success {
                    successView
                } else {
                    // Tier selector and pricing
                    premiumContent
                }

                // Bottom buttons
                bottomButtons
                    .frame(maxWidth: isRegularWidth ? 400 : .infinity)
                    .padding(.horizontal, AppDimensions.screenPadding)
                    .padding(.bottom, isRegularWidth ? 64 : 48)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.4),
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

    // MARK: - Feature Descriptions
    private let premiumDescription = "Unlock unlimited medications with reminders, profiles for your loved ones, to-do lists, notes, and useful contacts. Everything you need to stay organised and never forget what matters most."

    private let familyPlusDescription = "Everything in Premium, plus the ability to invite family members to help manage care together. Share access with different permission levels including Owner, Admin, Helper, and Viewer roles."

    // MARK: - Premium Content
    private var premiumContent: some View {
        VStack(spacing: isRegularWidth ? 24 : 20) {
            // Tier selector (segmented control style)
            tierSelector
                .frame(maxWidth: isRegularWidth ? 500 : .infinity)
                .padding(.horizontal, AppDimensions.screenPadding)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 20)
                .animation(
                    reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.1),
                    value: hasAppeared
                )

            // Plan details card
            planDetailsCard
                .frame(maxWidth: isRegularWidth ? 500 : .infinity)
                .padding(.horizontal, AppDimensions.screenPadding)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 20)
                .animation(
                    reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.2),
                    value: hasAppeared
                )

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
                .opacity(hasAppeared ? 1 : 0)
                .animation(
                    reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.3),
                    value: hasAppeared
                )
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
                Text("Premium")
                    .font(.appBodyMedium)
                    .foregroundColor(selectedTier == .premium ? .white : accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(selectedTier == .premium ? accentColor : Color.clear)
            }

            // Family Plus tab
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTier = .familyPlus
                    updateSelectedProduct()
                }
            } label: {
                Text("Family Plus")
                    .font(.appBodyMedium)
                    .foregroundColor(selectedTier == .familyPlus ? .white : accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(selectedTier == .familyPlus ? accentColor : Color.clear)
            }
        }
        .background(Color.cardBackground)
        .clipShape(Capsule())
    }

    // MARK: - Plan Details Card
    private var planDetailsCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Plan title
            Text(selectedTier == .premium ? "Premium" : "Family Plus")
                .font(.appTitle)
                .foregroundColor(.textPrimary)

            // Features description as paragraph
            Text(selectedTier == .premium ? premiumDescription : familyPlusDescription)
                .font(.appBody)
                .foregroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            // Pricing options
            VStack(spacing: 12) {
                // Monthly option
                pricingOptionRow(
                    title: "Monthly",
                    price: selectedTier == .premium ? "$4.99/month" : "$9.99/month",
                    isSelected: selectedBillingPeriod == .monthly,
                    onSelect: { selectedBillingPeriod = .monthly; updateSelectedProduct() }
                )

                // Annual option
                pricingOptionRow(
                    title: "Annual",
                    price: selectedTier == .premium ? "$39.99/year" : "$69.99/year",
                    isSelected: selectedBillingPeriod == .annual,
                    onSelect: { selectedBillingPeriod = .annual; updateSelectedProduct() }
                )
            }
        }
        .padding(20)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }

    // MARK: - Pricing Option Row
    private func pricingOptionRow(
        title: String,
        price: String,
        isSelected: Bool,
        onSelect: @escaping () -> Void
    ) -> some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.appBody)
                        .foregroundColor(.textPrimary)

                    Text(price)
                        .font(.appCaption)
                        .foregroundColor(accentColor)
                }

                Spacer()

                // Selection indicator
                Circle()
                    .fill(isSelected ? accentColor : Color.clear)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? accentColor : Color.textSecondary.opacity(0.5), lineWidth: 2)
                    )
            }
            .padding(16)
            .background(Color.cardBackgroundSoft.opacity(0.5))
            .cornerRadius(AppDimensions.buttonCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppDimensions.buttonCornerRadius)
                    .stroke(isSelected ? accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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

    // MARK: - Subscription Terms
    private var subscriptionTerms: some View {
        VStack(spacing: 8) {
            Text("Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period. Manage subscriptions in Settings.")
                .font(.system(size: 12))
                .foregroundColor(.textMuted)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button("Terms of Use") {
                    // Open terms URL
                }
                .font(.system(size: 12))
                .foregroundColor(.textSecondary)

                Button("Privacy Policy") {
                    // Open privacy URL
                }
                .font(.system(size: 10))
                .foregroundColor(.textSecondary)
            }
        }
        .frame(maxWidth: isRegularWidth ? 500 : .infinity)
        .padding(.horizontal, AppDimensions.screenPadding)
    }

    // MARK: - Bottom Buttons
    private var bottomButtons: some View {
        VStack(spacing: 12) {
            if purchaseState == .success {
                Button(action: onContinue) {
                    Text("Continue")
                        .font(.appBodyMedium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppDimensions.buttonHeight)
                        .background(accentColor)
                        .cornerRadius(AppDimensions.buttonCornerRadius)
                }
            } else {
                // Subscribe button
                Button(action: purchase) {
                    HStack {
                        if purchaseState == .purchasing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Start your 7 day free trial")
                                .font(.appBodyMedium)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: AppDimensions.buttonHeight)
                    .background(accentColor)
                    .cornerRadius(AppDimensions.buttonCornerRadius)
                }
                .disabled(purchaseState == .purchasing)

                // Maybe later
                Button(action: onContinue) {
                    Text("Maybe Later")
                        .font(.appBodyMedium)
                        .foregroundColor(.textSecondary)
                }
            }
        }
    }

    // MARK: - StoreKit Methods

    private var productsForSelectedTier: [Product] {
        let prefix = selectedTier == .premium ? "com.unforgotten.premium" : "com.unforgotten.family"
        return products.filter { $0.id.hasPrefix(prefix) }
    }

    private func updateSelectedProduct() {
        let tierProducts = productsForSelectedTier
        let suffix = selectedBillingPeriod == .annual ? "annual" : "monthly"
        selectedProduct = tierProducts.first { $0.id.contains(suffix) } ?? tierProducts.first
    }

    private func loadProducts() async {
        purchaseState = .loading
        do {
            let storeProducts = try await Product.products(for: productIds)
            await MainActor.run {
                products = storeProducts
                // Select monthly premium by default
                selectedProduct = storeProducts.first { $0.id == "com.unforgotten.premium.monthly" }
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
