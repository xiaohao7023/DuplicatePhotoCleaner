import SwiftUI

@main
struct DuplicatePhotoCleanerApp: App {
    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasTrackedInitialOpen = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .preferredColorScheme(.light)
                .onAppear {
                    guard !hasTrackedInitialOpen else { return }
                    hasTrackedInitialOpen = true
                    Task { await StudioAnalytics.shared.trackAppBecameActive() }
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active, hasTrackedInitialOpen else { return }
                    Task { await StudioAnalytics.shared.trackAppBecameActive() }
                }
        }
    }
}

@Observable
class AppState {
    /// Persisted welcome offer deadline (10 min from first launch, not reset on cold start)
    let welcomeOfferDeadline: Date = {
        let key = "welcomeOfferDeadline"
        if let existing = UserDefaults.standard.object(forKey: key) as? Date {
            // 迁移：旧版本曾持久化 24h deadline，检测到仍是"未来 12h+ 以外"旧值则重置为 10 分钟
            if existing.timeIntervalSinceNow > 12 * 60 * 60 {
                let newDeadline = Date().addingTimeInterval(10 * 60)
                UserDefaults.standard.set(newDeadline, forKey: key)
                return newDeadline
            }
            return existing
        }
        let deadline = Date().addingTimeInterval(10 * 60)
        UserDefaults.standard.set(deadline, forKey: key)
        return deadline
    }()

