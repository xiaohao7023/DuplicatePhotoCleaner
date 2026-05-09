import Photos

private var fileSizeCache: [String: Int64] = [:]
private let cacheLock = NSLock()

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
        cacheLock.lock()
        if let cached = fileSizeCache[id] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        let resources = PHAssetResource.assetResources(for: self)
        let size = resources.first?.value(forKey: "fileSize") as? Int64 ?? 0

        cacheLock.lock()
        fileSizeCache[id] = size
        cacheLock.unlock()

        return size
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
}
