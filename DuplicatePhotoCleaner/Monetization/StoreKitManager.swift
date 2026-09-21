import StoreKit

@Observable
class StoreKitManager {
    /// 全局共享实例：商品/购买状态全 App 只维护一份，避免每个页面各自请求 App Store
    static let shared = StoreKitManager()

    var products: [Product] = []
    var purchasedProductIDs: Set<String> = []
    var isLoading = false
    var productLoadError: String?

    static let lifetimeID = "com.cleanupphone.lifetime"
    static let yearlyID = "com.dupes.premium.yearly"
    static let premiumProductIDs: Set<String> = [lifetimeID, yearlyID]

    func loadProducts() async {
        // 缓存：已成功加载过商品则直接复用，避免每次进入页面都重新请求 App Store
        if !products.isEmpty { return }
        isLoading = true
        productLoadError = nil
        defer { isLoading = false }

        for attempt in 0..<3 {
            do {
                // 与 updatePurchasedProducts 一致：StoreKit 网络调用强制 3s 超时，
                // 防止无网络/沙盒缓慢时 UI 长时间卡在 Loading。
                let loaded = try await withTimeout(seconds: 3) {
                    try await Product.products(for: Array(Self.premiumProductIDs))
                }
                products = loaded
                if lifetimeProduct != nil { return }
                productLoadError = "The lifetime offer is not available from the App Store yet."
            } catch {
                productLoadError = "Unable to connect to the App Store: \(error.localizedDescription)"
            }
            if attempt < 2 {
                try? await Task.sleep(for: .seconds(1.5))
            }
        }
    }

    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await trackCompletedPurchase(product: product, transaction: transaction)
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

    private func trackCompletedPurchase(product: Product, transaction: Transaction) async {
        let isFreeTrial: Bool
        if #available(iOS 17.2, *) {
            isFreeTrial = transaction.offer?.type == .introductory
                && transaction.offer?.paymentMode == .freeTrial
        } else {
            isFreeTrial = transaction.offerType == .introductory
                && product.subscription?.introductoryOffer?.paymentMode == .freeTrial
        }
        let actualPrice = transaction.price ?? product.price
        let currencyCode = transaction.currency?.identifier ?? product.priceFormatStyle.currencyCode
        await StudioAnalytics.shared.track(isFreeTrial ? .trialStarted : .purchaseCompleted, properties: [
            "analytics_environment": transaction.environment == .sandbox ? "sandbox" : "production",
            "product_id": product.id,
            "price": isFreeTrial ? "试用 0 元，续费价 \(product.displayPrice)" : product.displayPrice,
            "price_amount": NSDecimalNumber(decimal: isFreeTrial ? 0 : actualPrice).stringValue,
            "renewal_price": product.displayPrice,
            "currency_code": currencyCode,
            "offer_type": isFreeTrial ? "introductory_free_trial" : "direct",
            "transaction_id": String(transaction.id),
            "storefront_region": transaction.storefront.countryCode
        ])
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
    var yearlyProduct: Product? { products.first { $0.id == Self.yearlyID } }

    /// 直接拉起终身买断购买（无弹层付费墙，一步直达 App Store 支付）。
    /// 商品未加载时会自动补拉一次。调用方在成功后需同步 appState.purchasedProductIDs。
    func purchaseLifetimeDirect() async -> Bool {
        if lifetimeProduct == nil { await loadProducts() }
        guard let product = lifetimeProduct else { return false }
        return await purchase(product)
    }

    func startTransactionListener() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                await transaction.finish()
                if Self.premiumProductIDs.contains(transaction.productID) {
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
