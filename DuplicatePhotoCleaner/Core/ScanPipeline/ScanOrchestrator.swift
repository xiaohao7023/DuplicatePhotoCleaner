import Photos
import SwiftUI

enum ScanCategory: String, CaseIterable, Identifiable {
    case duplicates = "Duplicates"
    case videos = "Videos"
    case screenshots = "Screenshots"
    case blurry = "Blurry"
    case similar = "Similar"
    case unfavorites = "Unfavorites"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .duplicates: return String(localized: "Duplicates")
        case .videos: return String(localized: "Videos")
        case .screenshots: return String(localized: "Screenshots")
        case .blurry: return String(localized: "Blurry")
        case .similar: return String(localized: "Similar")
        case .unfavorites: return String(localized: "Unfavorites")
        }
    }
    var icon: String {
        switch self {
        case .duplicates: return "doc.on.doc.fill"
        case .similar: return "square.stack.3d.up.fill"
        case .blurry: return "eye.trianglebadge.exclamationmark"
        case .screenshots: return "camera.viewfinder"
        case .videos: return "film.fill"
        case .unfavorites: return "heart.slash.fill"
        }
    }
    var color: Color {
        switch self {
        case .duplicates: return .appPrimary
        case .similar: return .appTeal
        case .blurry: return .appWarning
        case .screenshots: return .appPurple
        case .videos: return .appCamel
        case .unfavorites: return .appRose
        }
    }
}

@Observable
class CategoryScanState {
    var isScanning = false
    var isDone = false
    var progress: Double = 0
    var count: Int = 0
    var sizeBytes: Int64 = 0
    var processedPhotos: Int = 0
    var totalPhotos: Int = 0

    func reset() {
        isScanning = false; isDone = false; progress = 0; count = 0; sizeBytes = 0
        processedPhotos = 0; totalPhotos = 0
    }

    func update(fromDuplicateGroups groups: [DuplicateGroup]) {
        count = groups.reduce(0) { $0 + $1.assets.count - 1 }
        sizeBytes = groups.reduce(Int64(0)) { total, g in
            total + g.assets.filter { $0.localIdentifier != g.recommended.localIdentifier }.reduce(Int64(0)) { $0 + $1.fileSizeBytes }
        }
    }

    func update(fromSimilarGroups groups: [SimilarGroup]) {
        count = groups.reduce(0) { $0 + $1.assets.count - 1 }
        sizeBytes = groups.reduce(Int64(0)) { total, g in
            total + g.assets.filter { $0.localIdentifier != g.recommended.localIdentifier }.reduce(Int64(0)) { $0 + $1.fileSizeBytes }
        }
    }

    func update(fromBlurryPhotos photos: [PhotoQuality]) {
        count = photos.count
        sizeBytes = photos.reduce(Int64(0)) { $0 + $1.fileSize }
    }

    func update(fromScreenshotGroups groups: [ScreenshotGroupData]) {
        count = groups.reduce(0) { $0 + $1.assets.count }
        sizeBytes = groups.reduce(Int64(0)) { $0 + $1.totalSize }
    }

    func update(fromVideos videos: [PHAsset]) {
        count = videos.count
        sizeBytes = videos.reduce(Int64(0)) { $0 + $1.fileSizeBytes }
    }

    func update(fromUnfavorites assets: [PHAsset]) {
        count = assets.count
        sizeBytes = assets.reduce(Int64(0)) { $0 + $1.fileSizeBytes }
    }
}

