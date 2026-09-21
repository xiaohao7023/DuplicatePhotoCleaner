import SwiftUI
import Photos
import AVKit

struct VideosView: View {
    let videos: [PHAsset]
    var onVideosChanged: (([PHAsset]) -> Void)?
    @Environment(AppState.self) private var appState
    @State private var selectedForDeletion: Set<String> = []
    @State private var showDeleteConfirmation = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var previewAsset: PHAsset?

    private var selectedAssets: [PHAsset] {
        videos.filter { selectedForDeletion.contains($0.localIdentifier) }
    }

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 2) {
                ForEach(videos, id: \.localIdentifier) { asset in
                    VideoGridCell(
                        asset: asset,
                        isSelected: selectedForDeletion.contains(asset.localIdentifier),
                        onSelect: {
                            HapticManager.selection()
                            if selectedForDeletion.contains(asset.localIdentifier) {
                                selectedForDeletion.remove(asset.localIdentifier)
                            } else {
                                selectedForDeletion.insert(asset.localIdentifier)
                            }
                        },
                        onPreview: { previewAsset = asset }
                    )
                }
            }
            .padding(.top, Layout.headerToContent)
            .padding(.bottom, 100)
        }
        .padding(.horizontal, Layout.pageHorizontalPadding)
        .background(Color.appBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                let allSelected = !videos.isEmpty && videos.allSatisfy { selectedForDeletion.contains($0.localIdentifier) }
                Button {
                    HapticManager.selection()
                    Task { @MainActor in
                        if allSelected {
                            selectedForDeletion.removeAll()
                        } else {
                            selectedForDeletion = Set(videos.map(\.localIdentifier))
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
                            Text("\(count) video selected")
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
        .sheet(isPresented: Binding(
            get: { previewAsset != nil },
            set: { if !$0 { previewAsset = nil } }
        )) {
            if let asset = previewAsset {
                VideoPreviewSheet(asset: asset) {
                    previewAsset = nil
                    deleteAsset(asset)
                }
                .environment(appState)
            }
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
                        _ = appState.consumeFreeQuota(bytes: bytes, deletedCount: count)
                    } else {
                        appState.recordCleanup(freedBytes: bytes, deletedCount: count)
                    }
                    HapticManager.notification(.success)
                    let deletedIDs = selectedForDeletion
                    let updated = videos.filter { !deletedIDs.contains($0.localIdentifier) }
                    selectedForDeletion.removeAll()
                    withAnimation { onVideosChanged?(updated) }
                    toastMessage = String(localized: "\(count) video deleted")
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

    private func deleteAsset(_ asset: PHAsset) {
        let bytes = asset.fileSizeBytes

        Task {
            do {
                try await PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.deleteAssets([asset] as NSArray) }
                await MainActor.run {
                    // V1.1: 消耗免费额度 (仅删除成功后)
                    if !appState.isPurchased {
                        _ = appState.consumeFreeQuota(bytes: bytes, deletedCount: 1)
                    } else {
                        appState.recordCleanup(freedBytes: bytes, deletedCount: 1)
                    }
                    HapticManager.notification(.success)
                    let updated = videos.filter { $0.localIdentifier != asset.localIdentifier }
                    withAnimation { onVideosChanged?(updated) }
                    toastMessage = String(localized: "Video deleted")
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

// MARK: - Video Grid Cell

private struct VideoGridCell: View {
    let asset: PHAsset
    let isSelected: Bool
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
            .overlay {
                Image(systemName: "play.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 3)
            }
            .overlay(alignment: .bottomLeading) {
                if !asset.durationFormatted.isEmpty {
                    Text(asset.durationFormatted)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.black.opacity(0.6)))
                        .padding(4)
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
            for: asset, targetSize: CGSize(width: 200, height: 200),
            contentMode: .aspectFill, options: opts
        ) { img, _ in
            if let img { DispatchQueue.main.async { self.thumbnail = img } }
        }
    }
}

// MARK: - Video Preview Sheet

private struct VideoPreviewSheet: View {
    let asset: PHAsset
    var onDelete: (() -> Void)?
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var thumbnail: UIImage?
    @State private var showDeleteConfirmation = false
    @State private var player: AVPlayer?
    @State private var isLoadingVideo = false

    var body: some View {
        VStack(spacing: 0) {
            Text("Videos")
                .font(.appH3)
                .foregroundStyle(Color.appTextPrimary)
                .padding(.top, 20)
                .padding(.bottom, 16)

            // Video player inline in the sheet
            ZStack {
                // Thumbnail as backdrop while loading
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable().aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Color.appBackgroundSecondary
                }

                // Inline video player
                if let player {
                    VideoPlayer(player: player)
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onAppear { player.play() }
                        .onDisappear { player.pause() }
                }

                // Loading indicator while fetching video
                if isLoadingVideo {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.white)
                }
            }
            .frame(height: 360)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
            .padding(.horizontal, 24)

            // Info
            VStack(spacing: 10) {
                Divider().padding(.horizontal, 24).padding(.top, 10)

                videoInfoRow(icon: "arrow.up.arrow.down", label: "Size",
                        value: asset.fileSizeFormatted, color: Color.appPrimary)
                videoInfoRow(icon: "aspectratio", label: "Resolution",
                        value: asset.resolutionFormatted, color: Color.appTeal)
                videoInfoRow(icon: "clock", label: "Duration",
                        value: asset.durationFormatted, color: Color.appCamel)
                videoInfoRow(icon: "calendar", label: "Date",
                        value: asset.creationDateFormatted, color: Color.appCamel)

                Button {
                    if !appState.isPurchased {
                        // 未付费 → 检查免费额度；不足时直接拉起终身买断购买
                        if appState.freeDeletesRemainingBytes <= 0 || asset.fileSizeBytes > appState.freeDeletesRemainingBytes {
                            Task {
                                let ok = await StoreKitManager.shared.purchaseLifetimeDirect()
                                if ok {
                                    appState.purchasedProductIDs = StoreKitManager.shared.purchasedProductIDs
                                    onDelete?(); dismiss()
                                }
                            }
                        } else if appState.deletePreference == .askEveryTime {
                            showDeleteConfirmation = true
                        } else {
                            onDelete?(); dismiss()
                        }
                    } else {
                        // 已付费 → 直接进入删除偏好选择
                        if appState.deletePreference == .askEveryTime { showDeleteConfirmation = true }
                        else { onDelete?(); dismiss() }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash").font(.system(size: 14, weight: .medium))
                        Text("Delete This Video").font(.appSmallSemibold)
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

            Spacer(minLength: 16)
        }
        .background(Color.appBackground)
        .presentationDetents([.fraction(0.7), .large])
        .presentationDragIndicator(.hidden)
        .sheet(isPresented: $showDeleteConfirmation) {
            DeletePreferencePickerView { onDelete?(); dismiss() }
                .environment(appState)
        }
        .onAppear { loadThumbnail(); loadVideo() }
    }

    private func loadThumbnail() {
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .highQualityFormat
        opts.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(
            for: asset, targetSize: CGSize(width: 1200, height: 1200),
            contentMode: .aspectFit, options: opts
        ) { img, info in
            let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
            if let img, !isDegraded {
                DispatchQueue.main.async { self.thumbnail = img }
            }
        }
    }

    private func loadVideo() {
        guard player == nil else { return }
        isLoadingVideo = true
        let opts = PHVideoRequestOptions()
        opts.isNetworkAccessAllowed = true
        opts.deliveryMode = .automatic
        var didComplete = false
        let requestID = PHImageManager.default().requestAVAsset(forVideo: asset, options: opts) { avAsset, _, _ in
            guard !didComplete else { return }
            didComplete = true
            guard let avAsset else {
                DispatchQueue.main.async { self.isLoadingVideo = false }
                return
            }
            DispatchQueue.main.async {
                self.player = AVPlayer(playerItem: AVPlayerItem(asset: avAsset))
                self.isLoadingVideo = false
            }
        }
        // Timeout after 15s — iCloud downloads can hang indefinitely
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            guard !didComplete else { return }
            didComplete = true
            PHImageManager.default().cancelImageRequest(requestID)
            self.isLoadingVideo = false
        }
    }

    private func videoInfoRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous).fill(color.opacity(0.1)))
            Text(LocalizedStringKey(label))
                .font(.appCaption)
                .foregroundStyle(Color.appTextSecondary)
            Spacer()
            Text(value)
                .font(.appCaptionMedium)
                .foregroundStyle(Color.appTextPrimary)
        }
    }
}
