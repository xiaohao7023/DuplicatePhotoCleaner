import SwiftUI
import Photos

struct ScreenshotsView: View {
    @State var groups: [ScreenshotGroupData]
    @Environment(AppState.self) private var appState
    @State private var selectedForDeletion: Set<String> = []
    @State private var showDeleteConfirmation = false
    @State private var showToast = false
    @State private var toastMessage = ""

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Layout.cardSpacing) {
                ForEach(groups, id: \.group) { groupData in
                    ScreenshotSection(groupData: groupData, selectedForDeletion: selectedForDeletion) { id in
                        HapticManager.selection()
                        if selectedForDeletion.contains(id) { selectedForDeletion.remove(id) }
                        else { selectedForDeletion.insert(id) }
                    }
                }
            }
            .padding(.horizontal, Layout.pageHorizontalPadding)
            .padding(.top, Layout.headerToContent).padding(.bottom, 100)
        }
        .background(Color.appBackground)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Select All") { selectedForDeletion = Set(groups.flatMap { $0.assets.map(\.localIdentifier) }) }
                    .font(.appCaptionMedium).foregroundStyle(Color.appPrimary)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .overlay(alignment: .bottom) {
            if !selectedForDeletion.isEmpty {
                let count = selectedForDeletion.count
                PrimaryButton(title: "Delete \(count) Screenshot\(count > 1 ? "s" : "")", icon: "trash", isDanger: true) {
                    if appState.deletePreference == .askEveryTime { showDeleteConfirmation = true }
                    else { deletePhotos() }
                }
                .padding(.horizontal, Layout.pageHorizontalPadding).padding(.bottom, 32)
                .background(Rectangle().fill(Color.appBackground).shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: -4))
            }
        }
        .sheet(isPresented: $showDeleteConfirmation) {
            DeletePreferencePickerView { deletePhotos() }
                .environment(appState)
        }
        .overlay(alignment: .top) {
            if showToast {
                SuccessToast(message: toastMessage)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { showToast = false }
                        }
                    }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showToast)
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
                groups = groups.compactMap { g in
                    let remaining = g.assets.filter { !selectedForDeletion.contains($0.localIdentifier) }
                    guard !remaining.isEmpty else { return nil }
                    return ScreenshotGroupData(group: g.group, assets: remaining, totalSize: remaining.reduce(0) { $0 + $1.fileSizeBytes })
                }
                selectedForDeletion.removeAll()
                toastMessage = "\(count) screenshot\(count > 1 ? "s" : "") deleted"
                showToast = true
            }
        }
    }
}

private struct ScreenshotSection: View {
    let groupData: ScreenshotGroupData
    let selectedForDeletion: Set<String>
    let onTogglePhoto: (String) -> Void

    var body: some View {
        RoundedCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "clock").font(.system(size: 18)).foregroundStyle(Color.appPurple).frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(groupData.group.rawValue).font(.appBody).foregroundStyle(Color.appTextPrimary)
                        Text("\(groupData.assets.count) screenshots  •  \(formatBytes(groupData.totalSize))")
                            .font(.appCaption).foregroundStyle(Color.appTextSecondary)
                    }
                    Spacer()
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)], spacing: 4) {
                    ForEach(groupData.assets, id: \.localIdentifier) { asset in
                        SSThumb(asset: asset, isSelected: selectedForDeletion.contains(asset.localIdentifier))
                        { onTogglePhoto(asset.localIdentifier) }
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
    let asset: PHAsset; let isSelected: Bool; let onTap: () -> Void
    @State private var thumbnail: UIImage?
    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let thumbnail {
                Image(uiImage: thumbnail).resizable().aspectRatio(contentMode: .fill).frame(height: 80).clipped()
            } else {
                Rectangle().fill(Color.appBackgroundTertiary).frame(height: 80).onAppear { loadThumbnail() }
            }
            if isSelected {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.appDanger.opacity(0.3))
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 18)).foregroundStyle(.white, Color.appDanger)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onTapGesture(perform: onTap)
    }
    private func loadThumbnail() {
        let opts = PHImageRequestOptions(); opts.deliveryMode = .opportunistic; opts.isNetworkAccessAllowed = false
        PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 160, height: 160),
            contentMode: .aspectFill, options: opts) { img, _ in if let img { self.thumbnail = img } }
    }
}
