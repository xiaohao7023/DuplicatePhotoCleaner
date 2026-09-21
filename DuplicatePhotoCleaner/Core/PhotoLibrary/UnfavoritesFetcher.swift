import Photos

actor UnfavoritesFetcher {

    // MARK: - Statistics

    /// Returns (total, favorited, unfavorited) counts for the photo library.
    func fetchStatistics(includeVideos: Bool) async -> (total: Int, favorited: Int, unfavorited: Int) {
        let allOptions = PHFetchOptions()
        let favOptions = PHFetchOptions()
        favOptions.predicate = NSPredicate(format: "favorite == YES")

        let unfavOptions = PHFetchOptions()
        unfavOptions.predicate = NSPredicate(format: "favorite == NO")

        if !includeVideos {
            let imagePredicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            allOptions.predicate = imagePredicate
            favOptions.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [imagePredicate, favOptions.predicate!])
            unfavOptions.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [imagePredicate, unfavOptions.predicate!])
        }

        let total = PHAsset.fetchAssets(with: allOptions).count
        let favorited = PHAsset.fetchAssets(with: favOptions).count
        let unfavorited = PHAsset.fetchAssets(with: unfavOptions).count

        return (total, favorited, unfavorited)
    }

    // MARK: - Fetch Unfavorites

    /// Fetches all unfavorited assets sorted by creationDate descending.
    func fetchUnfavorites(includeVideos: Bool = false) async -> [PHAsset] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "favorite == NO")
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let results: PHFetchResult<PHAsset>
        if includeVideos {
            results = PHAsset.fetchAssets(with: options)
        } else {
            let imagePredicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            let compound = NSCompoundPredicate(andPredicateWithSubpredicates: [imagePredicate, options.predicate!])
            options.predicate = compound
            results = PHAsset.fetchAssets(with: options)
        }

        var assets: [PHAsset] = []
        results.enumerateObjects { asset, _, _ in assets.append(asset) }
        return assets
    }

    // MARK: - Mark as Favorite

    /// Marks one or more assets as favorite (whitelist mechanism).
    func markAsFavorite(_ assets: [PHAsset]) async throws {
        guard !assets.isEmpty else { return }
        try await PHPhotoLibrary.shared().performChanges {
            for asset in assets {
                let request = PHAssetChangeRequest(for: asset)
                request.isFavorite = true
            }
        }
    }
}
