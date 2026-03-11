//
//  StoreKitManager.swift
//  Sketchly
//
//  StoreKit 2 implementation for in-app purchases and subscriptions
//

import Foundation
import StoreKit

// MARK: - Product Identifiers
enum StoreKitProductID: String, CaseIterable {
    case weekly = "com.appfactory.sketchlydrawwithaifeedback.subscription.weekly"
    case monthly = "com.appfactory.sketchlydrawwithaifeedback.subscription.monthly"
    case yearly = "com.appfactory.sketchlydrawwithaifeedback.subscription.yearly"
    case lifetime = "com.appfactory.sketchlydrawwithaifeedback.subscription.lifetime"

    var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        case .lifetime: return "Lifetime"
        }
    }

    var isSubscription: Bool {
        true
    }

    static var subscriptionIDs: [String] {
        [weekly.rawValue, monthly.rawValue, yearly.rawValue, lifetime.rawValue]
    }

    static var allIDs: [String] {
        allCases.map { $0.rawValue }
    }
}

// MARK: - Purchase State
enum PurchaseState: Equatable {
    case idle
    case loading
    case purchasing
    case purchased
    case failed(String)
    case pending
    case cancelled
    case noNetwork
}

// MARK: - StoreKit Error
enum StoreKitError: LocalizedError {
    case productNotFound
    case purchaseFailed(Error)
    case verificationFailed
    case userCancelled
    case pending
    case noNetwork
    case unknown

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "The requested product could not be found."
        case .purchaseFailed(let error):
            return "Purchase failed: \(error.localizedDescription)"
        case .verificationFailed:
            return "Purchase verification failed. Please contact support."
        case .userCancelled:
            return "Purchase was cancelled."
        case .pending:
            return "Purchase is pending approval."
        case .noNetwork:
            return "No network connection. Please check your internet and try again."
        case .unknown:
            return "An unknown error occurred."
        }
    }
}

// MARK: - StoreKit Manager
@MainActor
@Observable
final class StoreKitManager {
    // MARK: - Properties

    private(set) var subscriptions: [Product] = []
    private(set) var nonConsumables: [Product] = []
    private(set) var allProducts: [Product] = []

    private(set) var purchaseState: PurchaseState = .idle
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?

    private(set) var purchasedSubscriptions: Set<String> = []
    private(set) var purchasedNonConsumables: Set<String> = []

    private var updateListenerTask: Task<Void, Error>?

    // MARK: - Computed Properties

    var hasActiveSubscription: Bool {
        !purchasedSubscriptions.isEmpty
    }

    var isPremium: Bool {
        hasActiveSubscription || !purchasedNonConsumables.isEmpty
    }

    var currentSubscriptionProductID: String? {
        purchasedSubscriptions.first
    }

    // MARK: - Initialization

    init() {
        updateListenerTask = listenForTransactions()

        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    // MARK: - Product Loading

    func loadProducts() async {
        isLoading = true
        errorMessage = nil

        do {
            let storeProducts = try await Product.products(for: StoreKitProductID.allIDs)

            var subs: [Product] = []
            var nonCons: [Product] = []

            for product in storeProducts {
                switch product.type {
                case .autoRenewable, .nonRenewable:
                    subs.append(product)
                case .nonConsumable:
                    nonCons.append(product)
                default:
                    break
                }
            }

            subscriptions = subs.sorted { $0.price < $1.price }
            nonConsumables = nonCons
            allProducts = subscriptions + nonConsumables

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            purchaseState = .failed(errorMessage ?? "Unknown error")
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> Transaction? {
        purchaseState = .purchasing
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updatePurchasedProducts()
                await transaction.finish()
                purchaseState = .purchased
                return transaction

            case .userCancelled:
                purchaseState = .cancelled
                throw StoreKitError.userCancelled

            case .pending:
                purchaseState = .pending
                throw StoreKitError.pending

            @unknown default:
                purchaseState = .failed("Unknown purchase result")
                throw StoreKitError.unknown
            }
        } catch StoreKitError.userCancelled {
            purchaseState = .cancelled
            throw StoreKitError.userCancelled
        } catch StoreKitError.pending {
            purchaseState = .pending
            throw StoreKitError.pending
        } catch {
            let errorMsg = error.localizedDescription
            purchaseState = .failed(errorMsg)
            errorMessage = errorMsg
            throw StoreKitError.purchaseFailed(error)
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        purchaseState = .loading
        errorMessage = nil

        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
            purchaseState = isPremium ? .purchased : .idle
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            purchaseState = .failed(errorMessage ?? "Unknown error")
        }
    }

    // MARK: - Transaction Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreKitError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Update Purchased Products

    func updatePurchasedProducts() async {
        var purchasedSubs: Set<String> = []
        var purchasedNonCons: Set<String> = []

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                switch transaction.productType {
                case .autoRenewable, .nonRenewable:
                    if transaction.revocationDate == nil {
                        purchasedSubs.insert(transaction.productID)
                    }
                case .nonConsumable:
                    if transaction.revocationDate == nil {
                        purchasedNonCons.insert(transaction.productID)
                    }
                default:
                    break
                }
            } catch {
                print("Failed to verify transaction: \(error)")
            }
        }

