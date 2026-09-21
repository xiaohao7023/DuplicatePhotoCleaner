# Duplicate Photo Cleaner — V1.5 Project Documentation

## Product Overview

**App Name:** Duplicate Photo Cleaner
**Bundle ID:** com.huangxiaohao.DuplicatePhotoCleaner
**Target Market:** English-speaking markets (US, UK, Australia)
**Platform:** iOS 17+, SwiftUI, Photos framework
**Monetization:** One-time lifetime purchase (`com.cleanupphone.lifetime`) + 100 MB free tier
**Privacy:** 100% on-device photo processing, no photo uploads or third-party SDKs; limited anonymous first-party analytics

### Core Value Proposition
Helps users find and clean duplicate photos, similar photos, blurry photos, screenshots, videos, and unfavorited photos. One scan identifies what to clean. Reclaim gigabytes instantly.

### Target Users
iPhone/iPad users with large photo libraries who want to reclaim storage space by removing redundant, low-quality, or unwanted media.

---

## Product Requirements (V1.5)

### Functional Requirements

| # | Feature | Description |
|---|---------|-------------|
| F1 | Duplicate Detection | Perceptual hash-based (pHash) detection of exact/near-exact duplicate photos |
| F2 | Similar Photo Detection | Vision framework feature print + cosine similarity grouping (threshold: 0.85) |
| F3 | Blurry Photo Detection | Laplacian variance blur scoring with adjustable threshold (blurry/very blurry) |
| F4 | Screenshot Detection | Classify screenshots by time period (Today/This Week/This Month/Older) |
| F5 | Video Detection | List all videos sorted by file size (largest first) |
| F6 | Unfavorites Detection | Find all photos not marked as favorite, with time filter + mark-as-favorite |
| F7 | Photo Preview | Full-screen swipeable viewer with zoom, delete, mark-favorite, swipe-down-to-dismiss |
| F8 | Video Preview | Inline video player in sheet with info (size, resolution, duration, date) |
| F9 | Batch Selection | Select All / Deselect All, individual tap-to-select on each item |
| F10 | Smart Recommendation | Each duplicate/similar group auto-recommends the "best" photo to keep (highest resolution → largest file → oldest) |
| F11 | Delete Preference | 3 modes: Move to Recently Deleted / Delete Permanently / Ask Every Time |
| F12 | Free Tier Quota | 100 MB free deletion quota; paywall triggers when exceeded |
| F13 | Paywall | Contextual one-time lifetime purchase to unlock unlimited deletion |
| F14 | Restore Purchase | Restore previous purchases via `Transaction.currentEntitlements` |
| F15 | Settings | Delete mode picker, legal document links |
| F16 | Onboarding | Single-page animated feature introduction with CTA |
| F17 | Dual-Tab Dashboard | Unfavorites (default) | Smart Clean — segmented picker, pinned on scroll |
| F18 | Auto Smart Scan | Scans all 5 categories automatically on first launch |

### Non-Functional Requirements
- All photo processing 100% on-device (network is used only for anonymous first-party analytics and StoreKit)
- iOS 17+ (leverages `@Observable`, Swift Concurrency)
- iPhone + iPad support (`targetedDeviceFamily = "1,2"`)
- Light theme only (`.preferredColorScheme(.light)`)
- Haptic feedback on all user interactions
- Smooth animations on list updates (slide-out on delete)

---

## Project Structure