actor ScanOrchestrator {
    private let photoLibrary = PhotoLibraryManager()
    private let duplicateDetector = DuplicateDetector()
    private let similarityGrouper = SimilarityGrouper()
    private let qualityAnalyzer = QualityAnalyzer()
    private let screenshotClassifier = ScreenshotClassifier()
    private let unfavoritesFetcher = UnfavoritesFetcher()

    // Cached library fetch — avoid fetching the entire library 5 times
    private var cachedPhotos: [PHAsset]?
    private var cachedPhotosIncludeVideos: Bool?

    private func fetchPhotosCached(includeVideos: Bool) async -> [PHAsset] {
        if let cached = cachedPhotos, cachedPhotosIncludeVideos == includeVideos {
            return cached
        }
        let photos = await photoLibrary.fetchAllPhotos(includeVideos: includeVideos)
        cachedPhotos = photos
        cachedPhotosIncludeVideos = includeVideos
        return photos
    }

    // MARK: - Individual scans

    func scanDuplicates(state: CategoryScanState, includeVideos: Bool = false) async -> [DuplicateGroup] {
        await MainActor.run { state.isScanning = true; state.isDone = false }
        let allPhotos = await fetchPhotosCached(includeVideos: includeVideos)
        let results = await duplicateDetector.detect(in: allPhotos) { p in
            let rounded = (p * 200).rounded() / 200
            Task { @MainActor in state.progress = rounded }
        }
        let count = results.reduce(0) { $0 + $1.assets.count - 1 }
        let bytes = results.reduce(Int64(0)) { total, group in
            total + group.assets.filter { $0 != group.recommended }.reduce(Int64(0)) { $0 + $1.fileSizeBytes }
        }
        await MainActor.run {
            state.count = count; state.sizeBytes = bytes
            state.isScanning = false; state.isDone = true; state.progress = 1
        }
        return results
    }

    func scanSimilar(state: CategoryScanState, includeVideos: Bool = false, fastFirstPass: Bool = false) async -> [SimilarGroup] {
        await MainActor.run { state.isScanning = true; state.isDone = false }
        let allPhotos = await fetchPhotosCached(includeVideos: includeVideos)
        let photos = fastFirstPass ? firstPassAssets(from: allPhotos, limit: 360) : allPhotos
        await MainActor.run { state.totalPhotos = photos.count; state.processedPhotos = 0 }
        let startedAt = Date()
        let results = await similarityGrouper.group(
            assets: photos,
            targetDimension: fastFirstPass ? 256 : 512
        ) { p in
            let rounded = (p * 200).rounded() / 200
            Task { @MainActor in
                state.progress = rounded
                // Feature extraction occupies the first 70% of this pipeline.
                state.processedPhotos = min(state.totalPhotos, Int((rounded / 0.7) * Double(state.totalPhotos)))
            }
        }
        if fastFirstPass { await ensureVisibleScanDuration(since: startedAt) }
        let count = results.reduce(0) { $0 + $1.assets.count - 1 }
        let bytes = results.reduce(Int64(0)) { total, group in
            total + group.assets.filter { $0 != group.recommended }.reduce(Int64(0)) { $0 + $1.fileSizeBytes }
        }
        await MainActor.run {
            state.count = count; state.sizeBytes = bytes
            state.isScanning = false; state.isDone = true; state.progress = 1
            state.processedPhotos = state.totalPhotos
        }
        return results
    }

    func scanBlurry(state: CategoryScanState, includeVideos: Bool = false, fastFirstPass: Bool = false) async -> [PhotoQuality] {
        await MainActor.run { state.isScanning = true; state.isDone = false }
        let allPhotos = await fetchPhotosCached(includeVideos: includeVideos)
        let photos = fastFirstPass ? firstPassAssets(from: allPhotos, limit: 280) : allPhotos
        await MainActor.run { state.totalPhotos = photos.count; state.processedPhotos = 0 }
        let startedAt = Date()
        let results = await qualityAnalyzer.findBlurry(
            assets: photos,
            targetDimension: fastFirstPass ? 256 : 512
        ) { p in
            let rounded = (p * 200).rounded() / 200
            Task { @MainActor in
                state.progress = rounded
                state.processedPhotos = min(state.totalPhotos, Int(rounded * Double(state.totalPhotos)))
            }
        }
        if fastFirstPass { await ensureVisibleScanDuration(since: startedAt) }
        let bytes = results.reduce(Int64(0) as Int64) { $0 + $1.fileSize }
        await MainActor.run {
            state.count = results.count; state.sizeBytes = bytes
            state.isScanning = false; state.isDone = true; state.progress = 1
            state.processedPhotos = state.totalPhotos
        }
        return results
    }

    private func firstPassAssets(from assets: [PHAsset], limit: Int) -> [PHAsset] {
        Array(assets.sorted {
            ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast)
        }.prefix(limit))
    }

    private func ensureVisibleScanDuration(since start: Date) async {
        let remaining = 0.9 - Date().timeIntervalSince(start)
        if remaining > 0 { try? await Task.sleep(for: .seconds(remaining)) }
    }

    func scanScreenshots(state: CategoryScanState) async -> [ScreenshotGroupData] {
        await MainActor.run { state.isScanning = true; state.isDone = false; state.progress = 0.5 }
        let screenshots = await screenshotClassifier.fetchScreenshots()
        let results = await screenshotClassifier.groupByTime(screenshots)
        let count = results.reduce(0) { $0 + $1.assets.count }
        let bytes = results.reduce(Int64(0)) { $0 + $1.totalSize }
        await MainActor.run {
            state.count = count; state.sizeBytes = bytes
            state.isScanning = false; state.isDone = true; state.progress = 1
        }
        return results
    }

    func scanVideos(state: CategoryScanState) async -> [PHAsset] {
        await MainActor.run { state.isScanning = true; state.isDone = false; state.progress = 0.5 }
        let videos = await photoLibrary.fetchVideos()
        let sorted = videos.sorted { $0.fileSizeBytes > $1.fileSizeBytes }
        let bytes = sorted.reduce(Int64(0)) { $0 + $1.fileSizeBytes }
        await MainActor.run {
            state.count = sorted.count; state.sizeBytes = bytes
            state.isScanning = false; state.isDone = true; state.progress = 1
        }
        return sorted
    }

    func scanUnfavorites(state: CategoryScanState, includeVideos: Bool = false) async -> [PHAsset] {
        await MainActor.run { state.isScanning = true; state.isDone = false; state.progress = 0.5 }
        let results = await unfavoritesFetcher.fetchUnfavorites(includeVideos: includeVideos)
        let bytes = results.reduce(Int64(0)) { $0 + $1.fileSizeBytes }
        await MainActor.run {
            state.count = results.count; state.sizeBytes = bytes
            state.isScanning = false; state.isDone = true; state.progress = 1
        }
        return results
    }

    func fetchUnfavoritesStatistics(includeVideos: Bool = false) async -> (total: Int, favorited: Int, unfavorited: Int) {
        await unfavoritesFetcher.fetchStatistics(includeVideos: includeVideos)
    }
}
