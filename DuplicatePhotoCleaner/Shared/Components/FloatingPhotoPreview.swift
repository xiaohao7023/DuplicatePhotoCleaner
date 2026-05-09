import SwiftUI
import Photos

enum PhotoPreviewCategory {
    case best
    case others

    var title: String {
        switch self {
        case .best: return "Best Photo"
        case .others: return "Other Copies"
        }
    }
}

// Used with .sheet(item:) so SwiftUI always creates a fresh view instance
struct PhotoPreviewContext: Identifiable, Equatable {
    let id = UUID()
    let assets: [PHAsset]
    let initialIndex: Int
    let category: PhotoPreviewCategory
    let reason: String
}

struct FloatingPhotoPreview: View {
    let assets: [PHAsset]
    let initialIndex: Int
    let category: PhotoPreviewCategory
    let reason: String
    var onDelete: ((PHAsset) -> Void)?
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int
    @State private var initialImage: UIImage?
    @State private var showDeleteConfirmation = false

    init(assets: [PHAsset], initialIndex: Int = 0, category: PhotoPreviewCategory = .others, reason: String = "", onDelete: ((PHAsset) -> Void)? = nil) {
        self.assets = assets
        self.initialIndex = initialIndex
        self.category = category
        self.reason = reason
        self.onDelete = onDelete
        _currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title
            Text(category.title)
                .font(.appH3)
                .foregroundStyle(Color.appTextPrimary)
                .padding(.top, 20)
                .padding(.bottom, 16)

            // Swipeable images
            TabView(selection: $currentIndex) {
                ForEach(Array(assets.enumerated()), id: \.element.localIdentifier) { index, asset in
                    PhotoSheetImage(
                        asset: asset,
                        preloadImage: index == initialIndex ? initialImage : nil
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 360)
            .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
            .padding(.horizontal, 24)

            // Page indicator
            if assets.count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<assets.count, id: \.self) { i in
                        Circle()
                            .fill(i == currentIndex ? Color.appPrimary : Color.appBackgroundTertiary)
                            .frame(width: 7, height: 7)
                    }
                }
                .padding(.top, 10)
            }

            // Photo info
            if currentIndex < assets.count {
                let current = assets[currentIndex]
                VStack(spacing: 10) {
                    Divider().padding(.horizontal, 24).padding(.top, 10)

                    InfoRow(icon: "arrow.up.arrow.down", label: "Size",
                            value: current.fileSizeFormatted, color: Color.appPrimary)
                    InfoRow(icon: "aspectratio", label: "Resolution",
                            value: current.resolutionFormatted, color: Color.appTeal)
                    InfoRow(icon: "calendar", label: "Date",
                            value: current.creationDateFormatted, color: Color.appCamel)
                    if !reason.isEmpty {
                        InfoRow(icon: category == .best ? "star.fill" : "info.circle",
                                label: "Why",
                                value: reason,
                                color: category == .best ? Color.appSuccess : Color.appPurple)
                    }

                    // Delete button
                    Button {
                        if appState.deletePreference == .askEveryTime {
                            showDeleteConfirmation = true
                        } else {
                            deleteCurrentPhoto()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash").font(.system(size: 14, weight: .medium))
                            Text("Delete This Photo").font(.appSmallSemibold)
                        }
                        .foregroundStyle(Color.appDanger)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .strokeBorder(Color.appDanger.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(.top, 4)
                .padding(.horizontal, 24)
            }

            Spacer(minLength: 16)
        }
        .background(Color.appBackground)
        .presentationDetents([.fraction(0.82), .large])
        .presentationDragIndicator(.hidden)
        .sheet(isPresented: $showDeleteConfirmation) {
            DeletePreferencePickerView { deleteCurrentPhoto() }
                .environment(appState)
        }
        .onAppear { preloadInitial() }
    }

    private func deleteCurrentPhoto() {
        guard currentIndex < assets.count else { return }
        let asset = assets[currentIndex]
        let bytes = asset.fileSizeBytes
        Task {
            try? await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets([asset] as NSArray)
            }
            await MainActor.run {
                HapticManager.notification(.success)
                appState.recordCleanup(freedBytes: bytes, deletedCount: 1)
                onDelete?(asset)
                dismiss()
            }
        }
    }

    private func preloadInitial() {
        guard initialIndex < assets.count, initialImage == nil else { return }
        let asset = assets[initialIndex]

        // Stage 1: fast opportunistic thumbnail
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .opportunistic
        opts.isNetworkAccessAllowed = true
        opts.version = .current
        opts.resizeMode = .fast
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 1200, height: 1200),
            contentMode: .aspectFit,
            options: opts
        ) { img, _ in
            if let img {
                DispatchQueue.main.async { self.initialImage = img }
            }
        }

        // Stage 2: high quality replacement
        let hiOpts = PHImageRequestOptions()
        hiOpts.deliveryMode = .highQualityFormat
        hiOpts.isNetworkAccessAllowed = true
        hiOpts.version = .current
        hiOpts.resizeMode = .none
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 1200, height: 1200),
            contentMode: .aspectFit,
            options: hiOpts
        ) { img, info in
            let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
            if let img, !isDegraded {
                DispatchQueue.main.async { self.initialImage = img }
            }
        }
    }
}

// MARK: - Info Row

private struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous).fill(color.opacity(0.1)))
            Text(label)
                .font(.appCaption)
                .foregroundStyle(Color.appTextSecondary)
            Spacer()
            Text(value)
                .font(.appCaptionMedium)
                .foregroundStyle(Color.appTextPrimary)
        }
    }
}

// MARK: - Image Loader

private struct PhotoSheetImage: View {
    let asset: PHAsset
    var preloadImage: UIImage?
    @State private var image: UIImage?

    private var displayImage: UIImage? { image ?? preloadImage }

    var body: some View {
        Group {
            if let displayImage {
                Image(uiImage: displayImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .background(Color.appBackgroundSecondary)
            } else {
                ZStack {
                    Color.appBackgroundSecondary
                    ProgressView()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { loadImage() }
    }

    private func loadImage() {
        guard image == nil, preloadImage == nil else { return }
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .highQualityFormat
        opts.isNetworkAccessAllowed = true
        opts.version = .current
        opts.resizeMode = .none
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 1200, height: 1200),
            contentMode: .aspectFit,
            options: opts
        ) { img, info in
            let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
            guard !isDegraded else { return }
            if let img {
                DispatchQueue.main.async { self.image = img }
            }
        }
    }
}
