import SwiftUI
import Photos

// MARK: - Shared bar state for floating delete bar communication

@Observable
class DashboardUnfavBarState {
    var selectedCount: Int = 0
    var totalCount: Int = 0
    var allSelected: Bool = false
}

final class UnfavoritesDeleteActionHolder {
    static let shared = UnfavoritesDeleteActionHolder()
    var deleteAction: (() -> Void)?
    var toggleSelectAllAction: (() -> Void)?
}

// MARK: - Time Filter

enum TimeFilterOption: String, CaseIterable, Identifiable {
    case all = "All"
    case days7 = "7 Days"
    case days30 = "30 Days"
    case days90 = "90 Days"
    case halfYear = "6 Months"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return String(localized: "All")
        case .days7: return String(localized: "7 Days")
        case .days30: return String(localized: "30 Days")
        case .days90: return String(localized: "90 Days")
        case .halfYear: return String(localized: "6 Months")
        }
    }

    var days: Int? {
        switch self {
        case .all: return nil
        case .days7: return 7
        case .days30: return 30
        case .days90: return 90
        case .halfYear: return 180
        }
    }
}

// MARK: - Unfavorites View

struct UnfavoritesView: View {
    let assets: [PHAsset]
    let statistics: (total: Int, favorited: Int, unfavorited: Int)
    var onAssetsChanged: (([PHAsset]) -> Void)?
    var scrollable: Bool = true  // false when embedded in DashboardView's outer ScrollView
    var barState: DashboardUnfavBarState? = nil  // shared state for floating bar in DashboardView

    @Environment(AppState.self) private var appState
    private let unfavoritesFetcher = UnfavoritesFetcher()

    @State private var selectedForDeletion: Set<String> = []
    @State private var selectedTimeFilter: TimeFilterOption = .all

    @State private var showDeleteConfirmation = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var previewContext: PhotoPreviewContext?
    @State private var locallyRemovedAssetIDs: Set<String> = []

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    private var filteredAssets: [PHAsset] {
        let visibleAssets = assets.filter { !locallyRemovedAssetIDs.contains($0.localIdentifier) }
        guard let days = selectedTimeFilter.days else { return visibleAssets }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        return visibleAssets.filter { ($0.creationDate ?? Date.distantPast) < cutoff }
    }

    private var selectedAssets: [PHAsset] {
        filteredAssets.filter { selectedForDeletion.contains($0.localIdentifier) }
    }

    private var totalFilteredBytes: Int64 {
        filteredAssets.reduce(Int64(0)) { $0 + $1.fileSizeBytes }
    }

    private var innerContent: some View {
        VStack(spacing: 12) {
            // MARK: Stats Header
            statsHeader

            // MARK: Time Filter
            timeFilterPicker

            // MARK: Photo Grid (Apple Photos style)
            photoGrid

            Spacer(minLength: 80)
        }
        .padding(.horizontal, Layout.pageHorizontalPadding)
        .padding(.top, Layout.headerToContent)
    }

