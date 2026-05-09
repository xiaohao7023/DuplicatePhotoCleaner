import Photos
import SwiftUI

enum ScanCategory: String, CaseIterable, Identifiable {
    case duplicates = "Duplicates"
    case similar = "Similar"
    case blurry = "Blurry"
    case screenshots = "Screenshots"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .duplicates: return "doc.on.doc.fill"
        case .similar: return "square.stack.3d.up.fill"
        case .blurry: return "eye.trianglebadge.exclamationmark"
        case .screenshots: return "camera.viewfinder"
        }
    }
    var color: Color {
        switch self {
        case .duplicates: return .appPrimary
        case .similar: return .appTeal
        case .blurry: return .appWarning
        case .screenshots: return .appPurple
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
}

actor ScanOrchestrator {
    private let photoLibrary = PhotoLibraryManager()
    private let duplicateDetector = DuplicateDetector()
    private let similarityGrouper = SimilarityGrouper()
    private let qualityAnalyzer = QualityAnalyzer()
    private let screenshotClassifier = ScreenshotClassifier()

    // Cached results (read from main actor after scan completes)
    nonisolated(unsafe) var duplicateGroups: [DuplicateGroup] = []
    nonisolated(unsafe) var similarGroups: [SimilarGroup] = []
    nonisolated(unsafe) var blurryPhotos: [PhotoQuality] = []
    nonisolated(unsafe) var screenshotGroups: [ScreenshotGroupData] = []

    // MARK: - Individual scans

    func scanDuplicates(state: CategoryScanState, includeVideos: Bool = false) async {
        await MainActor.run { state.isScanning = true; state.isDone = false }
        let allPhotos = await photoLibrary.fetchAllPhotos(includeVideos: includeVideos)
        duplicateGroups = await duplicateDetector.detect(in: allPhotos) { p in
            Task { @MainActor in state.progress = p }
        }
        let count = duplicateGroups.reduce(0) { $0 + $1.assets.count - 1 }
        let bytes = duplicateGroups.reduce(Int64(0)) { total, group in
            total + group.assets.filter { $0 != group.recommended }.reduce(Int64(0)) { $0 + $1.fileSizeBytes }
        }
        await MainActor.run {
            state.count = count; state.sizeBytes = bytes
            state.isScanning = false; state.isDone = true; state.progress = 1
        }
    }

    func scanSimilar(state: CategoryScanState, includeVideos: Bool = false) async {
        await MainActor.run { state.isScanning = true; state.isDone = false }
        let allPhotos = await photoLibrary.fetchAllPhotos(includeVideos: includeVideos)
        similarGroups = await similarityGrouper.group(assets: allPhotos) { p in
            Task { @MainActor in state.progress = p }
        }
        let count = similarGroups.reduce(0) { $0 + $1.assets.count - 1 }
        let bytes = similarGroups.reduce(Int64(0)) { total, group in
            total + group.assets.filter { $0 != group.recommended }.reduce(Int64(0)) { $0 + $1.fileSizeBytes }
        }
        await MainActor.run {
            state.count = count; state.sizeBytes = bytes
            state.isScanning = false; state.isDone = true; state.progress = 1
        }
    }

    func scanBlurry(state: CategoryScanState, includeVideos: Bool = false) async {
        await MainActor.run { state.isScanning = true; state.isDone = false }
        let allPhotos = await photoLibrary.fetchAllPhotos(includeVideos: includeVideos)
        blurryPhotos = await qualityAnalyzer.findBlurry(assets: allPhotos) { p in
            Task { @MainActor in state.progress = p }
        }
        let bytes = blurryPhotos.reduce(Int64(0) as Int64) { $0 + $1.fileSize }
        await MainActor.run {
            state.count = blurryPhotos.count; state.sizeBytes = bytes
            state.isScanning = false; state.isDone = true; state.progress = 1
        }
    }

    func scanScreenshots(state: CategoryScanState) async {
        await MainActor.run { state.isScanning = true; state.isDone = false; state.progress = 0.5 }
        let screenshots = await screenshotClassifier.fetchScreenshots()
        screenshotGroups = await screenshotClassifier.groupByTime(screenshots)
        let count = screenshotGroups.reduce(0) { $0 + $1.assets.count }
        let bytes = screenshotGroups.reduce(Int64(0)) { $0 + $1.totalSize }
        await MainActor.run {
            state.count = count; state.sizeBytes = bytes
            state.isScanning = false; state.isDone = true; state.progress = 1
        }
    }

    // MARK: - Full scan (legacy)

    func runScan(progress: ScanProgressState, includeVideos: Bool = false) async -> ScanResult {
        await MainActor.run { progress.isScanning = true; progress.isCancelled = false }

        await MainActor.run { progress.phase = .screenshots; progress.overallProgress = 0.1 }
        let screenshots = await screenshotClassifier.fetchScreenshots()
        screenshotGroups = await screenshotClassifier.groupByTime(screenshots)
        await MainActor.run { progress.overallProgress = 0.15 }

        await MainActor.run { progress.phase = .duplicates; progress.overallProgress = 0.2 }
        let allPhotos = await photoLibrary.fetchAllPhotos(includeVideos: includeVideos)
        duplicateGroups = await duplicateDetector.detect(in: allPhotos) { p in
            Task { @MainActor in progress.phaseProgress = p; progress.overallProgress = 0.2 + p * 0.3 }
        }
        await MainActor.run { progress.overallProgress = 0.5 }

        await MainActor.run { progress.phase = .similar; progress.overallProgress = 0.5 }
        similarGroups = await similarityGrouper.group(assets: allPhotos) { p in
            Task { @MainActor in progress.phaseProgress = p; progress.overallProgress = 0.5 + p * 0.3 }
        }
        await MainActor.run { progress.overallProgress = 0.8 }

        await MainActor.run { progress.phase = .blurry; progress.overallProgress = 0.8 }
        blurryPhotos = await qualityAnalyzer.findBlurry(assets: allPhotos) { p in
            Task { @MainActor in progress.phaseProgress = p; progress.overallProgress = 0.8 + p * 0.2 }
        }

        await MainActor.run {
            progress.overallProgress = 1.0; progress.phase = .completed; progress.isScanning = false
        }

        return ScanResult(
            duplicateGroups: duplicateGroups, similarGroups: similarGroups,
            blurryPhotos: blurryPhotos, screenshotGroups: screenshotGroups
        )
    }
}