    var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }
    var purchasedProductIDs: Set<String> = []
    var preloadedScanData: ScanResultData?

    /// Persists the fact that PhotoKit completed at least one full scan. This
    /// lets a later cold launch show the post-scan offer without waiting for a
    /// second full library scan to finish first.
    var hasCompletedSuccessfulScan = UserDefaults.standard.bool(forKey: "hasCompletedSuccessfulScan") {
        didSet { UserDefaults.standard.set(hasCompletedSuccessfulScan, forKey: "hasCompletedSuccessfulScan") }
    }

    var isShowingCleanupResultPaywall = false
    var lastCleanupFreedBytes: Int64 = 0
    var lastCleanupDeletedCount = 0

    // MARK: - 付费墙回收机制

    /// 用户点击 "Maybe Later" 的次数（UserDefaults 持久化）
    var paywallDismissCount: Int {
        get { UserDefaults.standard.integer(forKey: "paywallDismissCount") }
        set { UserDefaults.standard.set(newValue, forKey: "paywallDismissCount") }
    }

    /// 上次关闭付费墙后的删除次数
    var deletesSincePaywallDismiss: Int {
        get { UserDefaults.standard.integer(forKey: "deletesSincePaywallDismiss") }
        set { UserDefaults.standard.set(newValue, forKey: "deletesSincePaywallDismiss") }
    }

    /// 是否应该展示回收付费墙（关闭后删了 >= 2 次，且最多回收 2 次）
    var shouldShowReengagementPaywall: Bool {
        !isPurchased && paywallDismissCount < 2 && deletesSincePaywallDismiss >= 2
    }

    var isPurchased: Bool {
        !purchasedProductIDs.isDisjoint(with: StoreKitManager.premiumProductIDs)
    }

    // MARK: - V1.1: Free Tier Tracking

    /// 免费额度总量 (100MB in bytes)
    static let freeTierTotalQuota: Int64 = 100_000_000 // 100 MB (decimal, matches ByteCountFormatter .file style)

    /// 已使用的免费额度 (bytes)
    var freeDeletesUsedBytes: Int64 = UserDefaults.standard.object(forKey: "freeDeletesUsedBytes") as? Int64 ?? 0 {
        didSet { UserDefaults.standard.set(freeDeletesUsedBytes, forKey: "freeDeletesUsedBytes") }
    }

    /// 剩余免费额度 (bytes)
    var freeDeletesRemainingBytes: Int64 {
        max(0, Self.freeTierTotalQuota - freeDeletesUsedBytes)
    }

    /// 免费额度是否已用完
    var isFreeTierExhausted: Bool {
        freeDeletesRemainingBytes <= 0
    }

    /// 免费额度使用进度 (0.0 - 1.0)
    var freeQuotaProgress: Double {
        Double(freeDeletesUsedBytes) / Double(Self.freeTierTotalQuota)
    }

    /// 消耗免费额度，返回实际消耗量 (bytes)
    @discardableResult
    func consumeFreeQuota(bytes requestedBytes: Int64, deletedCount: Int = 1) -> Int64 {
        let actualConsumed = min(requestedBytes, freeDeletesRemainingBytes)
        freeDeletesUsedBytes += actualConsumed
        recordCleanup(freedBytes: actualConsumed, deletedCount: deletedCount)
        if deletedCount > 0, !isPurchased {
            lastCleanupFreedBytes = actualConsumed
            lastCleanupDeletedCount = deletedCount
            // 跟踪删除次数用于回收机制
            deletesSincePaywallDismiss += deletedCount
        }
        return actualConsumed
    }

    #if DEBUG
    /// 重置免费额度 (仅调试用)
    func resetFreeQuota() {
        freeDeletesUsedBytes = 0
        isShowingCleanupResultPaywall = false
        lastCleanupFreedBytes = 0
        lastCleanupDeletedCount = 0
    }

    /// 重置购买状态 (仅调试用，测试用)
    func resetPurchaseState() {
        purchasedProductIDs.removeAll()
    }
    #endif

    var deletePreference: DeletePreference {
        get {
            guard let raw = UserDefaults.standard.string(forKey: "deletePreference") else { return .askEveryTime }
            return DeletePreference(rawValue: raw) ?? .askEveryTime
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "deletePreference")
        }
    }

    var includeVideos = UserDefaults.standard.bool(forKey: "scanIncludeVideos") {
        didSet { UserDefaults.standard.set(includeVideos, forKey: "scanIncludeVideos") }
    }
    var includeICloud = UserDefaults.standard.bool(forKey: "scanIncludeICloud") {
        didSet { UserDefaults.standard.set(includeICloud, forKey: "scanIncludeICloud") }
    }

    // MARK: - V1.1: Total cleanable (set by Dashboard after scan, read by paywall)
    var totalCleanableBytes: Int64 = 0
    var totalCleanableCount: Int = 0

    // MARK: - Cumulative stats
    private static let freedBytesKey = "cumulativeFreedBytes"
    private static let deletedCountKey = "cumulativeDeletedCount"

    var cumulativeFreedBytes: Int64 {
        get { Int64(UserDefaults.standard.integer(forKey: Self.freedBytesKey)) }
        set { UserDefaults.standard.set(Int(newValue), forKey: Self.freedBytesKey) }
    }

    var cumulativeDeletedCount: Int {
        get { UserDefaults.standard.integer(forKey: Self.deletedCountKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.deletedCountKey) }
    }

    func recordCleanup(freedBytes: Int64, deletedCount: Int) {
        cumulativeFreedBytes += freedBytes
        cumulativeDeletedCount += deletedCount
    }
}

enum DeletePreference: String, CaseIterable, Identifiable {
    case recentlyDeleted = "recently_deleted"
    case permanent = "permanent"
    case askEveryTime = "ask_every_time"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .recentlyDeleted: return String(localized: "Move to Recently Deleted")
        case .permanent: return String(localized: "Delete Permanently")
        case .askEveryTime: return String(localized: "Ask Every Time")
        }
    }

    var description: String {
        switch self {
        case .recentlyDeleted: return String(localized: "Recoverable in 30 days")
        case .permanent: return String(localized: "Cannot be undone")
        case .askEveryTime: return String(localized: "Choose each time you delete")
        }
    }

    var icon: String {
        switch self {
        case .recentlyDeleted: return "trash.slash"
        case .permanent: return "trash.fill"
        case .askEveryTime: return "questionmark.circle"
        }
    }

    var iconColor: Color {
        switch self {
        case .recentlyDeleted: return .appPrimary
        case .permanent: return .appDanger
        case .askEveryTime: return .appTeal
        }
    }
}