```
DuplicatePhotoCleaner/
├── App/
│   ├── DuplicatePhotoCleanerApp.swift    # @main, AppState (@Observable), DeletePreference, free tier quota
│   └── ContentView.swift                 # Root router: OnboardingView → PermissionRequest → DashboardView
│
├── Core/
│   ├── HashEngine/
│   │   ├── DuplicateDetector.swift       # DuplicateGroup struct, pHash-based detection actor
│   │   ├── HammingDistance.swift         # Hamming distance comparison for hash similarity
│   │   └── PerceptualHash.swift          # DCT-based perceptual hash computation
│   ├── PhotoLibrary/
│   │   ├── PhotoLibraryManager.swift     # PHAsset fetch (all photos, videos) actor
│   │   ├── PhotoPermissionManager.swift  # Photo library authorization handling
│   │   └── UnfavoritesFetcher.swift      # Fetch unfavorited photos + statistics, mark-as-favorite
│   ├── QualityEngine/
│   │   ├── BlurDetector.swift            # Laplacian variance blur scoring, BlurLevel enum
│   │   └── QualityAnalyzer.swift         # PhotoQuality struct, blurry detection pipeline
│   ├── ScanPipeline/
│   │   └── ScanOrchestrator.swift        # ScanCategory enum, CategoryScanState, orchestrator actor
│   ├── ScreenshotDetector/
│   │   └── ScreenshotClassifier.swift    # ScreenshotGroupData struct, time-based grouping
│   └── SimilarityEngine/
│       ├── CosineSimilarity.swift        # Cosine similarity computation for feature vectors
│       ├── FeatureExtractor.swift        # VNGenerateImageFeaturePrint request wrapper
│       └── SimilarityGrouper.swift       # SimilarGroup struct, similarity-based clustering
│
├── Features/
│   ├── Blurry/BlurryPhotosView.swift     # Blurry photo grid with blur score badge + threshold filter
│   ├── Dashboard/
│   │   ├── DashboardView.swift           # Dual-tab homepage: Unfavorites (default) | Smart Clean
│   │   │                                 # Unfavorites tab: embeds UnfavoritesView (scrollable: false)
│   │   │                                 # Smart Clean tab: FreeTierCard + ScanCategoryTile × 4
│   │   │                                 # Floating delete bar for Unfavorites (DashboardUnfavBarState)
│   │   └── StorageOverviewView.swift     # Storage bar chart + cumulative cleanup stats
│   ├── Duplicates/DuplicateGroupsView.swift   # Inline group cards: best + others, batch select + delete
│   ├── Onboarding/OnboardingView.swift   # Animated feature reveal with "Get Started" CTA
│   ├── Results/ResultCardView.swift      # Compact horizontal card for scan result rows
│   ├── Screenshots/ScreenshotsView.swift # Screenshot groups by time period, grid + batch delete
│   ├── Settings/SettingsView.swift       # Delete mode, legal links, app info
│   ├── Similar/SimilarGroupsView.swift   # Similar groups with similarity %, inline cards + delete
│   ├── Unfavorites/
│   │   └── UnfavoritesView.swift         # Unfavorited photos grid, time filter, delete, mark-favorite
│   └── Videos/VideosView.swift           # All videos sorted by size, multi-select delete
│
├── Monetization/
│   └── StoreKitManager.swift             # StoreKit 2: load/purchase/restore/listen, 3s timeout
│
└── Shared/
    ├── Components/
    │   ├── DeletePreferencePickerView.swift  # 3-option delete mode picker sheet
    │   ├── EmptyStateView.swift              # Empty state placeholder
    │   ├── FreeTierCard.swift                # Top dashboard card: free quota progress (free) / storage (pro)
    │   ├── FreeTierUsageCard.swift           # Free tier usage summary (legacy, may be unused)
    │   ├── FullScreenPhotoViewer.swift       # Full-screen swipeable viewer with zoom, delete, swipe-down dismiss
    │   ├── LegalDocumentView.swift           # WebView for Privacy Policy / Terms of Use
    │   ├── PaywallDeleteSheet.swift          # Contextual paywall: shows "Free Up X" / "You've Freed X"
    │   ├── PhotoThumbnailGrid.swift          # Reusable photo thumbnail grid component
    │   ├── PrimaryButton.swift               # Styled primary CTA button
    │   ├── ProgressBar.swift                 # Animated progress bar
    │   ├── RoundedCard.swift                 # Card container with rounded corners
    │   ├── SmartScanHeader.swift             # Auto-scan status indicator
    │   ├── StatusTag.swift                   # Small status badge
    │   ├── SuccessToast.swift                # Top toast notification (auto-dismiss 2s)
    │   └── TotalCleanedCard.swift            # Cumulative bytes freed + item count summary
    ├── DesignSystem/
    │   ├── Color+DesignSystem.swift          # Full color palette + Color(hex:) initializer
    │   ├── Constants.swift                   # Layout, Radius, Spacing constants
    │   ├── Font+DesignSystem.swift           # Font presets
    │   └── ViewModifiers.swift               # pressableScale, cardBackground, sectionHeaderStyle
    ├── Extensions/
    │   ├── FileManager+Storage.swift         # Device storage info (used/total GB)
    │   └── PHAsset+Extensions.swift          # fileSizeFormatted, fileSizeBytes (thread-safe cached), resolution, date, duration
    └── Utils/
        └── HapticManager.swift               # Haptic feedback wrappers (selection, notification)
```

