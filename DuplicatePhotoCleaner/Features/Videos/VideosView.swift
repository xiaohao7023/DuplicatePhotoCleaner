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

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(videos, id: \.localIdentifier) { asset in
                    VideoRow(
                        asset: asset,
                        isSelected: selectedForDeletion.contains(asset.localIdentifier),
                        onTap: {
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
                let allSelected = !videos.isEmpty && videos.allSatisfy { selectedForDeletion.contains($0.localIdentifier) }
                Button {
                    HapticManager.selection()
                    if allSelected {
                        selectedForDeletion.removeAll()
                    } else {
                        selectedForDeletion = Set(videos.map(\.localIdentifier))
                    }
                } label: {
                    Text(allSelected ? "Deselect All" : "Select All")
                        .font(.appCaptionMedium)
                        .foregroundStyle(Color.appPrimary)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if !selectedForDeletion.isEmpty {
                let count = selectedForDeletion.count
                let bytes = selectedAssets.reduce(Int64(0)) { $0 + $1.fileSizeBytes }
                VStack(spacing: 0) {
                    Divider()
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Free up \(formatBytes(bytes))")
                                .font(.appH3).foregroundStyle(Color.appTextPrimary)
                            Text("\(count) video\(count > 1 ? "s" : "") selected")
                                .font(.appCaption).foregroundStyle(Color.appTextSecondary)
                        }
                        Spacer()
                        Button {
                            if appState.deletePreference == .askEveryTime { showDeleteConfirmation = true }
                            else { deleteSelected() }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "trash.fill").font(.system(size: 15, weight: .semibold))
                                Text("Delete \(count)").font(.appBody)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24).padding(.vertical, 14)
                            .background(Capsule().fill(Color.appDanger))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 18)
                    .background(Color.appBackground)
                }
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
            try? await PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.deleteAssets(assets as NSArray) }
            await MainActor.run {
                HapticManager.notification(.success)
                appState.recordCleanup(freedBytes: bytes, deletedCount: count)
                let deletedIDs = selectedForDeletion
                let updated = videos.filter { !deletedIDs.contains($0.localIdentifier) }
                selectedForDeletion.removeAll()
                onVideosChanged?(updated)
                toastMessage = "\(count) video\(count > 1 ? "s" : "") deleted"
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showToast = true }
            }
        }
    }

    private func deleteAsset(_ asset: PHAsset) {
        let bytes = asset.fileSizeBytes
        Task {
            try? await PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.deleteAssets([asset] as NSArray) }
            await MainActor.run {
                HapticManager.notification(.success)
                appState.recordCleanup(freedBytes: bytes, deletedCount: 1)
                let updated = videos.filter { $0.localIdentifier != asset.localIdentifier }
                onVideosChanged?(updated)
                toastMessage = "Video deleted"
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showToast = true }
            }
        }
    }

    private func formatBytes(_ b: Int64) -> String {
        let f = ByteCountFormatter(); f.allowedUnits = [.useGB, .useMB]; f.countStyle = .file
        return f.string(fromByteCount: b)
    }
}

// MARK: - Video Row

private struct VideoRow: View {
    let asset: PHAsset
    let isSelected: Bool
    let onTap: () -> Void
    let onPreview: () -> Void
    @State private var thumbnail: UIImage?

    var body: some View {
        RoundedCard {
            HStack(spacing: 14) {
                // Thumbnail
                ZStack {
                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable().aspectRatio(contentMode: .fill)
                            .frame(width: 72, height: 72).clipped()
                    } else {
                        Rectangle().fill(Color.appBackgroundTertiary)
                            .frame(width: 72, height: 72)
                            .overlay(ProgressView().scaleEffect(0.5))
                    }
                    // Play icon
                    Image(systemName: "play.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 3)
                    // Duration badge
                    if !asset.durationFormatted.isEmpty {
                        Text(asset.durationFormatted)
                            .font(.appMicro).foregroundStyle(.white)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Capsule().fill(Color.black.opacity(0.6)))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(4)
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .onTapGesture { onPreview() }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(asset.fileSizeFormatted)
                        .font(.appSmallSemibold).foregroundStyle(Color.appTextPrimary)
                    Text(asset.resolutionFormatted)
                        .font(.appCaption).foregroundStyle(Color.appTextSecondary)
                    Text(asset.creationDateFormatted)
                        .font(.appCaption).foregroundStyle(Color.appTextTertiary)
                }

                Spacer()

                // Selection badge
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.appDanger : Color.appBackgroundTertiary)
                        .frame(width: 26, height: 26)
                    Image(systemName: isSelected ? "checkmark" : "")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
                .contentShape(Rectangle())
                .onTapGesture { onTap() }
            }
        }
        .onAppear { loadThumbnail() }
        .onDisappear { thumbnail = nil }
    }

    private func loadThumbnail() {
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .opportunistic
        opts.isNetworkAccessAllowed = false
        PHImageManager.default().requestImage(
            for: asset, targetSize: CGSize(width: 200, height: 200),
            contentMode: .aspectFill, options: opts
        ) { img, _ in if let img { self.thumbnail = img } }
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
    @State private var showPlayer = false

    var body: some View {
        VStack(spacing: 0) {
            Text("Video")
                .font(.appH3)
                .foregroundStyle(Color.appTextPrimary)
                .padding(.top, 20)
                .padding(.bottom, 16)

            // Thumbnail with play button
            ZStack {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable().aspectRatio(contentMode: .fill)
                        .frame(height: 360).clipped()
                } else {
                    Color.appBackgroundSecondary
                        .frame(height: 360)
                        .overlay(ProgressView())
                }
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 8)
            }
            .frame(height: 360)
            .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
            .padding(.horizontal, 24)
            .onTapGesture { playVideo() }
            .fullScreenCover(isPresented: $showPlayer) {
                if let player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                        .onAppear { player.play() }
                        .onDisappear { player.pause() }
                }
            }

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
                    if appState.deletePreference == .askEveryTime { showDeleteConfirmation = true }
                    else { onDelete?(); dismiss() }
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
        .onAppear { loadThumbnail() }
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

    private func playVideo() {
        let opts = PHVideoRequestOptions()
        opts.isNetworkAccessAllowed = true
        opts.deliveryMode = .automatic
        PHImageManager.default().requestAVAsset(forVideo: asset, options: opts) { avAsset, _, _ in
            guard let avAsset else { return }
            DispatchQueue.main.async {
                self.player = AVPlayer(playerItem: AVPlayerItem(asset: avAsset))
                self.showPlayer = true
            }
        }
    }

    private func videoInfoRow(icon: String, label: String, value: String, color: Color) -> some View {
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
