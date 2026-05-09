import SwiftUI

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
    @State private var orchestrator = ScanOrchestrator()

    // Scan results (stored after scan completes, safe to read from main actor)
    @State private var duplicateGroups: [DuplicateGroup] = []
    @State private var similarGroups: [SimilarGroup] = []
    @State private var blurryPhotos: [PhotoQuality] = []
    @State private var screenshotGroups: [ScreenshotGroupData] = []

    // Navigation
    @State private var showResults = false
    @State private var navigateCategory: ScanCategory?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Layout.cardSpacing) {
                    StorageOverviewView(usedGB: storageInfo.used, totalGB: storageInfo.total,
                                        freedBytes: appState.cumulativeFreedBytes, deletedCount: appState.cumulativeDeletedCount)

                    // 4 scan cards
                    ScanCategoryCard(
                        category: .duplicates, state: dupState,
                        description: "Find identical photos",
                        onScan: { startScan(.duplicates) },
                        onNavigate: { navigate(to: .duplicates) }
                    )

                    ScanCategoryCard(
                        category: .similar, state: simState,
                        description: "Find similar photos in same scene",
                        onScan: { startScan(.similar) },
                        onNavigate: { navigate(to: .similar) }
                    )

                    ScanCategoryCard(
                        category: .blurry, state: blurState,
                        description: "Detect blurry and out-of-focus photos",
                        onScan: { startScan(.blurry) },
                        onNavigate: { navigate(to: .blurry) }
                    )

                    ScanCategoryCard(
                        category: .screenshots, state: ssState,
                        description: "Clean up old screenshots",
                        onScan: { startScan(.screenshots) },
                        onNavigate: { navigate(to: .screenshots) }
                    )
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
        .onAppear { loadStorageInfo() }
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
            DuplicateGroupsView(groups: duplicateGroups)
        case .similar:
            SimilarGroupsView(groups: similarGroups)
        case .blurry:
            BlurryPhotosView(photos: blurryPhotos)
        case .screenshots:
            ScreenshotsView(groups: screenshotGroups)
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

            let state = stateFor(category)
            state.reset()

            switch category {
            case .duplicates:
                duplicateGroups = await orchestrator.scanDuplicates(state: state, includeVideos: appState.includeVideos)
            case .similar:
                similarGroups = await orchestrator.scanSimilar(state: state, includeVideos: appState.includeVideos)
            case .blurry:
                blurryPhotos = await orchestrator.scanBlurry(state: state, includeVideos: appState.includeVideos)
            case .screenshots:
                screenshotGroups = await orchestrator.scanScreenshots(state: state)
            }

            navigateCategory = category
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
        }
    }

    private func loadStorageInfo() {
        if let info = FileManager.default.getFilesystemInfo() {
            storageInfo = (used: info.used, total: info.total)
        }
    }
}

// MARK: - Scan Category Card
private struct ScanCategoryCard: View {
    let category: ScanCategory
    @Bindable var state: CategoryScanState
    let description: String
    let onScan: () -> Void
    var onNavigate: (() -> Void)? = nil

    var body: some View {
        RoundedCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .fill(category.color.opacity(0.12))
                            .frame(width: 48, height: 48)
                        Image(systemName: category.icon)
                            .font(.system(size: 22))
                            .foregroundStyle(category.color)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.rawValue)
                            .font(.appH3)
                            .foregroundStyle(Color.appTextPrimary)
                        Text(description)
                            .font(.appCaption)
                            .foregroundStyle(Color.appTextSecondary)
                    }

                    Spacer()
                }

                if state.isScanning {
                    VStack(spacing: 6) {
                        ProgressBar(value: state.progress, color: category.color)
                        Text("Scanning...")
                            .font(.appTiny)
                            .foregroundStyle(Color.appTextTertiary)
                    }
                } else if state.isDone {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(state.count) found")
                                .font(.appSmallSemibold)
                                .foregroundStyle(Color.appTextPrimary)
                            Text(formatBytes(state.sizeBytes))
                                .font(.appTiny)
                                .foregroundStyle(Color.appTextSecondary)
                        }
                        Spacer()
                        StatusTag(text: state.count > 0 ? "Clean Up" : "All Clean", type: state.count > 0 ? .info : .success)
                    }
                } else {
                    Button(action: onScan) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkle.magnifyingglass")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Scan")
                                .font(.appSmallSemibold)
                        }
                        .foregroundStyle(category.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                                .fill(category.color.opacity(0.08))
                        )
                    }
                    .buttonStyle(.plain)
                    .pressableScale(0.97)
                }
            }
        }
        .onTapGesture {
            if state.isDone && state.count > 0 {
                onNavigate?()
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let f = ByteCountFormatter(); f.allowedUnits = [.useGB, .useMB]; f.countStyle = .file
        return f.string(fromByteCount: bytes)
    }
}
