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
        Array(repeating: GridItem(.flexible(), spacing: 4), count: columns)
    }

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 4) {
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
        ZStack(alignment: .bottomTrailing) {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.appBackgroundTertiary)
                    .aspectRatio(1, contentMode: .fill)
                    .overlay { ProgressView().scaleEffect(0.6) }
                    .onAppear { loadThumbnail() }
            }
            if showSelection {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.appPrimary : Color.white.opacity(0.7))
                        .frame(width: 24, height: 24)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(6)
            }
            if isRecommended {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 10))
                    Text("Best").font(.appMicro)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(Capsule().fill(Color.appSuccess))
                .padding(6)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func loadThumbnail() {
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
