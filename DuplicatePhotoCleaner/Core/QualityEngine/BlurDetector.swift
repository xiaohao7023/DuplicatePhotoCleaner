import UIKit
import Accelerate

struct BlurDetector: Sendable {
    enum BlurLevel: String, CaseIterable, Sendable {
        case sharp = "Sharp"
        case slightlyBlurry = "Slightly Blurry"
        case blurry = "Blurry"
        case veryBlurry = "Very Blurry"

        var displayName: String {
            switch self {
            case .sharp: return String(localized: "Sharp")
            case .slightlyBlurry: return String(localized: "Slightly Blurry")
            case .blurry: return String(localized: "Blurry")
            case .veryBlurry: return String(localized: "Very Blurry")
            }
        }

        nonisolated var threshold: Double {
            switch self {
            case .sharp: return 500
            case .slightlyBlurry: return 200
            case .blurry: return 100
            case .veryBlurry: return 50
            }
        }
    }

    nonisolated static func laplacianVariance(for image: CGImage) -> Double? {
        let width = min(image.width, 512)
        let height = min(image.height, 512)

        guard let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else { return nil }
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height)

        // Laplacian kernel: [0,1,0; 1,-4,1; 0,1,0]
        var sum: Double = 0
        var sumSq: Double = 0
        var count: Double = 0

        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let center = Double(pixels[y * width + x]) * -4
                let top = Double(pixels[(y - 1) * width + x])
                let bottom = Double(pixels[(y + 1) * width + x])
                let left = Double(pixels[y * width + (x - 1)])
                let right = Double(pixels[y * width + (x + 1)])
                let val = abs(center + top + bottom + left + right)
                sum += val
                sumSq += val * val
                count += 1
            }
        }

        let mean = sum / count
        return sumSq / count - mean * mean
    }

    nonisolated static func classify(_ variance: Double) -> BlurLevel {
        if variance >= BlurLevel.sharp.threshold { return .sharp }
        if variance >= BlurLevel.slightlyBlurry.threshold { return .slightlyBlurry }
        if variance >= BlurLevel.blurry.threshold { return .blurry }
        return .veryBlurry
    }

    nonisolated static func isBlurry(_ image: CGImage, threshold: BlurLevel = .blurry) -> Bool {
        guard let variance = laplacianVariance(for: image) else { return false }
        return variance < threshold.threshold
    }
}
