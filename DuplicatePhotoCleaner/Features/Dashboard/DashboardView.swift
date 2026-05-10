import SwiftUI
import Photos

@Observable
class ScanResultData {
    var duplicateGroups: [DuplicateGroup] = []
    var similarGroups: [SimilarGroup] = []
    var blurryPhotos: [PhotoQuality] = []
    var screenshotGroups: [ScreenshotGroupData] = []
    var videos: [PHAsset] = []
}

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var storageInfo: (used: Double, total: Double) = (0, 0)
    @State private var showingSettings = false
    @State private var permissionManager = PhotoPermissionManager()
    @State private var showPermissionAlert = false

    // Individual scan states
    @State private var dupState = CategoryScanState()
    @State private var simState = CategoryScanState()
    @State private var blurState = CategoryScanState()
    @State private var ssState = CategoryScanState()
    @State private var vidState = CategoryScanState()
    @State private var orchestrator = ScanOrchestrator()

    // Scan results (reference type — detail views see updates immediately)
    @State private var scanData = ScanResultData()

    // Navigation
    @State private var showResults = false
    @State private var navigateCategory: ScanCategory?

    // Auto-scan
    @State private var lastFullScanAt: Date? = {
        let ts = UserDefaults.standard.double(forKey: "lastFullScanAt")
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }()

    private let gridColumns = [
        GridItem(.flexible(), spacing: Layout.cardSpacing),
        GridItem(.flexible(), spacing: Layout.cardSpacing)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Layout.cardSpacing) {
                    StorageOverviewView(usedGB: storageInfo.used, totalGB: storageInfo.total,
                                        freedBytes: appState.cumulativeFreedBytes, deletedCount: appState.cumulativeDeletedCount)

                    LazyVGrid(columns: gridColumns, spacing: Layout.cardSpacing) {
                        ScanCategoryTile(
                            category: .duplicates, state: dupState,
                            onScan: { startScan(.duplicates) },
                            onNavigate: { navigate(to: .duplicates) }
                        )

                        ScanCategoryTile(
                            category: .videos, state: vidState,
                            onScan: { startScan(.videos) },
                            onNavigate: { navigate(to: .videos) }
                        )

                        ScanCategoryTile(
                            category: .similar, state: simState,
                            onScan: { startScan(.similar) },
                            onNavigate: { navigate(to: .similar) }
                        )

                        ScanCategoryTile(
                            category: .blurry, state: blurState,
                            onScan: { startScan(.blurry) },
                            onNavigate: { navigate(to: .blurry) }
                        )

                        ScanCategoryTile(
                            category: .screenshots, state: ssState,
                            onScan: { startScan(.screenshots) },
                            onNavigate: { navigate(to: .screenshots) }
                        )
                        .gridCellColumns(2)
                    }
                }
                .padding(.horizontal, Layout.pageHorizontalPadding)
                .padding(.top, Layout.headerToContent)
                .padding(.bottom, Layout.scrollBottomPadding)
            }
            .background(Color.appBackground)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape.fill").font(.system(size: 18)).foregroundStyle(Color.appTextSecondary)
                    }
                }
            }
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .navigationDestination(item: $navigateCategory) { category in
                categoryDetailView(for: category)
            }
        }
        .onAppear {
            loadStorageInfo()
            autoScanIfNeeded()
        }
        .alert("Photo Access Required", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Please allow access to your photos in Settings to use the cleaner.") }
    }

    @ViewBuilder
    private func categoryDetailView(for category: ScanCategory) -> some View {
        switch category {
        case .duplicates:
            DuplicateGroupsView(groups: scanData.duplicateGroups) {
                scanData.duplicateGroups = $0
                dupState.update(fromDuplicateGroups: $0)
            }
        case .similar:
            SimilarGroupsView(groups: scanData.similarGroups) {
                scanData.similarGroups = $0
                simState.update(fromSimilarGroups: $0)
            }
        case .blurry:
            BlurryPhotosView(photos: scanData.blurryPhotos) {
                scanData.blurryPhotos = $0
                blurState.update(fromBlurryPhotos: $0)
            }
        case .screenshots:
            ScreenshotsView(groups: scanData.screenshotGroups) {
                scanData.screenshotGroups = $0
                ssState.update(fromScreenshotGroups: $0)
            }
        case .videos:
            VideosView(videos: scanData.videos) {
                scanData.videos = $0
                vidState.update(fromVideos: $0)
            }
        }
    }

    // MARK: - Scan Logic

    private func performScan(_ category: ScanCategory) async {
        let state = stateFor(category)
        state.reset()

        switch category {
        case .duplicates:
            scanData.duplicateGroups = await orchestrator.scanDuplicates(state: state, includeVideos: appState.includeVideos)
        case .similar:
            scanData.similarGroups = await orchestrator.scanSimilar(state: state, includeVideos: appState.includeVideos)
        case .blurry:
            scanData.blurryPhotos = await orchestrator.scanBlurry(state: state, includeVideos: appState.includeVideos)
        case .screenshots:
            scanData.screenshotGroups = await orchestrator.scanScreenshots(state: state)
        case .videos:
            scanData.videos = await orchestrator.scanVideos(state: state)
        }
    }

    private func startScan(_ category: ScanCategory) {
        Task {
            let status = await permissionManager.requestPermission()
            switch status {
            case .authorized, .limited:
                break
            case .denied:
                showPermissionAlert = true
                return
            default:
                return
            }

            await performScan(category)
            navigateCategory = category
        }
    }

    private func autoScanIfNeeded() {
        // Skip if any scan is in progress
        guard !dupState.isScanning, !simState.isScanning, !blurState.isScanning, !ssState.isScanning, !vidState.isScanning else { return }

        // Skip only if all scans already completed AND within cooldown
        let allDone = dupState.isDone && simState.isDone && blurState.isDone && ssState.isDone && vidState.isDone
        if allDone, let last = lastFullScanAt, Date().timeIntervalSince(last) < 300 { return }

        Task {
            let status = await permissionManager.requestPermission()
            guard status == .authorized || status == .limited else { return }

            for category in ScanCategory.allCases {
                await performScan(category)
            }

            lastFullScanAt = Date()
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastFullScanAt")
        }
    }

    private func navigate(to category: ScanCategory) {
        if navigateCategory == category {
            navigateCategory = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                navigateCategory = category
            }
        } else {
            navigateCategory = category
        }
    }

    private func stateFor(_ category: ScanCategory) -> CategoryScanState {
        switch category {
        case .duplicates: return dupState
        case .similar: return simState
        case .blurry: return blurState
        case .screenshots: return ssState
        case .videos: return vidState
        }
    }

    private func loadStorageInfo() {
        if let info = FileManager.default.getFilesystemInfo() {
            storageInfo = (used: info.used, total: info.total)
        }
    }
}