---

## Architecture

### App State

`AppState` is an `@Observable` class injected via `.environment(appState)`.

```swift
@Observable class AppState {
    var hasCompletedOnboarding: Bool        // persisted in UserDefaults
    var purchasedProductIDs: Set<String>    // StoreKit 2 purchase state
    var isPurchased: Bool                   // computed: contains lifetimeID
    var deletePreference: DeletePreference  // persisted in UserDefaults
    var includeVideos: Bool                 // persisted in UserDefaults
    var includeICloud: Bool                 // persisted in UserDefaults

    // Free tier quota
    static let freeTierTotalQuota: Int64 = 100_000_000  // 100 MB
    var freeDeletesUsedBytes: Int64         // persisted in UserDefaults
    var freeDeletesRemainingBytes: Int64    // computed
    var isFreeTierExhausted: Bool           // computed
    var freeQuotaProgress: Double           // 0.0–1.0
    func consumeFreeQuota(bytes: Int64) -> Int64

    // Cleanup stats
    var totalCleanableBytes: Int64          // set by Dashboard
    var totalCleanableCount: Int            // set by Dashboard
    var cumulativeFreedBytes: Int64         // persisted in UserDefaults
    var cumulativeDeletedCount: Int         // persisted in UserDefaults
    func recordCleanup(freedBytes: Int64, deletedCount: Int)
}
```

### Data Models (all `let` structs — immutable)

| Model | Properties | Usage |
|-------|-----------|-------|
| `DuplicateGroup` | `assets: [PHAsset]`, `recommended: PHAsset` | Duplicate detection results |
| `SimilarGroup` | `assets: [PHAsset]`, `recommended: PHAsset`, `averageSimilarity: Float` | Similar photo groups |
| `ScreenshotGroupData` | `group: ScreenshotTimeGroup`, `assets: [PHAsset]`, `totalSize: Int64` | Screenshot time groups |
| `PhotoQuality` | `asset: PHAsset`, `blurScore: Double`, `blurLevel: BlurLevel`, `fileSize: Int64` | Blur detection results |
| `ScanResultData` | `duplicateGroups`, `similarGroups`, `blurryPhotos`, `screenshotGroups`, `videos`, `unfavoritedPhotos` | `@Observable` reference type holding all scan results |

**Critical:** Data model structs have `let` properties. You CANNOT mutate `assets` in place. Always use `compactMap` to create new instances when filtering.

### Scan Pipeline

```
DashboardView
  └─ ScanOrchestrator (actor)
       ├─ PhotoLibraryManager    → fetchAllPhotos / fetchVideos
       ├─ DuplicateDetector      → pHash + Hamming distance grouping
       ├─ SimilarityGrouper      → Vision feature print + cosine similarity clustering
       ├─ QualityAnalyzer        → Laplacian variance blur scoring
       ├─ ScreenshotClassifier   → PHAssetMediaSubtype.photoScreenshot + time grouping
       └─ UnfavoritesFetcher     → isFavorite == false fetch + statistics
```

**Scan categories (6 total):**
1. **Duplicates** — Perceptual hash comparison, groups photos with Hamming distance ≤ 10
2. **Videos** — All videos sorted by file size (largest first)
3. **Screenshots** — Classified by time period (Today/Week/Month/Older)
4. **Unfavorites** — Photos with `isFavorite == false`, sorted by date descending
5. **Similar** — Vision framework feature prints, cosine similarity ≥ 0.85

**Auto-scan priority order:** `[.duplicates, .videos, .screenshots, .unfavorites, .similar]`

**Scan trigger:** Auto-scan on first launch (`startSmartScan`); subsequent visits show cached results. Manual re-scan per category available.

**Library caching:** `ScanOrchestrator` caches the photo library fetch (`cachedPhotos`) so duplicate/similar/blurry/unfavorites scans share a single library fetch instead of multiple separate ones.

### Navigation Flow

