import SwiftUI
import StoreKit

// MARK: - Onboarding Premium View
/// Screen 6: Premium subscription offering with StoreKit 2 integration
struct OnboardingPremiumView: View {
    @Bindable var onboardingData: OnboardingData
    let accentColor: Color
    let onContinue: () -> Void

    @State private var products: [Product] = []
    @State private var selectedProduct: Product? = nil
    @State private var purchaseState: PurchaseState = .idle
    @State private var errorMessage: String? = nil
    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum PurchaseState {
        case idle
        case loading
        case purchasing
        case success
    }

    // Placeholder product IDs - replace with actual App Store Connect IDs
    private let productIds = [
        "com.unforgotten.premium.monthly",
        "com.unforgotten.premium.annual"
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

                    Text("Unlock everything with Premium")
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
                    // Features and pricing
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
    private let premiumFeatures = [
        "Unlimited friends",
        "Unlimited reminders",
        "Unlimited notes",
        "Unlimited medications",
        "Priority support",
        "Family sharing"
    ]

    // MARK: - Premium Content
    private var premiumContent: some View {
        VStack(spacing: 24) {
            // Premium features
            VStack(spacing: 12) {
                ForEach(Array(premiumFeatures.enumerated()), id: \.offset) { index, feature in
                    OnboardingFeatureCheckRow(text: feature, accentColor: accentColor)
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
            } else if products.isEmpty {
                // Fallback pricing display when products can't be loaded
                VStack(spacing: 12) {
                    pricingCard(
                        title: "Monthly",
                        price: "$4.99/month",
                        isSelected: true,
                        isBestValue: false
                    )
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.35),
                        value: hasAppeared
                    )

                    pricingCard(
                        title: "Annual",
                        price: "$39.99/year",
                        subtitle: "Save 33%",
                        isSelected: false,
                        isBestValue: true
                    )
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.4),
                        value: hasAppeared
                    )
                }
                .padding(.horizontal, AppDimensions.screenPadding)
            } else {
                // Real products from StoreKit
                VStack(spacing: 12) {
                    ForEach(Array(products.sorted { $0.price < $1.price }.enumerated()), id: \.element.id) { index, product in
                        productCard(product)
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 20)
                            .animation(
                                reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.05 + 0.35),
                                value: hasAppeared
                            )
                    }
                }
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

    // MARK: - Success View
    private var successView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.badgeGreen)

            Text("Welcome to Premium!")
                .font(.appTitle)
                .foregroundColor(.textPrimary)

            Text("You now have access to all premium features")
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
        isBestValue: Bool
    ) -> some View {
        VStack(spacing: 0) {
            if isBestValue {
                Text("BEST VALUE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(accentColor)
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
                            .foregroundColor(accentColor)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(accentColor)
                }
            }
            .padding(20)
            .background(Color.cardBackground)
            .cornerRadius(AppDimensions.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius)
                    .stroke(isSelected ? accentColor : Color.cardBackgroundLight, lineWidth: isSelected ? 2 : 1)
            )
        }
    }

    // MARK: - Product Card
    private func productCard(_ product: Product) -> some View {
        let isSelected = selectedProduct?.id == product.id
        let isAnnual = product.id.contains("annual")

        return Button {
            selectedProduct = product
        } label: {
            pricingCard(
                title: isAnnual ? "Annual" : "Monthly",
                price: product.displayPrice + (isAnnual ? "/year" : "/month"),
                subtitle: isAnnual ? "Save 33%" : nil,
                isSelected: isSelected,
                isBestValue: isAnnual
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
                    backgroundColor: accentColor,
                    action: onContinue
                )
            } else {
                // Subscribe button
                PrimaryButton(
                    title: "Subscribe",
                    isLoading: purchaseState == .purchasing,
                    backgroundColor: accentColor,
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
                // Select annual by default
                selectedProduct = storeProducts.first { $0.id.contains("annual") } ?? storeProducts.first
                purchaseState = .idle
            }
        } catch {
            print("Failed to load products: \(error)")
            await MainActor.run {
                purchaseState = .idle
            }
        }
    }

    private func purchase() {
        guard let product = selectedProduct ?? products.first else {
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
                            onboardingData.isPremium = true
                            onboardingData.subscriptionProductId = product.id
                            purchaseState = .success
                        }

                    case .unverified(_, let error):
                        await MainActor.run {
                            errorMessage = "Purchase verification failed. Please try again."
                            purchaseState = .idle
                        }
                        print("Unverified transaction: \(error)")
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
                print("Purchase error: \(error)")
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
                            onboardingData.isPremium = true
                            onboardingData.subscriptionProductId = transaction.productID
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
            print("Restore error: \(error)")
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
