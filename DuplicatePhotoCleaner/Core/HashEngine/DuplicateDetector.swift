import Photos
import UIKit

struct DuplicateGroup {
    let assets: [PHAsset]
    let recommended: PHAsset
}

actor DuplicateDetector {
    func detect(in assets: [PHAsset], progress: @escaping (Double) -> Void) async -> [DuplicateGroup] {
        var hashResults: [(asset: PHAsset, hash: UInt64)] = []
        let total = Double(assets.count)

        for (index, asset) in assets.enumerated() {
            if let hash = await computeHash(for: asset) {
                hashResults.append((asset: asset, hash: hash))
            }
            progress(Double(index + 1) / total)
        }

        var used = Set<Int>()
        var groups: [DuplicateGroup] = []

        for i in 0..<hashResults.count {
            if used.contains(i) { continue }
            var group = [hashResults[i].asset]
            used.insert(i)
            for j in (i + 1)..<hashResults.count {
                if used.contains(j) { continue }
                if HammingDistance.areDuplicates(hashResults[i].hash, hashResults[j].hash) {
                    group.append(hashResults[j].asset)
                    used.insert(j)
                }
            }
            if group.count > 1 {
                groups.append(DuplicateGroup(assets: group, recommended: pickBest(in: group)))
            }
        }
        return groups
    }

    private func computeHash(for asset: PHAsset) async -> UInt64? {
        await withCheckedContinuation { continuation in
            var didResume = false
            let lock = NSLock()
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .fastFormat
            opts.isNetworkAccessAllowed = false
            opts.resizeMode = .fast
            PHImageManager.default().requestImage(
                for: asset, targetSize: CGSize(width: 256, height: 256),
                contentMode: .aspectFill, options: opts
            ) { image, _ in
                lock.lock()
                guard !didResume else { lock.unlock(); return }
                didResume = true
                lock.unlock()
                guard let cgImage = image?.cgImage else { continuation.resume(returning: nil); return }
                continuation.resume(returning: PerceptualHash.compute(for: cgImage))
            }
        }
    }

    private func pickBest(in assets: [PHAsset]) -> PHAsset {
        assets.max(by: { a, b in
            let sa = a.pixelWidth * a.pixelHeight
            let sb = b.pixelWidth * b.pixelHeight
            if sa != sb { return sa < sb }
            // Same resolution: larger file = less compression = better quality
            let fa = a.fileSizeBytes
            let fb = b.fileSizeBytes
            if fa != fb { return fa < fb }
            // Same size: prefer original (older)
            return (a.creationDate ?? .distantPast) < (b.creationDate ?? .distantPast)
        }) ?? assets[0]
    }
}
