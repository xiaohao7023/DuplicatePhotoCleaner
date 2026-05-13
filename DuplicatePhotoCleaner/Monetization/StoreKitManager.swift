import StoreKit

@Observable
class StoreKitManager {
    var products: [Product] = []
    var purchasedProductIDs: Set<String> = []
    var isLoading = false

    static let lifetimeID = "com.cleanupphone.lifetime"

    func loadProducts() async {
        isLoading = true; defer { isLoading = false }
        do {
            let loaded = try await withTimeout(seconds: 3) {
                try await Product.products(for: [Self.lifetimeID])
            }
            products = loaded
        } catch {}
    }

    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await updatePurchasedProducts()
                    return true
                }
                return false
            case .userCancelled, .pending: return false
            @unknown default: return false
            }
        } catch { return false }
    }

    func restorePurchases() async { await updatePurchasedProducts() }

    func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        do {
            try await withTimeout(seconds: 3) {
                for await result in Transaction.currentEntitlements {
                    if case .verified(let transaction) = result {
                        if transaction.revocationDate == nil { purchased.insert(transaction.productID) }
                    }
                }
            }
        } catch {}
        purchasedProductIDs = purchased
    }

    var lifetimeProduct: Product? { products.first { $0.id == Self.lifetimeID } }

    func startTransactionListener() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                await transaction.finish()
                if transaction.productID == Self.lifetimeID {
                    purchasedProductIDs.insert(transaction.productID)
                }
            }
        }
    }
}

private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError()
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

private struct TimeoutError: Error, LocalizedError {
    var errorDescription: String? { "Operation timed out" }
}