// MARK: - Scan Category Tile

private struct ScanCategoryTile: View {
    let category: ScanCategory
    @Bindable var state: CategoryScanState
    let onScan: () -> Void
    var onNavigate: (() -> Void)? = nil

    var body: some View {
        RoundedCard {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(category.color.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: category.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(category.color)
                }

                Text(category.rawValue)
                    .font(.appSmallSemibold)
                    .foregroundStyle(Color.appTextPrimary)

                if state.isScanning {
                    VStack(spacing: 4) {
                        ProgressBar(value: state.progress, color: category.color)
                        Text("Scanning...")
                            .font(.appMicro)
                            .foregroundStyle(Color.appTextTertiary)
                    }
                } else if state.isDone {
                    VStack(spacing: 2) {
                        Text("\(state.count)")
                            .font(.appH3)
                            .foregroundStyle(state.count > 0 ? Color.appTextPrimary : Color.appSuccess)
                        Text(state.count > 0 ? formatBytes(state.sizeBytes) : "All Clean")
                            .font(.appMicro)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                } else {
                    Button(action: onScan) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkle.magnifyingglass")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Scan")
                                .font(.appMicro)
                        }
                        .foregroundStyle(category.color)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(
                            Capsule().fill(category.color.opacity(0.08))
                        )
                    }
                    .buttonStyle(.plain)
                    .pressableScale(0.97)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .onTapGesture {
            if state.isDone && state.count > 0 {
                onNavigate?()
            } else if !state.isScanning && !state.isDone {
                onScan()
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let f = ByteCountFormatter(); f.allowedUnits = [.useGB, .useMB]; f.countStyle = .file
        return f.string(fromByteCount: bytes)
    }
}
