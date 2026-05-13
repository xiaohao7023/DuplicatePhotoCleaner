import SwiftUI
import Photos

struct ScreenshotsView: View {
    let groups: [ScreenshotGroupData]
    var onGroupsChanged: (([ScreenshotGroupData]) -> Void)?
    @Environment(AppState.self) private var appState
    @State private var selectedForDeletion: Set<String> = []
    @State private var showDeleteConfirmation = false
    @State private var showingPaywall = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var previewContext: PhotoPreviewContext?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Layout.cardSpacing) {
                ForEach(groups, id: \.group) { groupData in
                    ScreenshotSection(groupData: groupData, selectedForDeletion: selectedForDeletion,
                                      onTogglePhoto: { id in
                        HapticManager.selection()
                        if selectedForDeletion.contains(id) { selectedForDeletion.remove(id) }
                        else { selectedForDeletion.insert(id) }
                    }, onPreviewPhoto: { asset in
                        let allAssets = groups.flatMap { $0.assets }
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
                let allIDs = groups.flatMap { $0.assets.map(\.localIdentifier) }
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
            PrimaryButton(title: count > 0 ? "Delete \(count) Screenshot\(count > 1 ? "s" : "")" : "Delete",
                          icon: "trash", isDanger: true, isDisabled: count == 0) {
                if !appState.isPurchased { showingPaywall = true }
                else if appState.deletePreference == .askEveryTime { showDeleteConfirmation = true }
                else { deletePhotos() }
            }
            .padding(.horizontal, Layout.pageHorizontalPadding).padding(.bottom, 32)
            .background(Rectangle().fill(Color.appBackground).shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: -4))
        }
        .sheet(isPresented: $showDeleteConfirmation) {
            DeletePreferencePickerView { deletePhotos() }
                .environment(appState)
        }
        .sheet(isPresented: $showingPaywall) {
            let selectedAssets = groups.flatMap(\.assets).filter { selectedForDeletion.contains($0.localIdentifier) }
            let bytes = selectedAssets.reduce(Int64(0)) { $0 + $1.fileSizeBytes }
            PaywallDeleteSheet(selectedSizeBytes: bytes, selectedCount: selectedAssets.count, contentType: "screenshots") {
                showingPaywall = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { deletePhotos() }
            }
            .environment(appState)
        }
        .sheet(item: $previewContext) { ctx in
            FloatingPhotoPreview(assets: ctx.assets, initialIndex: ctx.initialIndex, category: ctx.category, reason: ctx.reason) { deleted in
                withAnimation {
                    let updated = groups.compactMap { g -> ScreenshotGroupData? in
                        let remaining = g.assets.filter { $0.localIdentifier != deleted.localIdentifier }
                        guard !remaining.isEmpty else { return nil }
                        return ScreenshotGroupData(group: g.group, assets: remaining, totalSize: remaining.reduce(0) { $0 + $1.fileSizeBytes })
                    }
                    onGroupsChanged?(updated)
                }
            }
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
        let assets = groups.flatMap(\.assets).filter { selectedForDeletion.contains($0.localIdentifier) }
        let count = assets.count
        let bytes = assets.reduce(Int64(0)) { $0 + $1.fileSizeBytes }
        Task {
            try? await PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.deleteAssets(assets as NSArray) }
            await MainActor.run {
                HapticManager.notification(.success)
                appState.recordCleanup(freedBytes: bytes, deletedCount: count)
                let updated = groups.compactMap { g -> ScreenshotGroupData? in
                    let remaining = g.assets.filter { !selectedForDeletion.contains($0.localIdentifier) }
                    guard !remaining.isEmpty else { return nil }
                    return ScreenshotGroupData(group: g.group, assets: remaining, totalSize: remaining.reduce(0) { $0 + $1.fileSizeBytes })
                }
                selectedForDeletion.removeAll()
                withAnimation { onGroupsChanged?(updated) }
                toastMessage = "\(count) screenshot\(count > 1 ? "s" : "") deleted"
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showToast = true }
            }
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
                    Text(groupData.group.rawValue)
                        .font(.appSmallSemibold).foregroundStyle(Color.appTextSecondary)
                        .textCase(.uppercase).tracking(0.6)
                    Spacer()
                    Text("\(groupData.assets.count) screenshots  •  \(formatBytes(groupData.totalSize))")
                        .font(.appCaption).foregroundStyle(Color.appPurple)
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)], spacing: 4) {
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
        ZStack(alignment: .topTrailing) {
            if let thumbnail {
                Image(uiImage: thumbnail).resizable().aspectRatio(contentMode: .fill).frame(height: 80).clipped()
                    .onTapGesture { onPreview() }
            } else {
                Rectangle().fill(Color.appBackgroundTertiary).frame(height: 80).onAppear { loadThumbnail() }
            }
            ZStack {
                Circle()
                    .fill(isSelected ? Color.appDanger : Color.white)
                    .frame(width: 24, height: 24)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(6)
            .contentShape(Rectangle())
            .onTapGesture(perform: onToggle)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
    private func loadThumbnail() {
        let opts = PHImageRequestOptions(); opts.deliveryMode = .opportunistic; opts.isNetworkAccessAllowed = false
        PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 160, height: 160),
            contentMode: .aspectFill, options: opts) { img, _ in
            if let img { DispatchQueue.main.async { self.thumbnail = img } }
        }
    }
}
