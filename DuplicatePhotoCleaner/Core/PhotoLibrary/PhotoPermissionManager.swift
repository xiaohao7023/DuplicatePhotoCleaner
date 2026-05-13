import Photos
import SwiftUI

enum PhotoPermissionStatus {
    case notDetermined, authorized, limited, denied
}

@Observable
class PhotoPermissionManager {
    var status: PhotoPermissionStatus = .notDetermined

    init() {}

    func checkCurrentStatus() {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch current {
        case .notDetermined: status = .notDetermined
        case .authorized: status = .authorized
        case .limited: status = .limited
        case .denied, .restricted: status = .denied
        @unknown default: status = .denied
        }
    }

    func requestPermission() async -> PhotoPermissionStatus {
        let result = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run {
            switch result {
            case .authorized: status = .authorized
            case .limited: status = .limited
            case .denied, .restricted: status = .denied
            case .notDetermined: status = .notDetermined
            @unknown default: status = .denied
            }
        }
        return status
    }
}
