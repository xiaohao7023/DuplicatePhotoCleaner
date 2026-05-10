import Photos

actor PhotoLibraryManager {
    func fetchAllPhotos(includeVideos: Bool = false) -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let results: PHFetchResult<PHAsset>
        if includeVideos { results = PHAsset.fetchAssets(with: options) }
        else { results = PHAsset.fetchAssets(with: .image, options: options) }
        var assets: [PHAsset] = []
        results.enumerateObjects { asset, _, _ in assets.append(asset) }
        return assets
    }

    func fetchVideos() -> [PHAsset] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let results = PHAsset.fetchAssets(with: options)
        var assets: [PHAsset] = []
        results.enumerateObjects { asset, _, _ in assets.append(asset) }
        return assets
    }

    func deleteAssets(_ assets: [PHAsset]) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSArray)
        }
    }
}