```
App Launch
  └─ ContentView
       ├─ [First Launch] → OnboardingView → Permission Request → DashboardView
       └─ [Returning]    → DashboardView (dual-tab homepage)
                             ├─ Tab 1: Unfavorites (default tab)
                             │   └─ UnfavoritesView (embedded, scrollable: false)
                             │       ├─ Time filter (All / 7d / 30d / 90d / 6mo)
                             │       ├─ 3-column photo grid with selection
                             │       └─ Floating delete bar (DashboardUnfavBarState)
                             ├─ Tab 2: Smart Clean
                             │   └─ ScrollView
                             │       ├─ FreeTierCard (free quota or storage)
                             │       └─ ScanCategoryTile × 4 (Duplicates, Videos, Screenshots, Similar)
                             ├─ → DuplicateGroupsView     (navigationDestination)
                             ├─ → SimilarGroupsView       (navigationDestination)
                             ├─ → ScreenshotsView         (navigationDestination)
                             ├─ → VideosView              (navigationDestination)
                             ├─ → SettingsView            (sheet)
                             └─ → PaywallDeleteSheet      (sheet)
```

**Tab switching:** `ScrollViewReader` + `proxy.scrollTo("tabTop", anchor: .top)` on tab change to prevent white screen from preserved scroll position.

### Monetization

- **Product:** `com.cleanupphone.lifetime` — one-time lifetime purchase
- **Free tier:** 100 MB free deletion quota (`freeTierTotalQuota`). Free users can scan and delete up to 100 MB total. Paywall triggers when quota is exceeded.
- **Paywall triggers:** Delete action when `freeDeletesRemainingBytes <= 0` or `selectedSizeBytes > freeDeletesRemainingBytes`
- **Contextual paywall:** Title adapts — "Free Up X Right Now" / "You've Freed X" / "Unlock Full Cleanup"
- **StoreKit 2:** `Transaction.currentEntitlements` for purchase verification, `Transaction.updates` for real-time listener
- **Timeout:** 3 seconds on all StoreKit network calls (prevents UI freeze on no-network)
- **No `@MainActor`:** `StoreKitManager` runs StoreKit operations on background threads to prevent UI blocking when network is unavailable
- **Dismiss during purchase:** `interactiveDismissDisabled(isPurchasing)` prevents user from dismissing paywall mid-purchase

### Delete Preference System

`DeletePreference` enum (persisted in UserDefaults):
- `.askEveryTime` — default, shows picker every time (first use)
- `.recentlyDeleted` — move to iOS Recently Deleted (recoverable 30 days)
- `.permanent` — permanent deletion via `PHAssetChangeRequest.deleteAssets`

Flow: Tap delete → check `isPurchased` (paywall if not) → check `freeDeletesRemainingBytes` (paywall if exceeded for free users) → check `deletePreference` (picker if `.askEveryTime`) → execute delete → `consumeFreeQuota` → `recordCleanup` → haptic + toast → data refresh with animation.

### Unfavorites + Floating Delete Bar Pattern

The Unfavorites tab uses a **floating delete bar** fixed at the screen bottom (outside the `ScrollView`). This requires a cross-view communication pattern:

1. **`DashboardUnfavBarState`** (`@Observable class`): Shared between DashboardView and UnfavoritesView. Holds `selectedCount`, `totalCount`, `allSelected`.
2. **`UnfavoritesDeleteActionHolder`** (singleton): Bridges button taps from Dashboard's floating bar to UnfavoritesView's internal actions. Holds `deleteAction` and `toggleSelectAllAction` closures.
3. **`UnfavoritesView.syncBarState()`**: Called on appear, selection change, and filter change to keep `barState` in sync.

---

## UI/UX Design System

### Color Palette

