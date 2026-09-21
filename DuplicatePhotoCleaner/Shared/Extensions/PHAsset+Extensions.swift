import Photos

// 使用简单的锁类来解决 Swift 6 并发问题
// SimpleLock is @unchecked Sendable — safe to access from any actor context.
// The nonisolated(unsafe) on cacheLock silences the cross-isolation access
// warning; the compiler considers it "unnecessary" for a Sendable constant
// but it IS required for access from nonisolated properties (known Swift issue).
private final class SimpleLock: @unchecked Sendable {
    private let _lock = NSLock()

    func performLocked<T>(_ body: () throws -> T) rethrows -> T {
        _lock.lock()
        defer { _lock.unlock() }
        return try body()
    }
}

nonisolated(unsafe) private var fileSizeCache: [String: Int64] = [:]
nonisolated(unsafe) private let cacheLock = SimpleLock()

extension PHAsset {
    nonisolated var fileSizeFormatted: String {
        let size = fileSizeBytes
        guard size > 0 else { return "Unknown" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    nonisolated var fileSizeBytes: Int64 {
        let id = localIdentifier
        return cacheLock.performLocked {
            if let cached = fileSizeCache[id] {
                return cached
            }

            let resources = PHAssetResource.assetResources(for: self)
            let size = resources
                .filter { $0.type != .adjustmentData }
                .reduce(Int64(0)) { total, resource in
                    total + (resource.value(forKey: "fileSize") as? Int64 ?? 0)
                }

            fileSizeCache[id] = size
            return size
        }
    }

    nonisolated var resolutionFormatted: String {
        "\(pixelWidth) x \(pixelHeight)"
    }

    nonisolated var creationDateFormatted: String {
        guard let date = creationDate else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    nonisolated var durationFormatted: String {
        guard duration > 0 else { return "" }
        let m = Int(duration) / 60
        let s = Int(duration) % 60
        return String(format: "%d:%02d", m, s)
    }
}
