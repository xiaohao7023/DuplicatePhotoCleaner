import SwiftUI
import Photos

struct PhotoViewerView: View {
    let assets: [PHAsset]
    @State private var currentIndex: Int
    @Environment(\.dismiss) private var dismiss

    init(assets: [PHAsset], initialIndex: Int = 0) {
        self.assets = assets
        _currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            TabView(selection: $currentIndex) {
                ForEach(Array(assets.enumerated()), id: \.element.localIdentifier) { index, asset in
                    ZoomableImage(asset: asset).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white).frame(width: 36, height: 36)
                            .background(Circle().fill(.black.opacity(0.5)))
                    }.padding(.leading, 16).padding(.top, 8)
                    Spacer()
                    Text("\(currentIndex + 1)/\(assets.count)").font(.appCaptionMedium)
                        .foregroundStyle(.white).padding(.trailing, 16).padding(.top, 8)
                }
                Spacer()
            }
        }
    }
}

private struct ZoomableImage: View {
    let asset: PHAsset; @State private var image: UIImage?
    @State private var scale: CGFloat = 1.0; @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero; @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { _ in
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fit)
                    .scaleEffect(scale).offset(offset)
                    .gesture(MagnificationGesture()
                        .onChanged { value in scale = lastScale * value }
                        .onEnded { _ in
                            withAnimation(.spring()) {
                                if scale < 1 { scale = 1; offset = .zero }
                                if scale > 3 { scale = 3 }
                            }
                            lastScale = scale
                        })
                    .simultaneousGesture(DragGesture()
                        .onChanged { value in
                            if scale > 1 {
                                offset = CGSize(width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height)
                            }
                        }
                        .onEnded { _ in lastOffset = offset })
                    .onTapGesture(count: 2) {
                        withAnimation(.spring()) {
                            if scale > 1 { scale = 1; offset = .zero; lastOffset = .zero; lastScale = 1 }
                            else { scale = 2; lastScale = 2 }
                        }
                    }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear { loadFullImage() }
            }
        }
    }

    private func loadFullImage() {
        let opts = PHImageRequestOptions(); opts.deliveryMode = .highQualityFormat; opts.isNetworkAccessAllowed = false
        PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize,
            contentMode: .default, options: opts) { img, _ in if let img { self.image = img } }
    }
}
