import SwiftUI
import Photos

struct SimilarGroupsView: View {
    let groups: [SimilarGroup]
    var onGroupsChanged: (([SimilarGroup]) -> Void)?
    @Environment(AppState.self) private var appState
    @State private var selectedForDeletion: Set<String> = []
    @State private var showDeleteConfirmation = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var previewContext: PhotoPreviewContext?
    @State private var locallyDeletedAssetIDs: Set<String> = []

    private var visibleGroups: [SimilarGroup] {
        groups.compactMap { group in
            let remaining = group.assets.filter { !locallyDeletedAssetIDs.contains($0.localIdentifier) }
            guard remaining.count > 1 else { return nil }
            let recommended = remaining.first(where: { $0.localIdentifier == group.recommended.localIdentifier }) ?? remaining[0]
            return SimilarGroup(assets: remaining, recommended: recommended, averageSimilarity: group.averageSimilarity)
        }
    }

    private var selectedAssets: [PHAsset] {
        visibleGroups.flatMap { $0.assets }.filter { selectedForDeletion.contains($0.localIdentifier) }
    }

    private var allOtherIDs: [String] {
        visibleGroups.flatMap { group in
            group.assets.filter { $0.localIdentifier != group.recommended.localIdentifier }.map(\.localIdentifier)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(Array(visibleGroups.enumerated()), id: \.element.assets.first?.localIdentifier) { index, group in
                    SimGroupSection(
                        group: group, index: index,
                        selectedForDeletion: selectedForDeletion,
                        onToggle: { asset in
                            HapticManager.selection()
                            if selectedForDeletion.contains(asset.localIdentifier) {
                                selectedForDeletion.remove(asset.localIdentifier)
                            } else {
                                selectedForDeletion.insert(asset.localIdentifier)
                            }
                        },
                        onTapPhoto: { asset, category in
                            // Pass ALL photos in the group for swipeable browsing
                            let allPhotos = group.assets
                            let initialIndex = allPhotos.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }) ?? 0

                            let best = group.recommended
                            let reason: String
                            if asset.localIdentifier == best.localIdentifier {
                                let bestPixels = best.pixelWidth * best.pixelHeight
                                let bestSize = best.fileSizeBytes
                                let others = group.assets.filter { $0.localIdentifier != best.localIdentifier }
                                let maxOtherPixels = others.map { $0.pixelWidth * $0.pixelHeight }.max() ?? 0
                                let maxOtherSize = others.map { $0.fileSizeBytes }.max() ?? 0
                                if bestPixels > maxOtherPixels {
                                    reason = String(localized: "Highest resolution")
                                } else if bestSize > maxOtherSize {
                                    reason = String(localized: "Largest file size (better quality)")
                                } else {
                                    reason = String(localized: "Original copy (oldest)")
                                }
                            } else {
                                let otherPixels = asset.pixelWidth * asset.pixelHeight
                                let otherSize = asset.fileSizeBytes
                                let bestPixels = best.pixelWidth * best.pixelHeight
                                let bestSize = best.fileSizeBytes
                                if otherPixels < bestPixels {
                                    reason = String(localized: "Lower resolution")
                                } else if otherSize < bestSize {
                                    reason = String(localized: "Smaller file (more compressed)")
                                } else {
                                    reason = String(localized: "Same quality, newer copy")
                                }
                            }
                            previewContext = PhotoPreviewContext(
                                assets: allPhotos,
                                initialIndex: initialIndex,
                                category: category,
                                reason: reason,
                                recommendedAsset: group.recommended
                            )
                        }
                    )
                }
            }
            .padding(.horizontal, Layout.pageHorizontalPadding)
            .padding(.top, Layout.headerToContent)
            .padding(.bottom, 100)
        }
        .background(Color.appBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                let allSelected = !allOtherIDs.isEmpty && allOtherIDs.allSatisfy { selectedForDeletion.contains($0) }
                Button {
                    HapticManager.selection()
                    Task { @MainActor in
                        if allSelected {
                            selectedForDeletion.removeAll()
                        } else {
                            selectedForDeletion = Set(allOtherIDs)
                        }
                    }
                } label: {
                    Text(allSelected ? "Deselect All" : "Select All")
                        .font(.appCaptionMedium)
                        .foregroundStyle(Color.appPrimary)
                }
            }
        }
        .overlay(alignment: .bottom) {
            let count = selectedForDeletion.count
            let bytes = selectedAssets.reduce(Int64(0)) { $0 + $1.fileSizeBytes }
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 3) {
                        if count > 0 {
                            Text("Free up \(formatBytes(bytes))")
                                .font(.appH3).foregroundStyle(Color.appTextPrimary)
                            Text("\(count) similar photo selected")
                                .font(.appCaption).foregroundStyle(Color.appTextSecondary)
                        } else {
                            Text("No items selected")
                                .font(.appCaption).foregroundStyle(Color.appTextTertiary)
                        }
                    }
                    Spacer()
                    Button {
                        if !appState.isPurchased {
                            // 未付费 → 检查免费额度；不足时直接拉起终身买断购买
                            if appState.freeDeletesRemainingBytes <= 0 || bytes > appState.freeDeletesRemainingBytes {
                                Task {
                                    let ok = await StoreKitManager.shared.purchaseLifetimeDirect()
                                    if ok {
                                        appState.purchasedProductIDs = StoreKitManager.shared.purchasedProductIDs
                                        deleteSelected()
                                    }
                                }
                            } else if appState.deletePreference == .askEveryTime {
                                showDeleteConfirmation = true
                            } else {
                                deleteSelected()
                            }
                        } else {
                            // 已付费 → 直接进入删除偏好选择
                            if appState.deletePreference == .askEveryTime { showDeleteConfirmation = true }
                            else { deleteSelected() }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash.fill").font(.system(size: 15, weight: .semibold))
                            Text(count > 0 ? "Delete \(count)" : "Delete").font(.appBody)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24).padding(.vertical, 14)
                        .background(Capsule().fill(Color.appDanger))
                    }
                    .buttonStyle(.plain)
                    .disabled(count == 0)
                    .opacity(count == 0 ? 0.5 : 1.0)
                }
                .padding(.horizontal, 20).padding(.vertical, 18)
                .background(Color.appBackground)
            }
        }
        .sheet(isPresented: $showDeleteConfirmation) {
            DeletePreferencePickerView { deleteSelected() }
                .environment(appState)
        }
        .fullScreenCover(item: $previewContext) { ctx in
            FullScreenPhotoViewer(context: ctx, onDelete: { deleted in
                withAnimation {
                    locallyDeletedAssetIDs.insert(deleted.localIdentifier)
                    onGroupsChanged?(visibleGroups)
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
        .task {
            let othersIDs = visibleGroups.flatMap { group in
                group.assets.filter { $0.localIdentifier != group.recommended.localIdentifier }.map(\.localIdentifier)
            }
            selectedForDeletion = Set(othersIDs)
        }
    }

    private func deleteSelected() {
        let assets = selectedAssets
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
                    withAnimation { onGroupsChanged?(visibleGroups) }
                    toastMessage = String(localized: "\(count) similar photo deleted")
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

    private func formatBytes(_ b: Int64) -> String {
        let f = ByteCountFormatter(); f.allowedUnits = [.useGB, .useMB]; f.countStyle = .file
        return f.string(fromByteCount: b)
    }
}

// MARK: - Group Section

private struct SimGroupSection: View {
    let group: SimilarGroup; let index: Int
    let selectedForDeletion: Set<String>
    let onToggle: (PHAsset) -> Void
    let onTapPhoto: (PHAsset, PhotoPreviewCategory) -> Void

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    private var bestAsset: PHAsset { group.recommended }
    private var otherAssets: [PHAsset] { group.assets.filter { $0.localIdentifier != bestAsset.localIdentifier } }

    var body: some View {
        VStack(spacing: 8) {
            // Section header
            HStack {
                Text("GROUP \(index + 1)")
                    .font(.appSmallSemibold)
                    .foregroundStyle(Color.appTextSecondary)
                    .tracking(0.6)
                Spacer()
                Text(String(format: "%d%% similar", Int(round(group.averageSimilarity * 100))))
                    .font(.appCaptionMedium)
                    .foregroundStyle(Color.appTeal)
            }

            // 3-column grid: Best first, then Others
            LazyVGrid(columns: gridColumns, spacing: 2) {
                // Best photo
                SimGridCell(
                    asset: bestAsset,
                    isSelected: selectedForDeletion.contains(bestAsset.localIdentifier),
                    isBest: true,
                    onSelect: { onToggle(bestAsset) },
                    onPreview: { onTapPhoto(bestAsset, .best) }
                )

                // Other photos
                ForEach(otherAssets, id: \.localIdentifier) { asset in
                    SimGridCell(
                        asset: asset,
                        isSelected: selectedForDeletion.contains(asset.localIdentifier),
                        isBest: false,
                        onSelect: { onToggle(asset) },
                        onPreview: { onTapPhoto(asset, .others) }
                    )
                }
            }
        }
    }
}

// MARK: - Grid Cell

private struct SimGridCell: View {
    let asset: PHAsset
    let isSelected: Bool
    let isBest: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void

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
                if isBest {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill").font(.system(size: 9))
                        Text("BEST").font(.system(size: 8, weight: .bold)).tracking(0.5)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.appSuccess))
                    .padding(5)
                }
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
                .onTapGesture { onSelect() }
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
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .opportunistic
        opts.isNetworkAccessAllowed = false
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 200, height: 200),
            contentMode: .aspectFill,
            options: opts
        ) { img, _ in
            if let img { DispatchQueue.main.async { self.thumbnail = img } }
        }
    }
}
