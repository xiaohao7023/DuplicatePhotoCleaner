import Vision
import UIKit
import Photos

struct FeatureExtractor: Sendable {
    nonisolated static func extract(from asset: PHAsset) async -> VNFeaturePrintObservation? {
        guard let image = await requestImage(for: asset) else { return nil }
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

    nonisolated private static func requestImage(for asset: PHAsset) async -> CGImage? {
        await withCheckedContinuation { continuation in
            var didResume = false
            let lock = NSLock()
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .highQualityFormat
            opts.isNetworkAccessAllowed = false
            opts.resizeMode = .fast
            PHImageManager.default().requestImage(
                for: asset, targetSize: CGSize(width: 512, height: 512),
                contentMode: .aspectFill, options: opts
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