        self.purchasedSubscriptions = purchasedSubs
        self.purchasedNonConsumables = purchasedNonCons
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { [weak self] in
            for await result in Transaction.updates {
                do {
                    let transaction: Transaction
                    switch result {
                    case .unverified:
                        throw StoreKitError.verificationFailed
                    case .verified(let safe):
                        transaction = safe
                    }

                    await self?.updatePurchasedProducts()
                    await transaction.finish()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }

    // MARK: - Subscription Status

    func getSubscriptionStatus() async -> Product.SubscriptionInfo.Status? {
        guard let productID = currentSubscriptionProductID,
              let product = subscriptions.first(where: { $0.id == productID }) else {
            return nil
        }

        do {
            let statuses = try await product.subscription?.status ?? []
            return statuses.first
        } catch {
            print("Failed to get subscription status: \(error)")
            return nil
        }
    }

    func getExpirationDate() async -> Date? {
        guard let status = await getSubscriptionStatus() else { return nil }

        do {
            let transaction = try checkVerified(status.transaction)
            return transaction.expirationDate
        } catch {
            return nil
        }
    }

    func isSubscriptionExpired() async -> Bool {
        guard let expirationDate = await getExpirationDate() else {
            return true
        }
        return expirationDate < Date()
    }

    // MARK: - Product Helpers

    func product(for id: StoreKitProductID) -> Product? {
        allProducts.first { $0.id == id.rawValue }
    }

    func formattedPrice(for product: Product) -> String {
        product.displayPrice
    }

    func pricePerPeriod(for product: Product) -> String? {
        guard let subscription = product.subscription else { return nil }

        let unit = subscription.subscriptionPeriod.unit
        let value = subscription.subscriptionPeriod.value

        switch unit {
        case .day:
            return value == 7 ? "/week" : "/\(value) days"
        case .week:
            return value == 1 ? "/week" : "/\(value) weeks"
        case .month:
            return value == 1 ? "/month" : "/\(value) months"
        case .year:
            return value == 1 ? "/year" : "/\(value) years"
        @unknown default:
            return nil
        }
    }

    // MARK: - Reset State

    func resetState() {
        purchaseState = .idle
        errorMessage = nil
    }
}

// MARK: - Product Extension for Display
extension Product {
    var periodLabel: String {
        guard let subscription = subscription else {
            return "One-time purchase"
        }

        let unit = subscription.subscriptionPeriod.unit
        let value = subscription.subscriptionPeriod.value

        switch unit {
        case .day:
            if value == 7 { return "per week" }
            return value == 1 ? "per day" : "per \(value) days"
        case .week:
            return value == 1 ? "per week" : "per \(value) weeks"
        case .month:
            return value == 1 ? "per month" : "per \(value) months"
        case .year:
            return value == 1 ? "per year" : "per \(value) years"
        @unknown default:
            return ""
        }
    }

    var savingsLabel: String? {
        guard let subscription = subscription else { return nil }
        switch subscription.subscriptionPeriod.unit {
        case .year:
            return "Best Value - Save 50%"
        default:
            return nil
        }
    }

    var isPopular: Bool {
        guard let subscription = subscription else { return false }
        return subscription.subscriptionPeriod.unit == .year
    }
}