| Token | Hex | Usage |
|-------|-----|-------|
| `appPrimary` | #C15F3C | CTAs, primary accent, progress |
| `appPrimaryLight` | #D4836A | Lighter primary variant |
| `appSuccess` | #6B8F5B | Best photo badge, success states, cleanup stats |
| `appWarning` | #C4903D | Low storage warning, blur score |
| `appDanger` | #B84C4C | Delete buttons, very blurry badge |
| `appTeal` | #6A9BA5 | Similar category, secondary accent |
| `appPurple` | #8B7D9E | Screenshot category, "Why" info row |
| `appRose` | #D4566B | Unfavorites category, selection indicator |
| `appCamel` | #A67B5B | Video category |
| `appBackground` | #F4F3EE | Main background (warm gray) |
| `appBackgroundSecondary` | #EDECEA | Card/image backdrop |
| `appBackgroundTertiary` | #DEDBD5 | Grid cell placeholder, inactive states |
| `appSurface` | white | Card surfaces |
| `appTextPrimary` | #2D2A26 | Headlines, primary text |
| `appTextSecondary` | #8A8580 | Subtitles, descriptions |
| `appTextTertiary` | #B1ADA1 | Hints, timestamps |
| `appTextQuaternary` | #C8C4BC | Disabled text |
| `appDivider` | #D8D5CE | Standard divider |
| `appDividerLight` | #E8E6E1 | Light divider |

### Typography

| Name | Size | Weight | Usage |
|------|------|--------|-------|
| `appH1` | 22 | semibold | Page titles, paywall headline |
| `appH2` | 20 | semibold | Section titles |
| `appH3` | 17 | semibold | Card titles, sheet titles, storage overview |
| `appBody` | 16 | medium | Body text |
| `appBodyRegular` | 15 | regular | Body text (lighter) |
| `appCaption` | 14 | regular | Secondary info, descriptions |
| `appCaptionMedium` | 14 | medium | Info values, button labels |
| `appSmall` | 13 | medium | Small labels |
| `appSmallSemibold` | 13 | semibold | Category names, counts |
| `appTiny` | 12 | medium | Tiny labels |
| `appTinySemibold` | 12 | semibold | Threshold filter buttons |
| `appMicro` | 11 | semibold | Progress text, duration badges |
| `appMonoSmall` | 12 | medium | Monospaced numbers |

**Note:** `appBodySemibold` does NOT exist. Use `.appBody` or `.appH3`.

### Spacing & Layout

- `Layout.pageHorizontalPadding` — standard page side padding
- `Layout.headerToContent` — gap between nav bar and content
- `Layout.cardSpacing` — gap between cards in grid
- `Layout.scrollBottomPadding` — bottom scroll padding
- `Radius.sm/md/xl` — corner radius presets

### Component Patterns

- **RoundedCard** — main card container with background fill + corner radius
- **PrimaryButton** — full-width capsule CTA with icon + label
- **ProgressBar** — animated horizontal progress indicator
- **SuccessToast** — top overlay toast with spring animation, auto-dismiss 2s
- **StatusTag** — small colored pill badge
- **FullScreenPhotoViewer** — full-screen swipeable viewer with:
  - `TabView(.page)` for horizontal swipe between photos
  - `ZoomablePhotoImage` — pinch-to-zoom, double-tap toggle, pan when zoomed
  - Swipe-down-to-dismiss: `DragGesture` on `ZStack` (NOT on `TabView`)
  - `ConditionalPanGesture` ViewModifier — only registers `DragGesture` when `scale > 1`, so TabView's horizontal page swipe is never blocked at scale==1
  - In-session deletion tracking: `deletedAssetIDs: Set<String>`, `remainingAssets` computed property
  - After delete: auto-advance to next non-deleted photo, toast confirmation, auto-dismiss if ≤1 remaining
- **PhotoPreviewContext** — `Identifiable` struct passed to `FullScreenPhotoViewer` via `.fullScreenCover(item:)`; `category` enum distinguishes Unfavorites/Duplicates/Similar/Blurry/Screenshots/Videos
- **PaywallDeleteSheet** — contextual paywall with dynamic title, `PremiumPricingCard`, `BenefitsGrid`, `interactiveDismissDisabled` during purchase

---

## Key User Flows

### 1. First Launch
```
Launch → OnboardingView (animated feature reveal, 1.6s)
  → "Get Started" button
  → Permission Request
  → DashboardView (auto startSmartScan begins)
       ├─ Tab 1 (default): UnfavoritesView — time filter + photo grid
       └─ Tab 2: Smart Clean — FreeTierCard + 4 scan category tiles
```

