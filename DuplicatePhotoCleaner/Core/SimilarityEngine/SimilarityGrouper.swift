import Photos
import Vision

struct SimilarGroup {
    let assets: [PHAsset]
    let recommended: PHAsset
    let averageSimilarity: Float
}

actor SimilarityGrouper {
    func group(assets: [PHAsset], progress: @escaping (Double) -> Void) async -> [SimilarGroup] {
        var features: [(asset: PHAsset, feature: VNFeaturePrintObservation)] = []
        let total = Double(assets.count)

        for (index, asset) in assets.enumerated() {
            if let feature = await FeatureExtractor.extract(from: asset) {
                features.append((asset: asset, feature: feature))
            }
            progress(Double(index + 1) / total * 0.7)
        }

        var used = Set<Int>()
        var groups: [SimilarGroup] = []
        let threshold: Float = 0.85

        for i in 0..<features.count {
            if used.contains(i) { continue }
            var groupIndices = [i]
            used.insert(i)
            var totalSim: Float = 0
            var pairCount = 0

            // Compare against all current group members, not just the anchor
            var checkIndex = i + 1
            while checkIndex < features.count {
                if used.contains(checkIndex) { checkIndex += 1; continue }
                var bestSim: Float = 0
                for memberIdx in groupIndices {
                    let sim = CosineSimilarity.compute(features[memberIdx].feature, features[checkIndex].feature)
                    if sim > bestSim { bestSim = sim }
                }
                if bestSim >= threshold {
                    groupIndices.append(checkIndex)
                    used.insert(checkIndex)
                    totalSim += bestSim
                    pairCount += 1
                    // Re-check from the beginning of remaining items since the group grew
                }
                checkIndex += 1
            }

            if groupIndices.count > 1 {
                let groupAssets = groupIndices.map { features[$0].asset }
                groups.append(SimilarGroup(
                    assets: groupAssets,
                    recommended: pickBest(in: groupAssets),
                    averageSimilarity: pairCount > 0 ? totalSim / Float(pairCount) : threshold
                ))
            }
            progress(0.7 + 0.3 * Double(i + 1) / Double(features.count))
        }
        return groups
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
