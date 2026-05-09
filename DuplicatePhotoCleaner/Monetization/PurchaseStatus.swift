import Foundation

enum PurchaseTier {
    case free, lifetime, yearly
}

@Observable
class PurchaseStatus {
    var currentTier: PurchaseTier = .free
    var isLoading = false
    var isPurchased: Bool { currentTier != .free }
}