### 2. Scan & Delete (Duplicates)
```
Tap "Duplicates" tile → Permission check → Scan (pHash all photos)
  → Auto-navigate to DuplicateGroupsView
  → Group cards: Best photo (left) + Others (right, pre-selected)
  → Tap image → FullScreenPhotoViewer (swipe, zoom, delete with toast + auto-advance)
  → Tap checkbox → toggle selection
  → "Select All" / "Deselect All" in toolbar
  → Bottom bar: "Free up XX MB" → "Delete X"
  → DeletePreferencePickerView (if .askEveryTime)
  → PHAssetChangeRequest.deleteAssets → consumeFreeQuota → Haptic + Toast → list refresh
```

### 3. Unfavorites Tab
```
DashboardView (default tab)
  → UnfavoritesView (embedded, scrollable: false)
  → Time filter: All / 7 days / 30 days / 90 days / 6 months
  → 3-column photo grid with selection overlay
  → Tap photo → FullScreenPhotoViewer with mark-favorite button
  → Floating delete bar (fixed at screen bottom, outside ScrollView)
  → Select All / Deselect All via UnfavoritesDeleteActionHolder singleton
  → Delete → paywall check → delete flow
```

### 4. Purchase Flow
```
Tap delete → Not purchased / quota exceeded → PaywallDeleteSheet
  → Contextual title: "Free Up X Right Now" / "You've Freed X"
  → PremiumPricingCard ($19.99 → $9.99, corner ribbon)
  → BenefitsGrid (2×2 + 2 full-width)
  → "Unlock Lifetime" button → StoreKit 2 purchase
  → interactiveDismissDisabled during purchase
  → verification → transaction.finish() → dismiss
```

---

## SwiftUI Patterns & Pitfalls

### Environment & State
- `AppState` injected via `.environment(appState)` at root, read via `@Environment(AppState.self)` in children
- All `.sheet` modifiers must explicitly pass `.environment(appState)` — sheets do NOT inherit environment
- `@State` for view-local mutable state, `@Bindable` for `@Observable` bindings
- `@Observable` reference types (`ScanResultData`, `CategoryScanState`) allow detail views to see updates without `.id()` tricks

### Navigation
- `NavigationStack` with `.navigationDestination(item: $navigateCategory)` for category navigation
- `navigateCategory` set to target value triggers navigation; set to `nil` then `asyncAfter(0.05)` re-set to same value to re-trigger
- **No `.id(stateVersion)` needed** — `@Observable` on `ScanResultData` triggers view updates automatically. Removing `.id()` preserves scroll position and selection state after delete.

### Data Refresh After Delete
- All delete callbacks wrapped in `withAnimation { ... }` for smooth item removal
- Child views call `onGroupsChanged?(updated)` with filtered data; parent updates `scanData` directly
- No view recreation needed — `@Observable` handles re-rendering

### Tab Switching (ScrollViewReader Pattern)
```swift
ScrollViewReader { proxy in
    ScrollView {
        LazyVStack {
            Color.clear.frame(height: 0).id("tabTop")  // anchor
            ...
        }
    }
    .onChange(of: selectedTab) { _, _ in
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo("tabTop", anchor: .top)
        }
    }
}
```

### Image Loading
- `PHImageManager.requestImage` callbacks may fire multiple times (degraded → full quality)
- Always check `PHImageResultIsDegradedKey` and skip degraded images for final display
- Use direct callbacks (not `withCheckedContinuation`) to avoid crash on double-resume
- Two-stage loading: `.opportunistic` fast thumbnail first, then `.highQualityFormat` replacement
- `PHAsset.fileSizeBytes` uses `NSLock` + cache dictionary for thread-safe performance

### Video Loading
- `PHImageManager.requestAVAsset` with `opts.isNetworkAccessAllowed = true` for iCloud support
- 15-second timeout via `DispatchQueue.main.asyncAfter` + `cancelImageRequest` to prevent infinite hang
- Inline `VideoPlayer` with thumbnail backdrop + loading spinner

### Pitfalls (Lessons Learned)

1. **Sheet reads stale state:** Presenting a `.sheet` in the same run loop as state changes may read old values. Fix: `Group { if !data.isEmpty { SheetContent() } }`.

2. **`withCheckedContinuation` + PHImageManager:** PHImageManager calls callback multiple times. `withCheckedContinuation` crashes if resumed more than once. Use direct callbacks.

3. **`let` struct properties:** Data models have `let` arrays. Never mutate in place — use `compactMap` to create new instances.

4. **Sheet environment inheritance:** `.sheet` does not inherit `.environment()`. Always pass `.environment(appState)` explicitly.

