import SwiftUI
import Photos

struct PhotoThumbnailGrid: View {
    let assets: [PHAsset]
    var selectedAssets: Set<String> = []
    var recommendedAsset: String? = nil
    var showSelection: Bool = false
    var onToggle: ((String) -> Void)? = nil
    let columns = 3

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 2), count: columns)
    }

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 2) {
            ForEach(assets, id: \.localIdentifier) { asset in
                PhotoGridCell(
                    asset: asset,
                    isSelected: selectedAssets.contains(asset.localIdentifier),
                    isRecommended: asset.localIdentifier == recommendedAsset,
                    showSelection: showSelection
                )
                .onTapGesture { onToggle?(asset.localIdentifier) }
            }
        }
    }
}

struct PhotoGridCell: View {
    let asset: PHAsset
    let isSelected: Bool
    let isRecommended: Bool
    let showSelection: Bool
    @State private var thumbnail: UIImage?

    var body: some View {
        Color.appBackgroundTertiary
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .overlay(alignment: .bottomLeading) {
                if isRecommended {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill").font(.system(size: 10))
                        Text("Best").font(.appMicro)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Capsule().fill(Color.appSuccess))
                    .padding(5)
                }
            }
            .overlay(alignment: .topTrailing) {
                if showSelection {
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.appRose : Color.white.opacity(0.85))
                            .frame(width: 22, height: 22)
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Circle()
                                .strokeBorder(Color.black.opacity(0.15), lineWidth: 1)
                                .frame(width: 20, height: 20)
                        }
                    }
                    .padding(5)
                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                }
            }
            .overlay {
                if isSelected {
                    Rectangle()
                        .fill(Color.appRose.opacity(0.15))
                        .allowsHitTesting(false)
                }
            }
            .onAppear { loadThumbnail() }
            .onDisappear { thumbnail = nil }
    }

    private func loadThumbnail() {
        guard thumbnail == nil else { return }
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .opportunistic
        opts.isNetworkAccessAllowed = false
        PHImageManager.default().requestImage(
            for: asset, targetSize: CGSize(width: 200, height: 200),
            contentMode: .aspectFill, options: opts
        ) { img, _ in
            if let img { DispatchQueue.main.async { self.thumbnail = img } }
        }
    }
}
