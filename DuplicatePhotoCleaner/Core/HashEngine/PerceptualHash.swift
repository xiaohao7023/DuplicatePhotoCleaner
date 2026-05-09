import UIKit
import Accelerate

struct PerceptualHash: Sendable {
    nonisolated static let hashSize = 8

    nonisolated static func compute(for image: CGImage) -> UInt64? {
        let size = 32
        guard let grayscale = toGrayscale(image, targetSize: CGSize(width: size, height: size)) else { return nil }

        let cosTable = precomputeCosineTable(size: size)
        let rowDCT = applySeparableDCT(grayscale, size: size, cosTable: cosTable)

        var lowFreq = [Float](repeating: 0, count: hashSize * hashSize)
        for row in 0..<hashSize {
            for col in 0..<hashSize {
                lowFreq[row * hashSize + col] = rowDCT[row * size + col]
            }
        }

        let withoutDC = Array(lowFreq.dropFirst())
        let sorted = withoutDC.sorted()
        let median: Float = sorted.count % 2 == 0
            ? (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2.0
            : sorted[sorted.count / 2]

        var hash: UInt64 = 0
        for (i, value) in lowFreq.enumerated() {
            if value > median { hash |= (1 << UInt64(i)) }
        }
        return hash
    }

    nonisolated private static func applySeparableDCT(_ pixels: [Float], size: Int, cosTable: [[Float]]) -> [Float] {
        var rowDCT = [Float](repeating: 0, count: size * size)
        for row in 0..<size {
            let input = Array(pixels[row * size..<(row + 1) * size])
            let output = dct1D(input, size: size, cosTable: cosTable)
            for col in 0..<size { rowDCT[row * size + col] = output[col] }
        }

        var result = [Float](repeating: 0, count: size * size)
        var column = [Float](repeating: 0, count: size)
        for col in 0..<size {
            for row in 0..<size { column[row] = rowDCT[row * size + col] }
            let output = dct1D(column, size: size, cosTable: cosTable)
            for row in 0..<size { result[row * size + col] = output[row] }
        }
        return result
    }

    nonisolated private static func dct1D(_ input: [Float], size: Int, cosTable: [[Float]]) -> [Float] {
        var output = [Float](repeating: 0, count: size)
        for u in 0..<size {
            var dot: Float = 0
            vDSP_dotpr(input, 1, cosTable[u], 1, &dot, vDSP_Length(size))
            output[u] = dot
        }
        return output
    }

    nonisolated private static func precomputeCosineTable(size: Int) -> [[Float]] {
        var table = [[Float]](repeating: [Float](repeating: 0, count: size), count: size)
        let factor = Float.pi / Float(2 * size)
        for u in 0..<size {
            for x in 0..<size {
                table[u][x] = cos(factor * Float(2 * x + 1) * Float(u))
            }
        }
        return table
    }

    nonisolated private static func toGrayscale(_ image: CGImage, targetSize: CGSize) -> [Float]? {
        let width = Int(targetSize.width)
        let height = Int(targetSize.height)
        guard let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        context.draw(image, in: CGRect(origin: .zero, size: targetSize))
        guard let data = context.data else { return nil }
        let buffer = data.bindMemory(to: UInt8.self, capacity: width * height)
        var floatPixels = [Float](repeating: 0, count: width * height)
        vDSP_vfltu8(buffer, 1, &floatPixels, 1, vDSP_Length(width * height))
        return floatPixels
    }
}