    var body: some View {
        Group {
            if scrollable {
                ScrollView { innerContent }
                    .overlay(alignment: .bottom) { deleteBar }
            } else {
                innerContent
            }
        }
        .background(Color.appBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                let ids = Set(filteredAssets.map(\.localIdentifier))
                let allSelected = !ids.isEmpty && ids.isSubset(of: selectedForDeletion)
                Button(allSelected ? "Deselect All" : "Select All") {
                    HapticManager.selection()
                    if allSelected { selectedForDeletion.subtract(ids) }
                    else { selectedForDeletion.formUnion(ids) }
                }
                .font(.appCaptionMedium)
                .foregroundStyle(Color.appPrimary)
            }
        }
        .sheet(isPresented: $showDeleteConfirmation) {
            DeletePreferencePickerView { deleteSelected() }
                .environment(appState)
        }
        .fullScreenCover(item: $previewContext) { ctx in
            FullScreenPhotoViewer(
                context: ctx,
                onDelete: { deletedAsset in
                    withAnimation {
                        selectedForDeletion.remove(deletedAsset.localIdentifier)
                        onAssetsChanged?(assets.filter { $0.localIdentifier != deletedAsset.localIdentifier })
                    }
                },
                onMarkFavorite: { favoritedAsset in
                    markAsFavorite([favoritedAsset])
                }
            )
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
            // Default: select all
            if selectedForDeletion.isEmpty {
                selectedForDeletion = Set(filteredAssets.map(\.localIdentifier))
            }
            syncBarState()
        }
        .onChange(of: selectedTimeFilter) { _, _ in
            // Re-select all when filter changes
            selectedForDeletion = Set(filteredAssets.map(\.localIdentifier))
            syncBarState()
        }
        // Sync bar state whenever selection changes
        .onChange(of: selectedForDeletion) { _, _ in syncBarState() }
        .onAppear {
            UnfavoritesDeleteActionHolder.shared.deleteAction = { deleteSelected() }
            UnfavoritesDeleteActionHolder.shared.toggleSelectAllAction = {
                HapticManager.selection()
                let allFilteredIDs = Set(filteredAssets.map(\.localIdentifier))
                let allSelected = !allFilteredIDs.isEmpty && allFilteredIDs.isSubset(of: selectedForDeletion)
                if allSelected {
                    selectedForDeletion.subtract(allFilteredIDs)
                } else {
                    selectedForDeletion.formUnion(allFilteredIDs)
                }
            }
        }
    }

    private func syncBarState() {
        guard let barState else { return }
        let ids = Set(filteredAssets.map(\.localIdentifier))
        barState.totalCount = filteredAssets.count
        barState.selectedCount = selectedAssets.count
        barState.allSelected = !ids.isEmpty && ids.isSubset(of: selectedForDeletion)
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        HStack(spacing: 0) {
            statBlock(value: "\(assets.count)", label: String(localized: "Not Favorited"), color: Color.appTextPrimary)
            Divider().frame(height: 30)
            statBlock(value: "\(statistics.favorited)", label: String(localized: "Favorited"), color: Color.appDanger)
            Divider().frame(height: 30)
            statBlock(value: formatBytes(totalFilteredBytes), label: String(localized: "Can Free"), color: Color.appRose)
        }
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .strokeBorder(Color.appDividerLight, lineWidth: 1)
        )
    }

    private func statBlock(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.appH3)
                .foregroundStyle(color)
            Text(label)
                .font(.appMicro)
                .foregroundStyle(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Time Filter

    private var timeFilterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TimeFilterOption.allCases) { option in
                    Button {
                        HapticManager.selection()
                        selectedTimeFilter = option
                    } label: {
                        Text(option.displayName)
                            .font(.appTinySemibold)
                            .foregroundStyle(selectedTimeFilter == option ? .white : Color.appTextSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(selectedTimeFilter == option ? Color.appRose : Color.appBackgroundTertiary.opacity(0.5))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Photo Grid

    private var photoGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 2) {
            ForEach(filteredAssets, id: \.localIdentifier) { asset in
                UnfavoriteGridCell(
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
                    onPreview: {
                        let index = filteredAssets.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }) ?? 0
                        previewContext = PhotoPreviewContext(
                            assets: filteredAssets,
                            initialIndex: index,
                            category: .unfavorites,
                            reason: String(localized: "Not favorited")
                        )
                    }
                )
            }
        }
    }

    // MARK: - Bottom Delete Bar

    private var deleteBar: some View {
        let count = selectedAssets.count
        let bytes = selectedAssets.reduce(Int64(0)) { $0 + $1.fileSizeBytes }
        return CleanupDeleteBar(selectedCount: count, selectedBytes: bytes, itemKind: .unfavoritedPhoto) {
                    if !appState.isPurchased {
                        if appState.freeDeletesRemainingBytes <= 0 || bytes > appState.freeDeletesRemainingBytes {
                            // 直接拉起终身买断购买
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
                        if appState.deletePreference == .askEveryTime {
                            showDeleteConfirmation = true
                        } else {
                            deleteSelected()
                        }
                    }
        }
    }

    // MARK: - Actions

    private func deleteSelected() {
        let deleteAssets = selectedAssets
        let count = deleteAssets.count
        let bytes = deleteAssets.reduce(Int64(0)) { $0 + $1.fileSizeBytes }

        Task {
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.deleteAssets(deleteAssets as NSArray)
                }
                await MainActor.run {
                    if !appState.isPurchased {
                        _ = appState.consumeFreeQuota(bytes: bytes, deletedCount: count)
                    } else {
                        appState.recordCleanup(freedBytes: bytes, deletedCount: count)
                    }
                    HapticManager.notification(.success)
                    locallyRemovedAssetIDs.formUnion(deleteAssets.map(\.localIdentifier))
                    selectedForDeletion.removeAll()
                    withAnimation { onAssetsChanged?(assets.filter { !locallyRemovedAssetIDs.contains($0.localIdentifier) }) }
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

    private func markAsFavorite(_ assetsToFavorite: [PHAsset]) {
        let ids = Set(assetsToFavorite.map(\.localIdentifier))
        Task {
            do {
                try await unfavoritesFetcher.markAsFavorite(assetsToFavorite)
                await MainActor.run {
                    HapticManager.notification(.success)
                    selectedForDeletion.subtract(ids)
                    locallyRemovedAssetIDs.formUnion(ids)
                    withAnimation { onAssetsChanged?(assets.filter { !locallyRemovedAssetIDs.contains($0.localIdentifier) }) }
                    toastMessage = String(localized: "\(assetsToFavorite.count) photo favorited")
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showToast = true }
                }
            } catch {
                await MainActor.run {
                    HapticManager.notification(.error)
                    toastMessage = String(localized: "Failed to favorite")
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showToast = true }
                }
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useGB, .useMB]
        f.countStyle = .file
        return f.string(fromByteCount: bytes)
    }
}

// MARK: - Grid Cell (Apple Photos style)

private struct UnfavoriteGridCell: View {
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
            .overlay(alignment: .topTrailing) {
                selectionCircle
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

    private var selectionCircle: some View {
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
        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
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
