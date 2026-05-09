import Photos
import UIKit

struct PhotoQuality {
    let asset: PHAsset
    let blurScore: Double
    let blurLevel: BlurDetector.BlurLevel
    let resolution: Int
    let fileSize: Int64
}

actor QualityAnalyzer {
    func analyze(assets: [PHAsset], progress: @escaping (Double) -> Void) async -> [PhotoQuality] {
        var results: [PhotoQuality] = []
        let total = Double(assets.count)
        for (index, asset) in assets.enumerated() {
            if let quality = await analyzeSingle(asset) { results.append(quality) }
            progress(Double(index + 1) / total)
        }
        return results.sorted { $0.blurScore < $1.blurScore }
    }

    func findBlurry(assets: [PHAsset], threshold: BlurDetector.BlurLevel = .blurry, progress: @escaping (Double) -> Void) async -> [PhotoQuality] {
        let all = await analyze(assets: assets, progress: progress)
        return all.filter { $0.blurScore < threshold.threshold }
    }

    private func analyzeSingle(_ asset: PHAsset) async -> PhotoQuality? {
        guard let image = await requestCGImage(for: asset) else { return nil }
        let blurScore = BlurDetector.laplacianVariance(for: image) ?? 0
        let resources = PHAssetResource.assetResources(for: asset)
        let fileSize = resources.first?.value(forKey: "fileSize") as? Int64 ?? 0

        return PhotoQuality(
            asset: asset, blurScore: blurScore,
            blurLevel: BlurDetector.classify(blurScore),
            resolution: asset.pixelWidth * asset.pixelHeight,
            fileSize: fileSize
        )
    }

    private func requestCGImage(for asset: PHAsset) async -> CGImage? {
        await withCheckedContinuation { continuation in
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .highQualityFormat
            opts.isNetworkAccessAllowed = false
            opts.resizeMode = .fast
            PHImageManager.default().requestImage(
                for: asset, targetSize: CGSize(width: 512, height: 512),
                contentMode: .aspectFill, options: opts
            ) { image, _ in continuation.resume(returning: image?.cgImage) }
        }
    }
}
