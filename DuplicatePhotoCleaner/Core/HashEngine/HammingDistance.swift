import Foundation

struct HammingDistance: Sendable {
    nonisolated static func compute(_ a: UInt64, _ b: UInt64) -> Int {
        var xor = a ^ b
        var count = 0
        while xor > 0 { count += Int(xor & 1); xor >>= 1 }
        return count
    }

    nonisolated static func similarity(_ a: UInt64, _ b: UInt64) -> Double {
        1.0 - Double(compute(a, b)) / 64.0
    }

    nonisolated static func areDuplicates(_ a: UInt64, _ b: UInt64, threshold: Int = 10) -> Bool {
        compute(a, b) <= threshold
    }
}
