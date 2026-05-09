import Foundation

enum ScanPhase: String {
    case idle = "Ready"
    case metadata = "Quick Scan"
    case duplicates = "Finding Duplicates"
    case similar = "Finding Similar Photos"
    case blurry = "Detecting Blurry Photos"
    case screenshots = "Organizing Screenshots"
    case completed = "Scan Complete"
}

@Observable
class ScanProgressState {
    var phase: ScanPhase = .idle
    var overallProgress: Double = 0
    var phaseProgress: Double = 0
    var photosProcessed: Int = 0
    var totalPhotos: Int = 0
    var duplicatesFound: Int = 0
    var similarGroupsFound: Int = 0
    var blurryFound: Int = 0
    var isScanning: Bool = false
    var isCancelled: Bool = false

    func reset() {
        phase = .idle; overallProgress = 0; phaseProgress = 0
        photosProcessed = 0; totalPhotos = 0
        duplicatesFound = 0; similarGroupsFound = 0; blurryFound = 0
        isScanning = false; isCancelled = false
    }
}
