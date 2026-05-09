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

        for i in 0..<features.count {
            if used.contains(i) { continue }
            var groupIndices = [i]
            used.insert(i)
            var totalSim: Float = 0
            var pairCount = 0

            for j in (i + 1)..<features.count {
                if used.contains(j) { continue }
                let sim = CosineSimilarity.compute(features[i].feature, features[j].feature)
                if sim >= 0.85 {
                    groupIndices.append(j)
                    used.insert(j)
                    totalSim += sim
                    pairCount += 1
                }
            }

            if groupIndices.count > 1 {
                let groupAssets = groupIndices.map { features[$0].asset }
                groups.append(SimilarGroup(
                    assets: groupAssets,
                    recommended: pickBest(in: groupAssets),
                    averageSimilarity: pairCount > 0 ? totalSim / Float(pairCount) : 0.85
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
            return (a.creationDate ?? .distantPast) < (b.creationDate ?? .distantPast)
        }) ?? assets[0]
    }
}
