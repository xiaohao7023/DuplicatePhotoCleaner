import SwiftUI
import Photos

// MARK: - Photo Preview Types

enum PhotoPreviewCategory {
    case best
    case others
    case videos
    case screenshots
    case blurry
    case similar
    case unfavorites

    var title: String {
        switch self {
        case .best: return String(localized: "Best Photo")
        case .others: return String(localized: "Other Copies")
        case .videos: return String(localized: "Videos")
        case .screenshots: return String(localized: "Screenshots")
        case .blurry: return String(localized: "Blurry Photos")
        case .similar: return String(localized: "Similar Photos")
        case .unfavorites: return String(localized: "Unfavorites")
        }
    }
}

// Used with .fullScreenCover(item:) so SwiftUI always creates a fresh view instance
struct PhotoPreviewContext: Identifiable, Equatable {
    let id = UUID()
    let assets: [PHAsset]
    let initialIndex: Int
    let category: PhotoPreviewCategory
    let reason: String
    let recommendedAsset: PHAsset?

    init(assets: [PHAsset], initialIndex: Int, category: PhotoPreviewCategory, reason: String, recommendedAsset: PHAsset? = nil) {
        self.assets = assets
        self.initialIndex = initialIndex
        self.category = category
        self.reason = reason
        self.recommendedAsset = recommendedAsset
    }

    static func == (lhs: PhotoPreviewContext, rhs: PhotoPreviewContext) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Full Screen Photo Viewer (iOS Photos style)

struct FullScreenPhotoViewer: View {
    let assets: [PHAsset]
    let initialIndex: Int
    var recommendedAsset: PHAsset?
    var onDelete: ((PHAsset) -> Void)?
    var onMarkFavorite: ((PHAsset) -> Void)?

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex: Int
    @State private var showUI = true
    @State private var showDeleteConfirmation = false
    @State private var showingPaywallWithUsage = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var dragOffset: CGSize = .zero
    @State private var deletedAssetIDs: Set<String> = []

    // Assets minus those deleted in this viewer session
    private var remainingAssets: [PHAsset] {
        assets.filter { !deletedAssetIDs.contains($0.localIdentifier) }
    }

    private var isCurrentBest: Bool {
        guard let recommended = recommendedAsset, currentIndex < remainingAssets.count else { return false }
        return remainingAssets[currentIndex].localIdentifier == recommended.localIdentifier
    }

    init(assets: [PHAsset], initialIndex: Int = 0,
         recommendedAsset: PHAsset? = nil,
         onDelete: ((PHAsset) -> Void)? = nil,
         onMarkFavorite: ((PHAsset) -> Void)? = nil) {
        self.assets = assets
        self.initialIndex = initialIndex
        self.recommendedAsset = recommendedAsset
        self.onDelete = onDelete
        self.onMarkFavorite = onMarkFavorite
        _currentIndex = State(initialValue: initialIndex)
    }

    init(context: PhotoPreviewContext,
         onDelete: ((PHAsset) -> Void)? = nil,
         onMarkFavorite: ((PHAsset) -> Void)? = nil) {
        self.assets = context.assets
        self.initialIndex = context.initialIndex
        self.recommendedAsset = context.recommendedAsset
        self.onDelete = onDelete
        self.onMarkFavorite = onMarkFavorite
        _currentIndex = State(initialValue: context.initialIndex)
    }

