import Foundation
import Security
import StoreKit

/// Anonymous studio analytics. Events are queued locally and never block app flows.
actor StudioAnalytics {
    static let shared = StudioAnalytics()

    private let endpoint = URL(string: "https://analytics.haoapps.tech/v1/events")!
    private let appID = "dupes"
    private let appKey = "3c978af4aadb1faab1ab19c9a512b16bb51428f0fd900043"
    private let queueKey = "studio_analytics_queue_v1"
    private let firstOpenKey = "studio_analytics_first_open_sent_v1"
    private var sessionID = UUID().uuidString.lowercased()
    private var isSending = false

    func track(_ name: Event, properties: [String: String] = [:]) async {
        var enriched = properties
        enriched["analytics_environment"] = enriched["analytics_environment"] ?? runtimeEnvironment
        if enriched["storefront_region"] == nil, let storefront = await Storefront.current {
            enriched["storefront_region"] = storefront.countryCode
        }
        enriched["device_region"] = enriched["device_region"]
            ?? Locale.current.region?.identifier
            ?? "unknown"

        var queue = loadQueue()
        queue.append(AnalyticsEvent(
            eventID: UUID().uuidString.lowercased(),
            event: name.rawValue,
            anonymousUserID: InstallationIdentity.shared.id,
            sessionID: sessionID,
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            buildNumber: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            platform: "ios",
            occurredAt: ISO8601DateFormatter().string(from: Date()),
            properties: enriched
        ))
        saveQueue(Array(queue.suffix(200)))
        await flush()
    }

    func trackAppBecameActive() async {
        sessionID = UUID().uuidString.lowercased()
        if !UserDefaults.standard.bool(forKey: firstOpenKey) {
            await track(.firstOpen)
            UserDefaults.standard.set(true, forKey: firstOpenKey)
        }
        await track(.appOpen)
    }

    func flush() async {
        guard !isSending else { return }
        let queue = loadQueue()
        guard !queue.isEmpty else { return }
        isSending = true
        defer { isSending = false }

        let batch = Array(queue.prefix(50))
        do {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.timeoutInterval = 12
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(appID, forHTTPHeaderField: "X-App-ID")
            request.setValue(appKey, forHTTPHeaderField: "X-App-Key")
            request.httpBody = try JSONEncoder().encode(EventBatch(events: batch))
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return }
            saveQueue(Array(queue.dropFirst(batch.count)))
            if queue.count > batch.count { await flush() }
        } catch {
            #if DEBUG
            print("[StudioAnalytics] Upload deferred: \(error.localizedDescription)")
            #endif
        }
    }

    enum Event: String {
        case appOpen = "app_open"
        case firstOpen = "first_open"
        case onboardingCompleted = "onboarding_completed"
        case paywallViewed = "paywall_viewed"
        case trialStarted = "trial_started"
        case purchaseCompleted = "purchase_completed"
    }

    private var runtimeEnvironment: String {
        #if DEBUG
        return "sandbox"
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" ? "sandbox" : "production"
        #endif
    }

    private func loadQueue() -> [AnalyticsEvent] {
        guard let data = UserDefaults.standard.data(forKey: queueKey) else { return [] }
        return (try? JSONDecoder().decode([AnalyticsEvent].self, from: data)) ?? []
    }

    private func saveQueue(_ queue: [AnalyticsEvent]) {
        if queue.isEmpty {
            UserDefaults.standard.removeObject(forKey: queueKey)
        } else if let data = try? JSONEncoder().encode(queue) {
            UserDefaults.standard.set(data, forKey: queueKey)
        }
    }
}

private final class InstallationIdentity: @unchecked Sendable {
    static let shared = InstallationIdentity()
    private let service = "com.huangxiaohao.dupes.analytics"
    private let account = "installationId"

    var id: String {
        if let existing = read() { return existing }
        let value = UUID().uuidString.lowercased()
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
        return value
    }

    private func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

private struct EventBatch: Encodable { let events: [AnalyticsEvent] }

private struct AnalyticsEvent: Codable {
    let eventID: String
    let event: String
    let anonymousUserID: String
    let sessionID: String
    let appVersion: String
    let buildNumber: String
    let platform: String
    let occurredAt: String
    let properties: [String: String]

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
        case event
        case anonymousUserID = "anonymous_user_id"
        case sessionID = "session_id"
        case appVersion = "app_version"
        case buildNumber = "build_number"
        case platform
        case occurredAt = "occurred_at"
        case properties
    }
}
