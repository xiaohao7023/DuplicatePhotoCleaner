import SwiftUI

@main
struct DuplicatePhotoCleanerApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .preferredColorScheme(.light)
        }
    }
}

@Observable
class AppState {
    var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }
    var currentScanResult: ScanResult?

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
        case .recentlyDeleted: return "Move to Recently Deleted"
        case .permanent: return "Delete Permanently"
        case .askEveryTime: return "Ask Every Time"
        }
    }

    var description: String {
        switch self {
        case .recentlyDeleted: return "Recoverable in 30 days"
        case .permanent: return "Cannot be undone"
        case .askEveryTime: return "Choose each time you delete"
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
