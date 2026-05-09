import Foundation

extension FileManager {
    func getFilesystemInfo() -> (used: Double, total: Double)? {
        do {
            let attrs = try attributesOfFileSystem(forPath: NSHomeDirectory())
            guard let totalBytes = attrs[.systemSize] as? Int64,
                  let freeBytes = attrs[.systemFreeSize] as? Int64 else { return nil }
            let totalGB = Double(totalBytes) / 1_073_741_824
            let freeGB = Double(freeBytes) / 1_073_741_824
            return (used: totalGB - freeGB, total: totalGB)
        } catch {
            return nil
        }
    }
}
