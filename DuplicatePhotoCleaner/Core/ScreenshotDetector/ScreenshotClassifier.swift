import Photos

enum ScreenshotTimeGroup: String, CaseIterable {
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case older = "Older"

    var displayName: String {
        switch self {
        case .today: return String(localized: "Today")
        case .thisWeek: return String(localized: "This Week")
        case .thisMonth: return String(localized: "This Month")
        case .older: return String(localized: "Older")
        }
    }
}

struct ScreenshotGroupData {
    let group: ScreenshotTimeGroup
    let assets: [PHAsset]
    let totalSize: Int64
}

actor ScreenshotClassifier {
    func fetchScreenshots() -> [PHAsset] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaSubtype == %d", PHAssetMediaSubtype.photoScreenshot.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let results = PHAsset.fetchAssets(with: .image, options: options)
        var assets: [PHAsset] = []
        results.enumerateObjects { asset, _, _ in assets.append(asset) }
        return assets
    }

    func groupByTime(_ screenshots: [PHAsset]) -> [ScreenshotGroupData] {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let startOfWeek = calendar.date(byAdding: .day, value: -7, to: startOfDay)!
        let startOfMonth = calendar.date(byAdding: .day, value: -30, to: startOfDay)!

        var groups: [ScreenshotTimeGroup: [PHAsset]] = [
            .today: [], .thisWeek: [], .thisMonth: [], .older: []
        ]

        for asset in screenshots {
            guard let date = asset.creationDate else {
                groups[.older, default: []].append(asset); continue
            }
            if date >= startOfDay { groups[.today, default: []].append(asset) }
            else if date >= startOfWeek { groups[.thisWeek, default: []].append(asset) }
            else if date >= startOfMonth { groups[.thisMonth, default: []].append(asset) }
            else { groups[.older, default: []].append(asset) }
        }

        return ScreenshotTimeGroup.allCases.compactMap { group in
            guard let assets = groups[group], !assets.isEmpty else { return nil }
            let totalSize = assets.reduce(Int64(0)) { total, asset in
                let resources = PHAssetResource.assetResources(for: asset)
                return total + (resources.first?.value(forKey: "fileSize") as? Int64 ?? 0)
            }
            return ScreenshotGroupData(group: group, assets: assets, totalSize: totalSize)
        }
    }
}
