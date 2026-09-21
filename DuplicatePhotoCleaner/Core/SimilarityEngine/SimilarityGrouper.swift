import Photos
import Vision

struct SimilarGroup {
    let assets: [PHAsset]
    let recommended: PHAsset
    let averageSimilarity: Float
}

actor SimilarityGrouper {
    private let anchorThreshold: Float = 0.92
    private let groupThreshold: Float = 0.90
    private let maximumCaptureGap: TimeInterval = 10 * 60
    private let maximumAspectRatioDelta = 0.08

    func group(assets: [PHAsset], targetDimension: CGFloat = 512, progress: @escaping (Double) -> Void) async -> [SimilarGroup] {
        // Metadata prefilter: Vision is the expensive part, so only generate
        // feature prints for photos that have at least one plausible neighbor
        // within the same capture window. This preserves the existing matching
        // rules while making the common library scan substantially faster.
        let candidateAssets = plausibleCandidates(in: assets)
        guard !candidateAssets.isEmpty else {
            progress(1)
            return []
        }

        var features: [(asset: PHAsset, feature: VNFeaturePrintObservation)] = []
        let total = Double(candidateAssets.count)

        for (index, asset) in candidateAssets.enumerated() {
            if let feature = await FeatureExtractor.extract(from: asset, targetDimension: targetDimension) {
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

            for checkIndex in (i + 1)..<features.count {
                if used.contains(checkIndex) { continue }

                let candidate = features[checkIndex]
                guard isPlausiblePair(features[i].asset, candidate.asset) else { continue }

                let anchorSimilarity = CosineSimilarity.compute(features[i].feature, candidate.feature)
                guard anchorSimilarity >= anchorThreshold else { continue }

                // Require the candidate to match every member. This prevents
                // transitive drift where A resembles B and B resembles C,
                // but A and C are visibly different.
                let memberSimilarities = groupIndices.map {
                    CosineSimilarity.compute(features[$0].feature, candidate.feature)
                }
                if memberSimilarities.allSatisfy({ $0 >= groupThreshold }) {
                    groupIndices.append(checkIndex)
                    used.insert(checkIndex)
                    totalSim += memberSimilarities.reduce(0, +) / Float(memberSimilarities.count)
                    pairCount += 1
                }
            }

            if groupIndices.count > 1 {
                let groupAssets = groupIndices.map { features[$0].asset }
                groups.append(SimilarGroup(
                    assets: groupAssets,
                    recommended: pickBest(in: groupAssets),
                    averageSimilarity: pairCount > 0 ? totalSim / Float(pairCount) : anchorThreshold
                ))
            }
            progress(0.7 + 0.3 * Double(i + 1) / Double(features.count))
        }
        return groups
    }

    private func plausibleCandidates(in assets: [PHAsset]) -> [PHAsset] {
        let dated = assets
            .filter { $0.creationDate != nil }
            .sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
        var candidateIDs = Set<String>()

        for leftIndex in dated.indices {
            let left = dated[leftIndex]
            var rightIndex = leftIndex + 1
            while rightIndex < dated.count {
                let right = dated[rightIndex]
                guard let leftDate = left.creationDate, let rightDate = right.creationDate else {
                    rightIndex += 1
                    continue
                }
                if rightDate.timeIntervalSince(leftDate) > maximumCaptureGap { break }
                if isPlausiblePair(left, right) {
                    candidateIDs.insert(left.localIdentifier)
                    candidateIDs.insert(right.localIdentifier)
                }
                rightIndex += 1
            }
        }

        return assets.filter { candidateIDs.contains($0.localIdentifier) }
    }

    private func isPlausiblePair(_ lhs: PHAsset, _ rhs: PHAsset) -> Bool {
        if let leftDate = lhs.creationDate, let rightDate = rhs.creationDate,
           abs(leftDate.timeIntervalSince(rightDate)) > maximumCaptureGap {
            return false
        }

        let leftRatio = Double(lhs.pixelWidth) / Double(max(lhs.pixelHeight, 1))
        let rightRatio = Double(rhs.pixelWidth) / Double(max(rhs.pixelHeight, 1))
        let ratioDelta = abs(leftRatio - rightRatio) / max(leftRatio, rightRatio)
        return ratioDelta <= maximumAspectRatioDelta
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
