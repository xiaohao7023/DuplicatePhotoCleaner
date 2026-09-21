import SwiftUI
import Photos

/// 全库扫描结果容器（引用类型）。由 HomeView 持有，Onboarding 预热与各清理页共享同一实例。
@Observable
class ScanResultData {
    var duplicateGroups: [DuplicateGroup] = []
    var similarGroups: [SimilarGroup] = []
    var blurryPhotos: [PhotoQuality] = []
    var screenshotGroups: [ScreenshotGroupData] = []
    var videos: [PHAsset] = []
    var unfavoritedPhotos: [PHAsset] = []
}
