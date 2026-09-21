import SwiftUI
import Photos

struct BlurryPhotosView: View {
    let photos: [PhotoQuality]
    var onPhotosChanged: (([PhotoQuality]) -> Void)?
    @Environment(AppState.self) private var appState
    @State private var selectedForDeletion: Set<String> = []
    @State private var showDeleteConfirmation = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var blurThreshold: BlurDetector.BlurLevel = .blurry
    @State private var previewContext: PhotoPreviewContext?
    @State private var locallyDeletedAssetIDs: Set<String> = []

    private var visiblePhotos: [PhotoQuality] {
        photos.filter { !locallyDeletedAssetIDs.contains($0.asset.localIdentifier) }
    }

    private var filteredPhotos: [PhotoQuality] { visiblePhotos.filter { $0.blurScore < blurThreshold.threshold } }

    var body: some View {
        ScrollView {
            VStack(spacing: Layout.cardSpacing) {
                RoundedCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Blur Threshold").font(.appSmallSemibold).foregroundStyle(Color.appTextSecondary)
                            .textCase(.uppercase).tracking(0.6)
                        HStack(spacing: 8) {
                            ForEach(BlurDetector.BlurLevel.allCases, id: \.self) { level in
                                Button { withAnimation { blurThreshold = level } } label: {
                                    Text(level.displayName).font(.appTinySemibold)
                                        .foregroundStyle(blurThreshold == level ? .white : Color.appTextPrimary)
                                        .padding(.horizontal, 12).padding(.vertical, 8)
                                        .background(Capsule().fill(blurThreshold == level ? Color.appPrimary : Color.appBackgroundTertiary))
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }
                Text("\(filteredPhotos.count) BLURRY PHOTOS").sectionHeaderStyle()
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2)], spacing: 2) {
                    ForEach(filteredPhotos, id: \.asset.localIdentifier) { photo in
                        BlurryCell(photo: photo, isSelected: selectedForDeletion.contains(photo.asset.localIdentifier),
                                   onToggle: {
                            HapticManager.selection()
                            if selectedForDeletion.contains(photo.asset.localIdentifier) { selectedForDeletion.remove(photo.asset.localIdentifier) }
                            else { selectedForDeletion.insert(photo.asset.localIdentifier) }
                        }, onPreview: {
                            let assets = filteredPhotos.map { $0.asset }
                            if let idx = assets.firstIndex(where: { $0.localIdentifier == photo.asset.localIdentifier }) {
                                previewContext = PhotoPreviewContext(assets: assets, initialIndex: idx, category: .blurry,
                                                                    reason: String(localized: "Blur score: \(Int(photo.blurScore))"))
                            }
                        })
                    }
                }
            }
            .padding(.horizontal, Layout.pageHorizontalPadding)
            .padding(.bottom, 100)
        }
        .background(Color.appBackground)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                let allIDs = filteredPhotos.map { $0.asset.localIdentifier }
                let allSelected = !allIDs.isEmpty && allIDs.allSatisfy { selectedForDeletion.contains($0) }
                Button {
                    HapticManager.selection()
                    Task { @MainActor in
                        if allSelected {
                            selectedForDeletion.removeAll()
                        } else {
                            selectedForDeletion = Set(allIDs)
                        }
                    }
                } label: {
                    Text(allSelected ? "Deselect All" : "Select All")
                        .font(.appCaptionMedium)
                        .foregroundStyle(Color.appPrimary)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .overlay(alignment: .bottom) {
            let count = selectedForDeletion.count
            let selected = filteredPhotos.filter { selectedForDeletion.contains($0.asset.localIdentifier) }
            let bytes = selected.reduce(Int64(0)) { $0 + $1.fileSize }
            CleanupDeleteBar(selectedCount: count, selectedBytes: bytes, itemKind: .blurryPhoto) {
                if !appState.isPurchased {
                    // 未付费 → 检查免费额度；不足时直接拉起终身买断购买
                    if appState.freeDeletesRemainingBytes <= 0 || bytes > appState.freeDeletesRemainingBytes {
                        Task {
                            let ok = await StoreKitManager.shared.purchaseLifetimeDirect()
                            if ok {
                                appState.purchasedProductIDs = StoreKitManager.shared.purchasedProductIDs
                                deletePhotos()
                            }
                        }
                    } else if appState.deletePreference == .askEveryTime {
                        showDeleteConfirmation = true
                    } else {
                        deletePhotos()
                    }
                } else {
                    // 已付费 → 直接进入删除偏好选择
                    if appState.deletePreference == .askEveryTime { showDeleteConfirmation = true }
                    else { deletePhotos() }
                }
            }
        }
        .sheet(isPresented: $showDeleteConfirmation) {
            DeletePreferencePickerView { deletePhotos() }
                .environment(appState)
        }
        .fullScreenCover(item: $previewContext) { ctx in
            FullScreenPhotoViewer(context: ctx, onDelete: { deleted in
                withAnimation {
                    locallyDeletedAssetIDs.insert(deleted.localIdentifier)
                    onPhotosChanged?(visiblePhotos)
                }
            })
            .environment(appState)
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

    private func deletePhotos() {
        let assets = filteredPhotos.filter { selectedForDeletion.contains($0.asset.localIdentifier) }.map { $0.asset }
        let count = assets.count
        let bytes = assets.reduce(Int64(0)) { $0 + $1.fileSizeBytes }

        Task {
            do {
                try await PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.deleteAssets(assets as NSArray) }
                await MainActor.run {
                    // V1.1: 消耗免费额度 (仅删除成功后)
                    if !appState.isPurchased {
                        let _ = appState.consumeFreeQuota(bytes: bytes, deletedCount: count)
                    } else {
                        appState.recordCleanup(freedBytes: bytes, deletedCount: count)
                    }
                    HapticManager.notification(.success)
                    locallyDeletedAssetIDs.formUnion(assets.map(\.localIdentifier))
                    selectedForDeletion.removeAll()
                    withAnimation { onPhotosChanged?(visiblePhotos) }
                    toastMessage = String(localized: "\(count) photo deleted")
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showToast = true }
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

private struct BlurryCell: View {
    let photo: PhotoQuality; let isSelected: Bool; let onToggle: () -> Void; let onPreview: () -> Void
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
                Text(String(format: "%.0f", photo.blurScore))
                    .font(.appMicro).foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Capsule().fill(photo.blurLevel == .veryBlurry ? Color.appDanger : Color.appWarning))
                    .padding(5)
            }
            .overlay(alignment: .topTrailing) {
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
                .contentShape(Circle().inset(by: -8))
                .onTapGesture { onToggle() }
            }
            .overlay {
                if isSelected {
                    Rectangle()
                        .fill(Color.appRose.opacity(0.15))
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onPreview() }
            .onAppear { loadThumbnail() }
            .onDisappear { thumbnail = nil }
    }
    private func loadThumbnail() {
        guard thumbnail == nil else { return }
        let opts = PHImageRequestOptions(); opts.deliveryMode = .opportunistic; opts.isNetworkAccessAllowed = false
        PHImageManager.default().requestImage(for: photo.asset, targetSize: CGSize(width: 200, height: 200),
            contentMode: .aspectFill, options: opts) { img, _ in
            if let img { DispatchQueue.main.async { self.thumbnail = img } }
        }
    }
}
