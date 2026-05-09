import SwiftUI
import Photos

struct PhotoPreviewSheet: View {
    let assets: [PHAsset]
    @State private var currentIndex: Int
    @Environment(\.dismiss) private var dismiss

    init(assets: [PHAsset], initialIndex: Int = 0) {
        self.assets = assets
        _currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("\(currentIndex + 1) / \(assets.count)")
                    .font(.appSmallSemibold).foregroundStyle(Color.appTextSecondary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.appTextQuaternary)
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 12)

            // Images
            TabView(selection: $currentIndex) {
                ForEach(Array(assets.enumerated()), id: \.element.localIdentifier) { index, asset in
                    PreviewImage(asset: asset)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxHeight: .infinity)

            // Info bar
            let current = assets[currentIndex]
            VStack(spacing: 6) {
                Divider()
                HStack {
                    Text(current.fileSizeFormatted).font(.appCaption).foregroundStyle(Color.appTextSecondary)
                    Spacer()
                    Text(current.resolutionFormatted).font(.appMonoSmall).foregroundStyle(Color.appTextTertiary)
                    Spacer()
                    Text(current.creationDateFormatted).font(.appCaption).foregroundStyle(Color.appTextTertiary)
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
        .background(Color.appBackground)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

private struct PreviewImage: View {
    let asset: PHAsset
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fit)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.appBackgroundSecondary)
            }
        }
        .onAppear {
            guard image == nil else { return }
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .opportunistic
            opts.isNetworkAccessAllowed = false
            opts.resizeMode = .fast
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 800, height: 800),
                contentMode: .aspectFit,
                options: opts
            ) { img, _ in if let img { self.image = img } }
        }
    }
}
