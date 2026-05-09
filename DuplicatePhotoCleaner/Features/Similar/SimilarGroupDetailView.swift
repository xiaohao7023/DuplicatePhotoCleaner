import SwiftUI
import Photos

struct SimilarGroupDetailView: View {
    let group: SimilarGroup; let groupIndex: Int; let totalGroups: Int
    let onDelete: (Set<String>) -> Void
    @Environment(AppState.self) private var appState
    @State private var selectedForDeletion: Set<String> = []
    @State private var showDeleteConfirmation = false

    private var bestAsset: PHAsset { group.recommended }
    private var otherAssets: [PHAsset] { group.assets.filter { $0.localIdentifier != bestAsset.localIdentifier } }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Group header
                HStack {
                    Text("Group \(groupIndex + 1)/\(totalGroups)")
                        .font(.appSmallSemibold).foregroundStyle(Color.appTextSecondary)
                        .textCase(.uppercase).tracking(0.6)
                    Spacer()
                    Text(String(format: "%.0f%% similar", group.averageSimilarity * 100))
                        .font(.appCaptionMedium).foregroundStyle(Color.appTeal)
                }
                .padding(.horizontal, Layout.pageHorizontalPadding)
                .padding(.top, Layout.headerToContent)

                // Best + Stack layout
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 8) {
                        SimBestPhotoCard(asset: bestAsset)
                        StatusTag(text: "Recommended", type: .success)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 8) {
                        ZStack {
                            ForEach(Array(otherAssets.prefix(5).enumerated()), id: \.element.localIdentifier) { index, asset in
                                let isSelected = selectedForDeletion.contains(asset.localIdentifier)
                                SimStackCard(asset: asset, isSelected: isSelected, index: index, total: min(otherAssets.count, 5))
                                    .onTapGesture {
                                        HapticManager.selection()
                                        if isSelected { selectedForDeletion.remove(asset.localIdentifier) }
                                        else { selectedForDeletion.insert(asset.localIdentifier) }
                                    }
                            }
                        }
                        .frame(height: 180)

                        if otherAssets.count > 5 {
                            Text("+\(otherAssets.count - 5) more")
                                .font(.appTiny).foregroundStyle(Color.appTextTertiary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, Layout.pageHorizontalPadding)

                // Summary
                RoundedCard {
                    VStack(spacing: 10) {
                        summaryRow(icon: "checkmark.circle.fill", color: .appDanger,
                                   label: "\(selectedForDeletion.count) selected for deletion")
                        summaryRow(icon: "sparkles", color: .appSuccess,
                                   label: "Best photo will be kept")
                        if !selectedForDeletion.isEmpty {
                            let bytes = otherAssets.filter { selectedForDeletion.contains($0.localIdentifier) }
                                .reduce(Int64(0)) { $0 + $1.fileSizeBytes }
                            summaryRow(icon: "arrow.down.circle", color: .appPrimary,
                                       label: "Free up \(formatBytes(bytes))")
                        }
                    }
                }
                .padding(.horizontal, Layout.pageHorizontalPadding)

                Spacer(minLength: 100)
            }
        }
        .background(Color.appBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !selectedForDeletion.isEmpty {
                    Button {
                        if appState.deletePreference == .askEveryTime { showDeleteConfirmation = true }
                        else { deletePhotos() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("Delete \(selectedForDeletion.count)")
                        }
                        .font(.appSmallSemibold)
                        .foregroundStyle(Color.appDanger)
                    }
                }
            }
        }
        .sheet(isPresented: $showDeleteConfirmation) {
            DeletePreferencePickerView { deletePhotos() }
                .environment(appState)
        }
        .onAppear {
            selectedForDeletion = Set(otherAssets.map(\.localIdentifier))
        }
    }

    private func summaryRow(icon: String, color: Color, label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 14)).foregroundStyle(color).frame(width: 20)
            Text(label).font(.appCaption).foregroundStyle(Color.appTextSecondary)
            Spacer()
        }
    }

    private func deletePhotos() {
        let assets = otherAssets.filter { selectedForDeletion.contains($0.localIdentifier) }
        let bytes = assets.reduce(Int64(0)) { $0 + $1.fileSizeBytes }
        Task {
            try? await PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.deleteAssets(assets as NSArray) }
            await MainActor.run {
                HapticManager.notification(.success)
                appState.recordCleanup(freedBytes: bytes, deletedCount: assets.count)
                onDelete(selectedForDeletion)
                selectedForDeletion.removeAll()
            }
        }
    }

    private func formatBytes(_ b: Int64) -> String {
        let f = ByteCountFormatter(); f.allowedUnits = [.useGB, .useMB]; f.countStyle = .file
        return f.string(fromByteCount: b)
    }
}

// MARK: - Best Photo Card

private struct SimBestPhotoCard: View {
    let asset: PHAsset; @State private var image: UIImage?
    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                    .frame(height: 200).clipped()
            } else {
                Rectangle().fill(Color.appBackgroundSecondary)
                    .frame(height: 200).overlay(ProgressView())
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 2) {
                Text(asset.fileSizeFormatted).font(.appTinySemibold).foregroundStyle(.white)
                Text(asset.resolutionFormatted).font(.appMicro).foregroundStyle(.white.opacity(0.8))
            }
            .padding(8)
            .background(
                LinearGradient(colors: [.black.opacity(0.5), .clear], startPoint: .bottom, endPoint: .top)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
            )
        }
        .onAppear {
            let opts = PHImageRequestOptions(); opts.deliveryMode = .opportunistic; opts.isNetworkAccessAllowed = false
            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 400, height: 400),
                contentMode: .aspectFill, options: opts) { img, _ in if let img { self.image = img } }
        }
    }
}

// MARK: - Stacked Photo Card

private struct SimStackCard: View {
    let asset: PHAsset; let isSelected: Bool; let index: Int; let total: Int
    @State private var image: UIImage?

    private var offset: CGFloat { CGFloat(index) * 8 }
    private var rotation: Double { Double(index) * 2.5 - 2.5 }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                    .frame(width: 130, height: 170).clipped()
            } else {
                Rectangle().fill(Color.appBackgroundTertiary)
                    .frame(width: 130, height: 170)
                    .onAppear { loadThumb() }
            }

            if isSelected {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(Color.appDanger.opacity(0.25))
                    .frame(width: 130, height: 170)
            }

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundStyle(isSelected ? Color.appDanger : .white.opacity(0.7))
                .shadow(color: .black.opacity(0.3), radius: 2)
                .padding(6)
        }
        .frame(width: 130, height: 170)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
        .offset(y: offset)
        .rotationEffect(.degrees(rotation), anchor: .top)
    }

    private func loadThumb() {
        let opts = PHImageRequestOptions(); opts.deliveryMode = .opportunistic; opts.isNetworkAccessAllowed = false
        PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 260, height: 340),
            contentMode: .aspectFill, options: opts) { img, _ in if let img { self.image = img } }
    }
}
