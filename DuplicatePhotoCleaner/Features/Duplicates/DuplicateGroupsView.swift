import SwiftUI
import Photos

struct DuplicateGroupsView: View {
    let groups: [DuplicateGroup]
    var onGroupsChanged: (([DuplicateGroup]) -> Void)?
    @Environment(AppState.self) private var appState
    @State private var selectedForDeletion: Set<String> = []
    @State private var showDeleteConfirmation = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var previewContext: PhotoPreviewContext?

    private var selectedAssets: [PHAsset] {
        groups.flatMap { $0.assets }.filter { selectedForDeletion.contains($0.localIdentifier) }
    }

    private var allOtherIDs: [String] {
        groups.flatMap { group in
            group.assets.filter { $0.localIdentifier != group.recommended.localIdentifier }.map(\.localIdentifier)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(Array(groups.enumerated()), id: \.element.assets.first?.localIdentifier) { index, group in
                    DupGroupCard(
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
                            let filtered: [PHAsset]
                            let reason: String
                            let best = group.recommended
                            let others = group.assets.filter { $0.localIdentifier != best.localIdentifier }
                            switch category {
                            case .best:
                                filtered = [best]
                                let bestPixels = best.pixelWidth * best.pixelHeight
                                let bestSize = best.fileSizeBytes
                                let maxOtherPixels = others.map { $0.pixelWidth * $0.pixelHeight }.max() ?? 0
                                let maxOtherSize = others.map { $0.fileSizeBytes }.max() ?? 0
                                if bestPixels > maxOtherPixels {
                                    reason = "Highest resolution"
                                } else if bestSize > maxOtherSize {
                                    reason = "Largest file size (better quality)"
                                } else {
                                    reason = "Original copy (oldest)"
                                }
                            case .others:
                                filtered = others
                                let otherPixels = asset.pixelWidth * asset.pixelHeight
                                let otherSize = asset.fileSizeBytes
                                let bestPixels = best.pixelWidth * best.pixelHeight
                                let bestSize = best.fileSizeBytes
                                if otherPixels < bestPixels {
                                    reason = "Lower resolution"
                                } else if otherSize < bestSize {
                                    reason = "Smaller file (more compressed)"
                                } else {
                                    reason = "Same quality, newer copy"
                                }
                            }
                            previewContext = PhotoPreviewContext(assets: filtered, initialIndex: 0, category: category, reason: reason)
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
                    if allSelected {
                        selectedForDeletion.removeAll()
                    } else {
                        selectedForDeletion = Set(allOtherIDs)
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
                            Text("\(count) duplicate\(count > 1 ? "s" : "") selected")
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
        .sheet(item: $previewContext) { ctx in
            FloatingPhotoPreview(assets: ctx.assets, initialIndex: ctx.initialIndex, category: ctx.category, reason: ctx.reason) { deleted in
                onGroupsChanged?(groups.compactMap { g -> DuplicateGroup? in
                    let remaining = g.assets.filter { $0.localIdentifier != deleted.localIdentifier }
                    guard remaining.count > 1 else { return nil }
                    return DuplicateGroup(assets: remaining, recommended: remaining.contains(where: { $0.localIdentifier == g.recommended.localIdentifier }) ? g.recommended : remaining[0])
                })
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
        .onAppear {
            let othersIDs = groups.flatMap { group in
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
            try? await PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.deleteAssets(assets as NSArray) }
            await MainActor.run {
                HapticManager.notification(.success)
                appState.recordCleanup(freedBytes: bytes, deletedCount: count)
                let deletedIDs = selectedForDeletion
                let updated = groups.compactMap { g -> DuplicateGroup? in
                    let remaining = g.assets.filter { !deletedIDs.contains($0.localIdentifier) }
                    guard remaining.count > 1 else { return nil }
                    return DuplicateGroup(assets: remaining, recommended: g.recommended)
                }
                selectedForDeletion.removeAll()
                onGroupsChanged?(updated)
                toastMessage = "\(count) duplicate\(count > 1 ? "s" : "") deleted"
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showToast = true }
            }
        }
    }

    private func formatBytes(_ b: Int64) -> String {
        let f = ByteCountFormatter(); f.allowedUnits = [.useGB, .useMB]; f.countStyle = .file
        return f.string(fromByteCount: b)
    }
}

// MARK: - Group Card

private struct DupGroupCard: View {
    let group: DuplicateGroup; let index: Int
    let selectedForDeletion: Set<String>
    let onToggle: (PHAsset) -> Void
    let onTapPhoto: (PHAsset, PhotoPreviewCategory) -> Void

    private var bestAsset: PHAsset { group.recommended }
    private var otherAssets: [PHAsset] { group.assets.filter { $0.localIdentifier != bestAsset.localIdentifier } }

    var body: some View {
        RoundedCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Group \(index + 1)").font(.appSmallSemibold).foregroundStyle(Color.appTextSecondary)
                        .textCase(.uppercase).tracking(0.6)
                    Spacer()
                    let selectedCount = otherAssets.filter { selectedForDeletion.contains($0.localIdentifier) }.count
                    Text("\(selectedCount)/\(otherAssets.count) selected")
                        .font(.appTiny).foregroundStyle(Color.appTextTertiary)
                }

                HStack(alignment: .top, spacing: 14) {
                    // Best
                    VStack(spacing: 6) {
                        DupThumb(asset: bestAsset, height: 120)
                            .onTapGesture { onTapPhoto(bestAsset, .best) }
                        StatusTag(text: "Best", type: .success)
                    }
                    .frame(maxWidth: .infinity)

                    // Others
                    VStack(spacing: 6) {
                        ZStack {
                            ForEach(Array(otherAssets.prefix(4).enumerated()), id: \.element.localIdentifier) { i, asset in
                                let isSelected = selectedForDeletion.contains(asset.localIdentifier)
                                DupSelectableThumb(
                                    asset: asset, height: 120, isSelected: isSelected,
                                    onToggle: { onToggle(asset) },
                                    onPreview: { onTapPhoto(asset, .others) }
                                )
                                .offset(y: CGFloat(i) * 4)
                                .rotationEffect(.degrees(Double(i) * 1.5 - 1.5), anchor: .top)
                            }
                        }
                        .frame(height: 128)

                        Text("Others").font(.appTinySemibold).foregroundStyle(Color.appTextTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - Thumbnails

private struct DupThumb: View {
    let asset: PHAsset; let height: CGFloat
    @State private var image: UIImage?
    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                    .frame(height: height).clipped()
            } else {
                Rectangle().fill(Color.appBackgroundTertiary)
                    .frame(height: height)
                    .overlay(ProgressView().scaleEffect(0.5))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .onAppear { loadThumb() }
        .onDisappear { image = nil }
    }
    private func loadThumb() {
        let opts = PHImageRequestOptions(); opts.deliveryMode = .opportunistic; opts.isNetworkAccessAllowed = false
        PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 200, height: 200),
            contentMode: .aspectFill, options: opts) { img, _ in if let img { self.image = img } }
    }
}

private struct DupSelectableThumb: View {
    let asset: PHAsset; let height: CGFloat; let isSelected: Bool
    let onToggle: () -> Void; let onPreview: () -> Void
    @State private var image: UIImage?
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Image area - tap to preview
            Group {
                if let image {
                    Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                        .frame(height: height).clipped()
                } else {
                    Rectangle().fill(Color.appBackgroundTertiary)
                        .frame(height: height)
                        .overlay(ProgressView().scaleEffect(0.5))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onPreview() }

            // Checkbox - tap to toggle selection
            ZStack {
                Circle()
                    .fill(isSelected ? Color.appDanger : Color.black.opacity(0.35))
                    .frame(width: 26, height: 26)
                Image(systemName: isSelected ? "checkmark" : "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(7)
            .contentShape(Rectangle())
            .onTapGesture { onToggle() }
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .onAppear { loadThumb() }
        .onDisappear { image = nil }
    }
    private func loadThumb() {
        let opts = PHImageRequestOptions(); opts.deliveryMode = .opportunistic; opts.isNetworkAccessAllowed = false
        PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 200, height: 200),
            contentMode: .aspectFill, options: opts) { img, _ in if let img { self.image = img } }
    }
}