5. **`.scrollContentBackground(.hidden)`** on a `List` makes it transparent, exposing dark background in sheets. Never use with sheets.

6. **Navigation re-trigger:** Setting `@State` binding to the same value doesn't re-trigger. Fix: set `nil` first, then `asyncAfter(0.05)` set to target.

7. **`@MainActor` + StoreKit:** `@MainActor` on `StoreKitManager` causes network calls to block the main thread when no internet. Remove `@MainActor` to let StoreKit run on background threads.

8. **`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`:** Project-level setting makes all types `@MainActor` by default. `actor` types have their own isolation — they are NOT MainActor. Properties accessed from actors need `nonisolated`.

9. **`print()` stripped in Release:** Use `NSLog()` for logging that must appear in Release builds.

10. **LazyVGrid cell sizing:** All grid cells use `Color.aspectRatio(1, .fit)` as the BASE view with image in `.overlay`. This guarantees the cell size is determined by the grid column width, NOT by the image's intrinsic size:
    ```swift
    Color.appBackgroundTertiary
        .aspectRatio(1, contentMode: .fit)   // base: forces square from column width
        .overlay { Image.resizable().scaledToFill() }  // image in overlay
        .clipped()
        .overlay(alignment: .topTrailing) { /* selection circle */ }
        .overlay(alignment: .bottomLeading) { /* badges */ }
    ```

11. **TabView swipe vs DragGesture:** A `DragGesture` on `TabView` overrides its built-in horizontal page swipe. Put swipe-down-to-dismiss `DragGesture` on the outer `ZStack` instead. For zoomable images, use a `ViewModifier` that conditionally registers `DragGesture` only when zoomed — when scale==1, no gesture is registered, so TabView swipe works unblocked.

12. **`.id()` destroys scroll and selection state:** Using `.id(stateVersion)` to force view recreation loses all `@State` (scroll position, selection set). With `@Observable` reference types, this is unnecessary — data changes trigger re-renders automatically.

---

## App Store Submission Checklist

### Code (Done)
- [x] Remove all `print()` debug statements from production code
- [x] `ITSAppUsesNonExemptEncryption = NO` in project settings
- [x] Remove unused Swift files (dead code cleanup)
- [x] `PrivacyInfo.xcprivacy` — UserDefaults API declaration
- [x] 0 compile errors

### App Store Connect (Manual)
- [ ] IAP product `com.cleanupphone.lifetime` — confirm status is "Ready to Submit" or "Approved"
- [ ] Privacy Policy URL: `https://xiaohao7023.github.io/dupes-legal/privacy.html`
- [ ] Support URL: `https://xiaohao7023.github.io/dupes-legal/support.html`
- [ ] Privacy Nutrition Labels: select "Does Not Collect Data"
- [ ] Age rating: 4+
- [ ] App Review Notes: "100% on-device processing. No login required. No third-party SDKs."
- [ ] Screenshots: 6.7" iPhone + 12.9" iPad (at least one set each)
- [ ] What's New text (English)

### Legal Documents
- Privacy Policy and Terms of Use hosted at GitHub Pages
- Accessible from: PaywallDeleteSheet, SettingsView
- Contact email: `huangxiaohao7023@icloud.com`

---

## Build Configuration

| Setting | Value |
|---------|-------|
| Deployment Target | iOS 17.0 |
| Swift Version | 5.0 (Swift 6 concurrency) |
| `SWIFT_APPROACHABLE_CONCURRENCY` | YES |
| `SWIFT_DEFAULT_ACTOR_ISOLATION` | MainActor |
| `targetedDeviceFamily` | 1,2 (iPhone + iPad) |
| `GENERATE_INFOPLIST_FILE` | YES |
| `ITSAppUsesNonExemptEncryption` | NO |
| Bundle ID | `com.huangxiaohao.DuplicatePhotoCleaner` |
| Development Team | G7RA2PAX7U |
| Marketing Version | 1.5 |
| Current Project Version | 1 |

---

## Known Warnings (Not Bugs)

