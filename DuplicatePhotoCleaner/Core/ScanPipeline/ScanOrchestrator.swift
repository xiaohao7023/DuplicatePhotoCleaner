import Photos
import SwiftUI

enum ScanCategory: String, CaseIterable, Identifiable {
    case duplicates = "Duplicates"
    case videos = "Videos"
    case screenshots = "Screenshots"
    case blurry = "Blurry"
    case similar = "Similar"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .duplicates: return "doc.on.doc.fill"
        case .similar: return "square.stack.3d.up.fill"
        case .blurry: return "eye.trianglebadge.exclamationmark"
        case .screenshots: return "camera.viewfinder"
        case .videos: return "film.fill"
        }
    }
    var color: Color {
        switch self {
        case .duplicates: return .appPrimary
        case .similar: return .appTeal
        case .blurry: return .appWarning
        case .screenshots: return .appPurple
        case .videos: return .appCamel
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

    func reset() {
        isScanning = false; isDone = false; progress = 0; count = 0; sizeBytes = 0
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
}

actor ScanOrchestrator {
    private let photoLibrary = PhotoLibraryManager()
    private let duplicateDetector = DuplicateDetector()
    private let similarityGrouper = SimilarityGrouper()
    private let qualityAnalyzer = QualityAnalyzer()
    private let screenshotClassifier = ScreenshotClassifier()

    // MARK: - Individual scans

    func scanDuplicates(state: CategoryScanState, includeVideos: Bool = false) async -> [DuplicateGroup] {
        await MainActor.run { state.isScanning = true; state.isDone = false }
        let allPhotos = await photoLibrary.fetchAllPhotos(includeVideos: includeVideos)
        let results = await duplicateDetector.detect(in: allPhotos) { p in
            Task { @MainActor in state.progress = p }
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

    func scanSimilar(state: CategoryScanState, includeVideos: Bool = false) async -> [SimilarGroup] {
        await MainActor.run { state.isScanning = true; state.isDone = false }
        let allPhotos = await photoLibrary.fetchAllPhotos(includeVideos: includeVideos)
        let results = await similarityGrouper.group(assets: allPhotos) { p in
            Task { @MainActor in state.progress = p }
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

    func scanBlurry(state: CategoryScanState, includeVideos: Bool = false) async -> [PhotoQuality] {
        await MainActor.run { state.isScanning = true; state.isDone = false }
        let allPhotos = await photoLibrary.fetchAllPhotos(includeVideos: includeVideos)
        let results = await qualityAnalyzer.findBlurry(assets: allPhotos) { p in
            Task { @MainActor in state.progress = p }
        }
        let bytes = results.reduce(Int64(0) as Int64) { $0 + $1.fileSize }
        await MainActor.run {
            state.count = results.count; state.sizeBytes = bytes
            state.isScanning = false; state.isDone = true; state.progress = 1
        }
        return results
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

    // MARK: - Full scan (legacy)

    func runScan(progress: ScanProgressState, includeVideos: Bool = false) async -> ScanResult {
        await MainActor.run { progress.isScanning = true; progress.isCancelled = false }

        await MainActor.run { progress.phase = .screenshots; progress.overallProgress = 0.1 }
        let screenshots = await screenshotClassifier.fetchScreenshots()
        let ssGroups = await screenshotClassifier.groupByTime(screenshots)
        await MainActor.run { progress.overallProgress = 0.15 }

        await MainActor.run { progress.phase = .duplicates; progress.overallProgress = 0.2 }
        let allPhotos = await photoLibrary.fetchAllPhotos(includeVideos: includeVideos)
        let dupGroups = await duplicateDetector.detect(in: allPhotos) { p in
            Task { @MainActor in progress.phaseProgress = p; progress.overallProgress = 0.2 + p * 0.3 }
        }
        await MainActor.run { progress.overallProgress = 0.5 }

        await MainActor.run { progress.phase = .similar; progress.overallProgress = 0.5 }
        let simGroups = await similarityGrouper.group(assets: allPhotos) { p in
            Task { @MainActor in progress.phaseProgress = p; progress.overallProgress = 0.5 + p * 0.3 }
        }
        await MainActor.run { progress.overallProgress = 0.8 }

        await MainActor.run { progress.phase = .blurry; progress.overallProgress = 0.8 }
        let blurPhotos = await qualityAnalyzer.findBlurry(assets: allPhotos) { p in
            Task { @MainActor in progress.phaseProgress = p; progress.overallProgress = 0.8 + p * 0.2 }
        }

        await MainActor.run {
            progress.overallProgress = 1.0; progress.phase = .completed; progress.isScanning = false
        }

        return ScanResult(
            duplicateGroups: dupGroups, similarGroups: simGroups,
            blurryPhotos: blurPhotos, screenshotGroups: ssGroups
        )
    }
}
