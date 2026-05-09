import SwiftUI
import Photos

struct BlurryPhotosView: View {
    @State var photos: [PhotoQuality]
    @Environment(AppState.self) private var appState
    @State private var selectedForDeletion: Set<String> = []
    @State private var showDeleteConfirmation = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var blurThreshold: BlurDetector.BlurLevel = .blurry

    private var filteredPhotos: [PhotoQuality] { photos.filter { $0.blurScore < blurThreshold.threshold } }

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
                                    Text(level.rawValue).font(.appTinySemibold)
                                        .foregroundStyle(blurThreshold == level ? .white : Color.appTextPrimary)
                                        .padding(.horizontal, 12).padding(.vertical, 8)
                                        .background(Capsule().fill(blurThreshold == level ? Color.appPrimary : Color.appBackgroundTertiary))
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }
                Text("\(filteredPhotos.count) BLURRY PHOTOS").sectionHeaderStyle()
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)], spacing: 4) {
                    ForEach(filteredPhotos, id: \.asset.localIdentifier) { photo in
                        BlurryCell(photo: photo, isSelected: selectedForDeletion.contains(photo.asset.localIdentifier)) {
                            HapticManager.selection()
                            if selectedForDeletion.contains(photo.asset.localIdentifier) { selectedForDeletion.remove(photo.asset.localIdentifier) }
                            else { selectedForDeletion.insert(photo.asset.localIdentifier) }
                        }
                    }
                }
                .padding(.horizontal, Layout.pageHorizontalPadding)
            }
            .padding(.bottom, 100)
        }
        .background(Color.appBackground)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Select All") { selectedForDeletion = Set(filteredPhotos.map { $0.asset.localIdentifier }) }
                    .font(.appCaptionMedium).foregroundStyle(Color.appPrimary)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .overlay(alignment: .bottom) {
            if !selectedForDeletion.isEmpty {
                let count = selectedForDeletion.count
                PrimaryButton(title: "Delete \(count) Photo\(count > 1 ? "s" : "")", icon: "trash", isDanger: true) {
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
            try? await PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.deleteAssets(assets as NSArray) }
            await MainActor.run {
                HapticManager.notification(.success)
                appState.recordCleanup(freedBytes: bytes, deletedCount: count)
                photos.removeAll { selectedForDeletion.contains($0.asset.localIdentifier) }
                selectedForDeletion.removeAll()
                toastMessage = "\(count) photo\(count > 1 ? "s" : "") deleted"
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showToast = true }
            }
        }
    }
}

private struct BlurryCell: View {
    let photo: PhotoQuality; let isSelected: Bool; let onTap: () -> Void
    @State private var thumbnail: UIImage?
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let thumbnail {
                Image(uiImage: thumbnail).resizable().aspectRatio(1, contentMode: .fill).clipped()
            } else {
                Rectangle().fill(Color.appBackgroundTertiary).aspectRatio(1, contentMode: .fill)
                    .onAppear { loadThumbnail() }
            }
            Text(String(format: "%.0f", photo.blurScore))
                .font(.appMicro).foregroundStyle(.white).padding(.horizontal, 6).padding(.vertical, 3)
                .background(Capsule().fill(photo.blurLevel == .veryBlurry ? Color.appDanger : Color.appWarning))
                .padding(6)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.appDanger, lineWidth: 3)
                Image(systemName: "checkmark.circle.fill").font(.system(size: 20)).foregroundStyle(.white, Color.appDanger)
            }
        }
        .onTapGesture(perform: onTap)
    }
    private func loadThumbnail() {
        let opts = PHImageRequestOptions(); opts.deliveryMode = .opportunistic; opts.isNetworkAccessAllowed = false
        PHImageManager.default().requestImage(for: photo.asset, targetSize: CGSize(width: 200, height: 200),
            contentMode: .aspectFill, options: opts) { img, _ in if let img { self.thumbnail = img } }
    }
}