- `nonisolated(unsafe) ... cacheLock` — Swift 6 concurrency false positive. The `SimpleLock` is `@unchecked Sendable` and thread-safe. Compiler warns it's "unnecessary" but access from `nonisolated` context requires it.
- `PHAssetResource.assetResources(for:)` — "Missing prefetched properties" warning when accessing file size metadata. Does not affect functionality.
- `Error Domain=com.apple.accounts Code=7` — Simulator/Apple ID issue, not a code bug.
- `FBSSceneSnapshotErrorDomain code 3` — iOS scene snapshot canceled during sheet animation, simulator only.
- SourceKit cross-file resolution errors — IDE indexing issues, not build errors.
- StoreKit network errors (Code=-1009) — Expected when device has no internet. StoreKit operations run on background threads and do not block UI.

---

## Version History

### V1.5 (2026-06-16)
- **Unfavorites feature**: New `UnfavoritesView` + `UnfavoritesFetcher` — find all photos not marked as favorite, with time filter (All / 7d / 30d / 90d / 6mo), batch delete, and mark-as-favorite
- **Dual-tab dashboard**: Homepage restructured to Unfavorites (default) | Smart Clean with segmented picker (pinned on scroll via `pinnedViews: [.sectionHeaders]`)
- **Floating delete bar**: Fixed at screen bottom for Unfavorites tab, communicates via `DashboardUnfavBarState` + `UnfavoritesDeleteActionHolder` singleton
- **Full-screen photo viewer**: New `FullScreenPhotoViewer` replaces `FloatingPhotoPreview`
  - Swipe left/right to browse all photos in group
  - Pinch-to-zoom with `ConditionalPanGesture` (pan only when zoomed, TabView swipe unblocked at scale==1)
  - Swipe-down-to-dismiss (DragGesture on ZStack, not TabView)
  - Delete shows toast "Photo deleted" and auto-advances to next photo
  - In-session deletion tracking via `deletedAssetIDs` + `remainingAssets`
- **Auto Smart Scan**: Scans all 5 categories on first launch in priority order
- **Tab scroll reset**: `ScrollViewReader` + `scrollTo("tabTop")` on tab switch prevents white screen
- **No more `.id(stateVersion)`**: `@Observable` reference types handle view updates; preserves scroll position and selection after delete
- **Free tier quota**: 100 MB free deletion limit; `PaywallDeleteSheet` replaces standalone `PaywallView`
- **Contextual paywall**: Dynamic title based on usage state, `interactiveDismissDisabled` during purchase
- **New components**: `FreeTierCard`, `TotalCleanedCard`, `SmartScanHeader`, `ResultCardView`
- **Deleted**: `PaywallView.swift`, `FloatingPhotoPreview.swift`

### V1.4 (2026-06-15)
- **LazyVGrid cell sizing FIXED**: Standardized all grid cells to `Color.aspectRatio(1, .fit)` as base + image in `.overlay`. Fixed portrait/landscape height inconsistency.

### V1.3 (2026-06-15)
- **Full-screen photo preview**: Unified `FullScreenPhotoViewer` with swipe, delete, mark-favorite
- **Best marking**: DuplicateGroupsView and SimilarGroupsView show Best badge in grid
- **PhotoPreviewContext**: `Identifiable` struct for `.fullScreenCover(item:)` with category enum

### V1.2 (2026-06-09)
- Moved debug controls (Reset Free Quota, Reset Purchase) from Dashboard to Settings
- Version bumped to 1.2 (build 2)

### V1.1 (2026-06-09)
- **UI Redesign**: Warm-ivory color theme
- **Typography**: Removed excessive bold/black font weights
- **Paywall Redesign**: High-conversion layout with 2x2 benefits grid, corner ribbon
- **Bug Fix**: Delete cancellation — `try?` → `do/catch` on `PHPhotoLibrary.performChanges`
- **Privacy Manifest**: Added `PrivacyInfo.xcprivacy`
- **Settings**: Added Debug section with Reset Free Quota / Reset Purchase controls

### V1.0 (2026-05-13)
- Initial App Store submission
- 5 scan categories: Duplicates, Similar, Blurry, Screenshots, Videos
- Inline group card design with best photo recommendation
- Swipeable photo preview with image info
- Inline video player with auto-load and timeout
- One-time lifetime purchase via StoreKit 2
- Delete preference system (Recently Deleted / Permanent / Ask Every Time)
- Cumulative cleanup stats on Dashboard
- Animated onboarding flow
- Settings with legal document links
