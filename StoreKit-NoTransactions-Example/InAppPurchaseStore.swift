//
//  InAppPurchaseStore.swift
//  StoreKit-NoTransactions-Example
//
//  Created by Semeniuk Slava on 29.08.2023.
//

import StoreKit


@MainActor
final class InAppPurchaseStore: ObservableObject {

    private let userDefaults = UserDefaults.standard

    // MARK: Published
    @Published private(set) var isPurchasing = false
    @Published var subscriptions: [Product] = []
    @Published var hasActiveSubscription: Bool = false
    @Published var purchaseErrorAlert: Error?

    // MARK: Properties
    private var observeTransactionUpdatesTask: Task<Void, Never>?
    private var updateStateTask: Task<Void, Never>?

    private let cachedExpirationDateKey = "cachedExpirationDateKey"
    private let productIds: [String] = ["pro.annual", "pro.monthly"]

    // MARK: Init
    init() {
        self.updateStateTask = Task(priority: .high) {
            await updateState()
        }
        self.observeTransactionUpdatesTask = observeTransactionUpdates()
        Task(priority: .high) { try await requestProducts() }
    }

    deinit {
        observeTransactionUpdatesTask?.cancel()
        updateStateTask?.cancel()
    }

    // MARK: Interface
    func purchase(product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case let .success(.verified(transaction)):
                await updateState()
                await transaction.finish()
            case let .success(.unverified(_, error)):
                purchaseErrorAlert = error
            case .pending:
                break
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseErrorAlert = error
        }
    }

    // MARK: Helpers
    private func updateState() async {
        var transactions: [Transaction] = []
        // currentEntitlements - the latest transaction for each auto-renewable subscription that has a RenewalState of subscribed or inGracePeriod
        for await result in Transaction.currentEntitlements {
            switch result {
            case let .verified(transaction):
                transactions.append(transaction)
            case let .unverified(_, error):
                Analytics.reportUnverifiedTransaction(error)
            }
        }
        hasActiveSubscription = !transactions.isEmpty

        if let savedExpirationDate = userDefaults.object(forKey: cachedExpirationDateKey) as? Date,
           savedExpirationDate > Date.now, transactions.isEmpty {
            Analytics.reportMissingTransaction()
        }

        guard let validTransaction = transactions.first else { return }
        userDefaults.set(validTransaction.expirationDate, forKey: cachedExpirationDateKey)
    }

    private func requestProducts() async throws {
        subscriptions = try await Product.products(for: productIds).sorted { $0.price > $1.price }
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task.detached { [weak self] in
            guard let self else { return }
            for await result in Transaction.updates {
                guard case let .verified(transaction) = result else { continue }
                await self.updateState()
                await transaction.finish()
            }
        }
    }
}
