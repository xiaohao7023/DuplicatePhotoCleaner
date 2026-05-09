import Photos

struct ScanResult: Identifiable {
    let id = UUID()
    let duplicateGroups: [DuplicateGroup]
    let similarGroups: [SimilarGroup]
    let blurryPhotos: [PhotoQuality]
    let screenshotGroups: [ScreenshotGroupData]

    var totalDuplicates: Int { duplicateGroups.reduce(0) { $0 + $1.assets.count - 1 } }
    var totalSimilar: Int { similarGroups.reduce(0) { $0 + $1.assets.count - 1 } }
    var totalBlurry: Int { blurryPhotos.count }
    var totalScreenshots: Int { screenshotGroups.reduce(0) { $0 + $1.assets.count } }

    var estimatedReclaimableBytes: Int64 {
        let dupBytes = duplicateGroups.reduce(Int64(0)) { total, group in
            total + group.assets.filter { $0 != group.recommended }.reduce(Int64(0)) { $0 + $1.fileSizeBytes }
        }
        let simBytes = similarGroups.reduce(Int64(0)) { total, group in
            total + group.assets.filter { $0 != group.recommended }.reduce(Int64(0)) { $0 + $1.fileSizeBytes }
        }
        let blurBytes = blurryPhotos.reduce(Int64(0)) { $0 + $1.fileSize }
        let ssBytes = screenshotGroups.reduce(Int64(0)) { $0 + $1.totalSize }
        return dupBytes + simBytes + blurBytes + ssBytes
    }

    var isEmpty: Bool {
        duplicateGroups.isEmpty && similarGroups.isEmpty && blurryPhotos.isEmpty && screenshotGroups.isEmpty
    }

    nonisolated static var empty: ScanResult {
        ScanResult(duplicateGroups: [], similarGroups: [], blurryPhotos: [], screenshotGroups: [])
    }
}
