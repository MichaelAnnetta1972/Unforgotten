import Foundation
import StoreKit

// MARK: - Subscription Manager
/// Central service for managing StoreKit 2 subscriptions.
/// Listens for transaction updates, verifies entitlements on launch,
/// and provides purchase/restore functionality.
@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    // MARK: - Published State
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var subscriptionTier: SubscriptionTier = .free
    @Published private(set) var isLoading = false

    // MARK: - Product IDs
    static let productIds: Set<String> = [
        "com.unforgotten.premium.monthly",
        "com.unforgotten.premium.annual",
        "com.unforgotten.family.monthly",
        "com.unforgotten.family.annual"
    ]

    // MARK: - Private
    private var transactionListener: Task<Void, Error>?

    private init() {
        // Start listening for transaction updates immediately
        transactionListener = listenForTransactions()
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Transaction Listener
    /// Listens for transaction updates from Apple.
    /// This catches renewals, cancellations, refunds, revocations,
    /// and purchases made on other devices or through the App Store directly.
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { return }

                switch result {
                case .verified(let transaction):
                    // Always finish verified transactions
                    await transaction.finish()
                    await self.refreshSubscriptionStatus()

                    #if DEBUG
                    print("📦 Transaction update received: \(transaction.productID) — revocationDate: \(String(describing: transaction.revocationDate))")
                    #endif

                case .unverified(let transaction, let error):
                    #if DEBUG
                    print("⚠️ Unverified transaction update: \(transaction.productID) — \(error)")
                    #endif
                    // Still refresh — the entitlement check will handle it
                    await self.refreshSubscriptionStatus()
                }
            }
        }
    }

    // MARK: - Load Products
    /// Fetches available products from the App Store
    func loadProducts() async {
        guard products.isEmpty else {
            #if DEBUG
            print("🛒 Products already loaded: \(products.map { $0.id })")
            #endif
            return
        }

        isLoading = true
        do {
            let storeProducts = try await Product.products(for: Self.productIds)
            #if DEBUG
            print("🛒 Loaded \(storeProducts.count) products: \(storeProducts.map { $0.id })")
            #endif
            // Sort: premium before family, monthly before annual
            products = storeProducts.sorted { a, b in
                if a.id.contains("premium") && b.id.contains("family") { return true }
                if a.id.contains("family") && b.id.contains("premium") { return false }
                if a.id.contains("monthly") && b.id.contains("annual") { return true }
                return false
            }
        } catch {
            #if DEBUG
            print("❌ Failed to load products: \(error)")
            #endif
        }
        isLoading = false
    }

    // MARK: - Purchase
    /// Initiates a purchase for the given product
    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                await transaction.finish()
                await refreshSubscriptionStatus()
                return transaction

            case .unverified(_, let error):
                throw SubscriptionError.verificationFailed(error)
            }

        case .userCancelled:
            return nil

        case .pending:
            throw SubscriptionError.purchasePending

        @unknown default:
            return nil
        }
    }

    // MARK: - Restore Purchases
    /// Syncs with the App Store and refreshes entitlements
    func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshSubscriptionStatus()
    }

    // MARK: - Refresh Subscription Status
    /// Checks current entitlements from Apple and updates the local subscription tier.
    /// This is the single source of truth — called on launch, after purchases,
    /// and whenever Transaction.updates fires.
    func refreshSubscriptionStatus() async {
        var highestTier: SubscriptionTier = .free
        var activeProductIDs: Set<String> = []

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }

            // Skip revoked transactions
            if transaction.revocationDate != nil { continue }

            // Check if this is one of our products
            guard Self.productIds.contains(transaction.productID) else { continue }

            activeProductIDs.insert(transaction.productID)

            // Determine tier from product ID
            let tier: SubscriptionTier = transaction.productID.contains("family") ? .familyPlus : .premium

            // Keep the highest tier
            if tier == .familyPlus {
                highestTier = .familyPlus
            } else if tier == .premium && highestTier == .free {
                highestTier = .premium
            }
        }

        purchasedProductIDs = activeProductIDs
        subscriptionTier = highestTier

        // Persist to UserDefaults so AppState can read it synchronously
        UserDefaults.standard.set(highestTier.rawValue, forKey: "user_subscription_tier")

        #if DEBUG
        print("🔄 Subscription status refreshed — tier: \(highestTier.displayName), active products: \(activeProductIDs)")
        #endif
    }

    // MARK: - Helpers

    /// Get products filtered by tier
    func products(for tier: SubscriptionTier) -> [Product] {
        let prefix: String
        switch tier {
        case .premium: prefix = "com.unforgotten.premium"
        case .familyPlus: prefix = "com.unforgotten.family"
        case .free: return []
        }
        return products.filter { $0.id.hasPrefix(prefix) }
    }

    /// Get a specific product by billing period
    func product(for tier: SubscriptionTier, period: BillingPeriod) -> Product? {
        let suffix = period == .annual ? "annual" : "monthly"
        return products(for: tier).first { $0.id.contains(suffix) }
    }

    /// Check if a product is currently purchased
    func isProductPurchased(_ productID: String) -> Bool {
        purchasedProductIDs.contains(productID)
    }

    // MARK: - Billing Period
    enum BillingPeriod {
        case monthly
        case annual
    }
}

// MARK: - Subscription Errors
enum SubscriptionError: LocalizedError {
    case verificationFailed(Error)
    case purchasePending
    case noProductFound

    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "Purchase verification failed. Please try again."
        case .purchasePending:
            return "Your purchase is pending approval."
        case .noProductFound:
            return "The selected subscription could not be found."
        }
    }
}
