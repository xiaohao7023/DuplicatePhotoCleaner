import SwiftUI
import Photos

struct ScreenshotsView: View {
    var onGroupsChanged: (([ScreenshotGroupData]) -> Void)?
    @State private var displayedGroups: [ScreenshotGroupData]
    @Environment(AppState.self) private var appState
    @State private var selectedForDeletion: Set<String> = []
    @State private var showDeleteConfirmation = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var previewContext: PhotoPreviewContext?
    init(groups: [ScreenshotGroupData], onGroupsChanged: (([ScreenshotGroupData]) -> Void)? = nil) {
        _displayedGroups = State(initialValue: groups)
        self.onGroupsChanged = onGroupsChanged
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Layout.cardSpacing) {
                ForEach(displayedGroups, id: \.group) { groupData in
                    ScreenshotSection(groupData: groupData, selectedForDeletion: selectedForDeletion,
                                      onTogglePhoto: { id in
                        HapticManager.selection()
                        if selectedForDeletion.contains(id) { selectedForDeletion.remove(id) }
                        else { selectedForDeletion.insert(id) }
                    }, onPreviewPhoto: { asset in
                        let allAssets = displayedGroups.flatMap { $0.assets }
                        if let idx = allAssets.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }) {
                            previewContext = PhotoPreviewContext(assets: allAssets, initialIndex: idx, category: .screenshots, reason: "")
                        }
                    })
                }
            }
            .padding(.horizontal, Layout.pageHorizontalPadding)
            .padding(.top, Layout.headerToContent).padding(.bottom, 100)
        }
        .background(Color.appBackground)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                let allIDs = displayedGroups.flatMap { $0.assets.map(\.localIdentifier) }
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
            let selectedAssets = displayedGroups.flatMap(\.assets).filter { selectedForDeletion.contains($0.localIdentifier) }
            let bytes = selectedAssets.reduce(Int64(0)) { $0 + $1.fileSizeBytes }
            CleanupDeleteBar(selectedCount: count, selectedBytes: bytes, itemKind: .screenshot) {
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
                    let updated = groupsRemoving(Set([deleted.localIdentifier]))
                    displayedGroups = updated
                    onGroupsChanged?(updated)
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
        let assets = displayedGroups.flatMap(\.assets).filter { selectedForDeletion.contains($0.localIdentifier) }
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
                    let updated = groupsRemoving(Set(assets.map(\.localIdentifier)))
                    selectedForDeletion.removeAll()
                    withAnimation {
                        displayedGroups = updated
                        onGroupsChanged?(updated)
                    }
                    toastMessage = String(localized: "\(count) screenshot deleted")
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

    private func groupsRemoving(_ deletedIDs: Set<String>) -> [ScreenshotGroupData] {
        displayedGroups.compactMap { group in
            let remaining = group.assets.filter { !deletedIDs.contains($0.localIdentifier) }
            guard !remaining.isEmpty else { return nil }
            return ScreenshotGroupData(
                group: group.group,
                assets: remaining,
                totalSize: remaining.reduce(0) { $0 + $1.fileSizeBytes }
            )
        }
    }
}

private struct ScreenshotSection: View {
    let groupData: ScreenshotGroupData
    let selectedForDeletion: Set<String>
    let onTogglePhoto: (String) -> Void
    let onPreviewPhoto: (PHAsset) -> Void

    var body: some View {
        RoundedCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(groupData.group.displayName)
                        .font(.appSmallSemibold).foregroundStyle(Color.appTextSecondary)
                        .textCase(.uppercase).tracking(0.6)
                    Spacer()
                    Text("\(groupData.assets.count) screenshots  •  \(formatBytes(groupData.totalSize))")
                        .font(.appCaption).foregroundStyle(Color.appPurple)
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2)], spacing: 2) {
                    ForEach(groupData.assets, id: \.localIdentifier) { asset in
                        SSThumb(asset: asset, isSelected: selectedForDeletion.contains(asset.localIdentifier),
                                onToggle: { onTogglePhoto(asset.localIdentifier) },
                                onPreview: { onPreviewPhoto(asset) })
                    }
                }
            }
        }
    }

    private func formatBytes(_ b: Int64) -> String {
        let f = ByteCountFormatter(); f.allowedUnits = [.useGB, .useMB]; f.countStyle = .file
        return f.string(fromByteCount: b)
    }
}

private struct SSThumb: View {
    let asset: PHAsset; let isSelected: Bool; let onToggle: () -> Void; let onPreview: () -> Void
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
        let opts = PHImageRequestOptions(); opts.deliveryMode = .opportunistic; opts.isNetworkAccessAllowed = false
        PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 200, height: 200),
            contentMode: .aspectFill, options: opts) { img, _ in
            if let img { DispatchQueue.main.async { self.thumbnail = img } }
        }
    }
}
