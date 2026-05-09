import Vision
import Accelerate

struct CosineSimilarity: Sendable {
    nonisolated static func compute(_ a: VNFeaturePrintObservation, _ b: VNFeaturePrintObservation) -> Float {
        let count = a.elementCount
        guard count == b.elementCount, count > 0 else { return 0 }

        let dataA = a.data
        let dataB = b.data

        return dataA.withUnsafeBytes { ptrA -> Float in
            dataB.withUnsafeBytes { ptrB -> Float in
                guard let baseA = ptrA.baseAddress, let baseB = ptrB.baseAddress else { return 0 }
                let floatA = baseA.bindMemory(to: Float.self, capacity: count)
                let floatB = baseB.bindMemory(to: Float.self, capacity: count)

                var dotProduct: Float = 0
                var normA: Float = 0
                var normB: Float = 0
                vDSP_dotpr(floatA, 1, floatB, 1, &dotProduct, vDSP_Length(count))
                vDSP_dotpr(floatA, 1, floatA, 1, &normA, vDSP_Length(count))
                vDSP_dotpr(floatB, 1, floatB, 1, &normB, vDSP_Length(count))

                let denominator = sqrt(normA) * sqrt(normB)
                guard denominator > 0 else { return 0 }
                return dotProduct / denominator
            }
        }
    }

    nonisolated static func areSimilar(_ a: VNFeaturePrintObservation, _ b: VNFeaturePrintObservation, threshold: Float = 0.85) -> Bool {
        compute(a, b) >= threshold
    }
}