    var body: some View {
        ZStack {
            // Black background
            Color.black.ignoresSafeArea()

            // Photo carousel — DragGesture is on ZStack (not TabView) to avoid
            // overriding TabView's built-in horizontal page swipe
            TabView(selection: $currentIndex) {
                ForEach(Array(remainingAssets.enumerated()), id: \.element.localIdentifier) { index, asset in
                    ZoomablePhotoImage(asset: asset)
                        .tag(index)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showUI.toggle()
                            }
                        }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // UI Overlay
            VStack {
                // Top bar
                if showUI {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white.opacity(0.9))
                        }

                        Spacer()

                        // Best badge
                        if isCurrentBest {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 11))
                                Text("Best")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.appSuccess))
                        }

                        // Page indicator
                        Text("\(currentIndex + 1) / \(remainingAssets.count)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()

                // Bottom info bar
                if showUI && currentIndex < remainingAssets.count {
                    let asset = remainingAssets[currentIndex]
                    VStack(spacing: 12) {
                        // Photo info
                        HStack(spacing: 20) {
                            infoItem(icon: "arrow.up.arrow.down", text: asset.fileSizeFormatted)
                            infoItem(icon: "aspectratio", text: asset.resolutionFormatted)
                            infoItem(icon: "calendar", text: asset.creationDateShort)
                        }

                        // Action buttons
                        HStack(spacing: 12) {
                            if onMarkFavorite != nil {
                                Button {
                                    onMarkFavorite?(asset)
                                    toastMessage = String(localized: "Added to favorites")
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showToast = true }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "heart.fill")
                                        Text("Favorite")
                                    }
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        Capsule().fill(Color.pink.opacity(0.8))
                                    )
                                }
                            }

                            Button {
                                if !appState.isPurchased {
                                    if appState.freeDeletesRemainingBytes <= 0 || asset.fileSizeBytes > appState.freeDeletesRemainingBytes {
                                        // 直接拉起终身买断购买
                                        Task {
                                            let ok = await StoreKitManager.shared.purchaseLifetimeDirect()
                                            if ok {
                                                appState.purchasedProductIDs = StoreKitManager.shared.purchasedProductIDs
                                                deleteCurrentPhoto()
                                            }
                                        }
                                    } else if appState.deletePreference == .askEveryTime {
                                        showDeleteConfirmation = true
                                    } else {
                                        deleteCurrentPhoto()
                                    }
                                } else {
                                    if appState.deletePreference == .askEveryTime {
                                        showDeleteConfirmation = true
                                    } else {
                                        deleteCurrentPhoto()
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash.fill")
                                    Text("Delete")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule().fill(Color.red.opacity(0.8))
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .offset(y: dragOffset.height)
        .scaleEffect(1 - abs(dragOffset.height) / 1000)
        // Swipe-down-to-dismiss — on ZStack (not TabView) so horizontal swipes
        // are not captured and TabView's page gesture works correctly.
        .gesture(
            DragGesture()
                .onChanged { value in
                    if abs(value.translation.height) > abs(value.translation.width) {
                        dragOffset = value.translation
                    }
                }
                .onEnded { value in
                    if abs(value.translation.height) > 150 {
                        dismiss()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = .zero
                        }
                    }
                }
        )
        .preferredColorScheme(.dark)
        .statusBarHidden(!showUI)
        .sheet(isPresented: $showDeleteConfirmation) {
            DeletePreferencePickerView { deleteCurrentPhoto() }
                .environment(appState)
                .presentationDetents([.medium])
        }
        .overlay(alignment: .top) {
            if showToast {
                SuccessToast(message: toastMessage)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showToast = false }
                        }
                    }
            }
        }
    }

    private func infoItem(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(text)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(.white.opacity(0.7))
    }

    private func deleteCurrentPhoto() {
        guard currentIndex < remainingAssets.count else { return }
        let asset = remainingAssets[currentIndex]
        let bytes = asset.fileSizeBytes
        // Capture the index before the async task so the deletion handler always
        // refers to the photo the user tapped Delete on, even if they swiped away.
        let indexAtDelete = currentIndex

        Task {
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.deleteAssets([asset] as NSArray)
                }
                await MainActor.run {
                    if !appState.isPurchased {
                        _ = appState.consumeFreeQuota(bytes: bytes, deletedCount: 1)
                    } else {
                        appState.recordCleanup(freedBytes: bytes, deletedCount: 1)
                    }
                    HapticManager.notification(.success)
                    onDelete?(asset)

                    // Mark deleted so remainingAssets shrinks and TabView skips it
                    deletedAssetIDs.insert(asset.localIdentifier)
                    let newRemaining = remainingAssets.count

                    if newRemaining <= 1 {
                        // Only 1 (or 0) photo left — parent will dismiss the group
                        dismiss()
                    } else {
                        // Advance to next photo (wrap to start if at the end)
                        var newIndex = indexAtDelete
                        while deletedAssetIDs.contains(assets[newIndex].localIdentifier) {
                            newIndex = (newIndex + 1) % assets.count
                        }
                        currentIndex = newIndex

                        toastMessage = String(localized: "Photo deleted")
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showToast = true }
                    }
                }
            } catch {
                await MainActor.run {
                    HapticManager.notification(.error)
                    toastMessage = String(localized: "Delete was cancelled")
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showToast = true }
                }
            }
        }
    }
}

// MARK: - Zoomable Photo Image

private struct ZoomablePhotoImage: View {
    let asset: PHAsset
    @State private var image: UIImage?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale = min(max(scale * delta, 1), 5)
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                    if scale < 1.1 {
                                        withAnimation(.spring()) {
                                            scale = 1.0
                                            offset = .zero
                                        }
                                    }
                                }
                        )
                        // Pan gesture only when zoomed; ViewModifier ensures the
                        // DragGesture is NOT registered at all when scale==1, so
                        // TabView's horizontal page swipe is never blocked.
                        .modifier(ConditionalPanGesture(
                            enabled: scale > 1,
                            offset: $offset,
                            lastOffset: $lastOffset
                        ))
                        .onTapGesture(count: 2) {
                            withAnimation(.spring()) {
                                if scale > 1 {
                                    scale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 2.5
                                }
                            }
                        }
                } else {
                    Color.black
                    ProgressView()
                        .tint(.white)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .onAppear { loadImage() }
    }

    private func loadImage() {
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .highQualityFormat
        opts.isNetworkAccessAllowed = true
        opts.version = .current
        opts.resizeMode = .none

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: opts
        ) { img, info in
            let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
            if let img, !isDegraded {
                DispatchQueue.main.async { self.image = img }
            }
        }
    }
}

// MARK: - Conditional Pan Gesture Modifier

/// Applies a simultaneous DragGesture only when `enabled` is true.
/// When disabled, no DragGesture is registered at all — critical for allowing
/// TabView's built-in horizontal page swipe to work without competition.
private struct ConditionalPanGesture: ViewModifier {
    let enabled: Bool
    @Binding var offset: CGSize
    @Binding var lastOffset: CGSize

    func body(content: Content) -> some View {
        if enabled {
            content.simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        offset = CGSize(
                            width: lastOffset.width + value.translation.width,
                            height: lastOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in
                        lastOffset = offset
                    }
            )
        } else {
            content
        }
    }
}

// MARK: - PHAsset Extension for short date

extension PHAsset {
    var creationDateShort: String {
        guard let date = creationDate else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
