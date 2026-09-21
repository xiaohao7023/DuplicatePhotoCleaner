import Vision
import UIKit
import Photos

struct FeatureExtractor: Sendable {
    nonisolated static func extract(from asset: PHAsset, targetDimension: CGFloat = 512) async -> VNFeaturePrintObservation? {
        guard let image = await requestImage(for: asset, targetDimension: targetDimension) else { return nil }
        return extract(from: image)
    }

    nonisolated static func extract(from cgImage: CGImage) -> VNFeaturePrintObservation? {
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            return request.results?.first as? VNFeaturePrintObservation
        } catch { return nil }
    }

    nonisolated private static func requestImage(for asset: PHAsset, targetDimension: CGFloat) async -> CGImage? {
        await withCheckedContinuation { continuation in
            var didResume = false
            let lock = NSLock()
            let opts = PHImageRequestOptions()
            opts.deliveryMode = targetDimension < 512 ? .fastFormat : .highQualityFormat
            opts.isNetworkAccessAllowed = false
            opts.resizeMode = .fast
            PHImageManager.default().requestImage(
                for: asset, targetSize: CGSize(width: targetDimension, height: targetDimension),
                // Preserve the entire frame. Cropping with aspectFill made
                // visually different photos look similar when their centers matched.
                contentMode: .aspectFit, options: opts
            ) { image, _ in
                lock.lock()
                guard !didResume else { lock.unlock(); return }
                didResume = true
                lock.unlock()
                continuation.resume(returning: image?.cgImage)
            }
        }
    }
}
