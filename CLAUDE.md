# Duplicate Photo Cleaner - Project Documentation

## Overview

iOS app that helps users find and clean duplicate photos, similar photos, blurry photos, and screenshots. 100% on-device processing, no cloud uploads.

**App Store Name:** Duplicate Photo Cleaner
**Target Market:** English-speaking markets (US, UK, Australia)
**Platform:** iOS 17+, SwiftUI, Photos framework

---

## Project Structure

```
DuplicatePhotoCleaner/
├── App/
│   ├── DuplicatePhotoCleanerApp.swift    # @main, AppState (@Observable), DeletePreference enum
│   └── ContentView.swift                 # Root: OnboardingView → DashboardView
│
├── Core/
│   ├── HashEngine/                       # Perceptual hash for duplicate detection
│   │   ├── DuplicateDetector.swift       # DuplicateGroup struct + detection actor
│   │   ├── HammingDistance.swift
│   │   └── PerceptualHash.swift
│   ├── PhotoLibrary/
│   │   ├── PhotoLibraryManager.swift     # Fetch all photos actor
│   │   └── PhotoPermissionManager.swift  # Permission handling
│   ├── QualityEngine/
│   │   ├── BlurDetector.swift            # BlurLevel enum
│   │   └── QualityAnalyzer.swift         # PhotoQuality struct + blurry detection
│   ├── ScanPipeline/
│   │   ├── ScanOrchestrator.swift        # ScanCategory enum, CategoryScanState, ScanOrchestrator actor
│   │   ├── ScanProgress.swift            # ScanProgressState
│   │   └── ScanResult.swift              # ScanResult struct
│   ├── ScreenshotDetector/
│   │   └── ScreenshotClassifier.swift    # ScreenshotGroupData struct + classification
│   └── SimilarityEngine/
│       ├── CosineSimilarity.swift
│       ├── FeatureExtractor.swift
│       └── SimilarityGrouper.swift       # SimilarGroup struct + grouping actor
│
├── Features/
│   ├── Blurry/BlurryPhotosView.swift     # Blurry photo grid with selection + delete
│   ├── Dashboard/
│   │   ├── DashboardView.swift           # Main screen: storage + 4 scan category cards
│   │   └── StorageOverviewView.swift     # Storage bar + cumulative cleanup stats
│   ├── Duplicates/
│   │   ├── DuplicateGroupDetailView.swift  # [UNUSED] Legacy detail view
│   │   └── DuplicateGroupsView.swift       # Inline group cards with selection + batch delete
│   ├── Onboarding/OnboardingView.swift     # Single-page animated onboarding
│   ├── Paywall/PaywallView.swift
│   ├── PhotoViewer/PhotoViewerView.swift   # Full-screen image viewer with zoom
│   ├── Results/ResultCardView.swift
│   ├── ScanProgress/ScanProgressView.swift
│   ├── Screenshots/ScreenshotsView.swift   # Screenshot groups, always expanded
│   ├── Settings/SettingsView.swift         # Settings sheet with Delete Mode picker
│   ├── Similar/
│   │   ├── SimilarGroupDetailView.swift    # [UNUSED] Legacy detail view
│   │   └── SimilarGroupsView.swift         # Inline group cards with selection + batch delete
│   └── Settings/SettingsView.swift
│
├── Monetization/
│   ├── PurchaseStatus.swift
│   └── StoreKitManager.swift
│
└── Shared/
    ├── Components/
    │   ├── DeleteConfirmSheet.swift        # Simple delete confirmation (used when preference is set)
    │   ├── DeletePreferencePickerView.swift # 3-option delete mode picker (sheet)
    │   ├── EmptyStateView.swift
    │   ├── FloatingPhotoPreview.swift       # Half-screen sheet for photo preview with swipe + info
    │   ├── PhotoPreviewSheet.swift          # [UNUSED] Old full preview, replaced by FloatingPhotoPreview
    │   ├── PhotoThumbnailGrid.swift
    │   ├── PrimaryButton.swift
    │   ├── ProgressBar.swift
    │   ├── RoundedCard.swift
    │   ├── StatusTag.swift
    │   └── SuccessToast.swift              # Top toast notification
    ├── DesignSystem/
    │   ├── Color+DesignSystem.swift        # Warm earth-tone palette (appPrimary: #C15F3C)
    │   ├── Constants.swift                 # Layout, Radius, Spacing constants
    │   ├── Font+DesignSystem.swift         # Font presets (appH1-H3, appBody, appCaption, etc.)
    │   └── ViewModifiers.swift             # pressableScale, cardBackground, sectionHeaderStyle
    ├── Extensions/
    │   ├── FileManager+Storage.swift
    │   └── PHAsset+Extensions.swift        # fileSizeFormatted, fileSizeBytes (cached), resolutionFormatted
    └── Utils/
        └── HapticManager.swift
```

---

## Key Architecture Decisions

### App State (`AppState`)
- `@Observable` class, injected via `.environment(appState)`
- Properties: `hasCompletedOnboarding`, `includeVideos`, `includeICloud`, `deletePreference`
- Cumulative stats: `cumulativeFreedBytes`, `cumulativeDeletedCount` (persisted in UserDefaults)
- **Color scheme:** Forced `.preferredColorScheme(.light)` — the app uses a warm light theme

### Data Models (all structs with `let` properties)
- `DuplicateGroup`: `assets: [PHAsset]`, `recommended: PHAsset`
- `SimilarGroup`: `assets: [PHAsset]`, `recommended: PHAsset`, `averageSimilarity: Float`
- `ScreenshotGroupData`: `group: ScreenshotTimeGroup`, `assets: [PHAsset]`, `totalSize: Int64`
- `PhotoQuality`: `asset: PHAsset`, `blurScore`, `blurLevel`, `fileSize`

**Important:** These structs have `let` properties. You CANNOT mutate `assets` in place. Use `compactMap` to create new instances when filtering.

### Delete Preference System
- `DeletePreference` enum: `.recentlyDeleted`, `.permanent`, `.askEveryTime`
- Default: `.askEveryTime` (first use always shows picker)
- After first choice: remembered in UserDefaults, subsequent deletes execute directly
- Settings page allows changing the preference
- `DeletePreferencePickerView` is a reusable sheet component (takes optional `onConfirm` callback)
- `DeleteConfirmSheet` exists but is currently unused

### Scan Flow
- Dashboard has 4 category cards (Duplicates, Similar, Blurry, Screenshots)
- Each card has its own `CategoryScanState` and `ScanOrchestrator`
- Tap "Scan" → permission check → scan → auto-navigate to results
- Navigation: `NavigationStack` with `navigationDestination(item:)` on `ScanCategory?`

---

## UI Patterns

### Navigation
- All secondary pages: `.navigationBarTitleDisplayMode(.inline)` — no large titles
- All pages have `.toolbarBackground(Color.appBackground)` for consistent styling
- No custom toolbar leading text (removed "Photo Cleaner", "Settings", etc.)

### Duplicate & Similar Pages (Inline Design)
- **No detail pages** — everything shown inline in group cards
- Each card: Best photo (left) + Others stacked (right) with checkbox overlay
- **Default selection:** All "Others" photos pre-selected
- **Toolbar:** "Select All" / "Deselect All" toggle button (top-right)
- **Tap zone separation on Others photos:**
  - **Tap image area** → opens `FloatingPhotoPreview` sheet
  - **Tap checkbox circle** (top-right) → toggles selection
  - Selection red overlay uses `.allowsHitTesting(false)` to not block image taps
- **Tap Best photo** → opens `FloatingPhotoPreview` sheet with "Best Photo" title
- **Photo preview:** half-screen sheet (82%), swipeable, shows category title ("Best Photo" / "Other Copies"), image info (size/resolution/date), two-stage image loading (fast thumbnail → high quality)
- **Bottom floating action bar:** "Free up XX MB" + "Delete X" capsule button (fully opaque, solid `Color.appBackground`)
- Single batch delete across all groups

### Blurry Photos Page
- Grid layout with threshold filter (blurry/very blurry)
- "Select All" in toolbar
- Selection with red overlay + checkmark
- Bottom floating delete bar (same as Duplicates/Similar)

### Screenshots Page
- All groups always expanded (no collapse/expand)
- Each group shows date header + count/size + photo grid
- "Select All" in toolbar
- Bottom floating delete bar

### Delete Flow
1. User taps delete button
2. If `deletePreference == .askEveryTime` → show `DeletePreferencePickerView` sheet
3. Otherwise → execute delete directly
4. After delete: `HapticManager.notification(.success)` + `SuccessToast` + data refresh
5. Deleted items removed from data arrays; empty groups removed

### Toast
- `SuccessToast` component: capsule with checkmark + message
- Shown via `.overlay(alignment: .top)` with spring animation
- Auto-dismiss after 2 seconds

### Sheets
- All sheets pass `.environment(appState)` to fix environment inheritance
- Settings sheet: `.listStyle(.insetGrouped)` without `.scrollContentBackground(.hidden)` (caused black screen)
- Delete preference sheet: `.presentationDetents([.fraction(0.6)])`
- **Photo preview sheet:** `FloatingPhotoPreview` — `.presentationDetents([.fraction(0.82), .large])`, no drag indicator, swipeable images (fixed 360pt height, `.fill` + `.clipped`), category title, info rows (size/resolution/date)
  - **Sheet empty assets workaround:** SwiftUI sheets may read stale state on first present. Wrap content in `Group { if !assets.isEmpty { ... } }` to defer rendering until data is populated.
  - **Image loading:** Two-stage — `.opportunistic` fast thumbnail first, then `.highQualityFormat` replacement. 0.3s delay before loading to let sheet animation settle.
  - **`PhotoPreviewCategory` enum:** `.best` ("Best Photo") / `.others` ("Other Copies"), passed through callback chain `(PHAsset, PhotoPreviewCategory) -> Void`

---

## Available Fonts (Font+DesignSystem.swift)

| Name | Size | Weight |
|------|------|--------|
| `appH1` | 22 | semibold |
| `appH2` | 20 | semibold |
| `appH3` | 17 | semibold |
| `appBody` | 16 | medium |
| `appBodyRegular` | 15 | regular |
| `appCaption` | 14 | regular |
| `appCaptionMedium` | 14 | medium |
| `appSmall` | 13 | medium |
| `appSmallSemibold` | 13 | semibold |
| `appTiny` | 12 | medium |
| `appTinySemibold` | 12 | semibold |
| `appMicro` | 11 | semibold |
| `appMonoSmall` | 12 | medium (monospaced) |

**Note:** `appBodySemibold` does NOT exist. Use `appBody` or `appH3`.

---

## Color Palette (Color+DesignSystem.swift)

- **Primary:** `appPrimary` (#C15F3C, warm brown-red)
- **Success:** `appSuccess` (#6B8F5B, sage green)
- **Warning:** `appWarning` (#C4903D, amber)
- **Danger:** `appDanger` (#B84C4C, muted red)
- **Teal:** `appTeal` (#6A9BA5)
- **Purple:** `appPurple` (#8B7D9E)
- **Background:** `appBackground` (#F4F3EE, warm gray)
- **Text:** `appTextPrimary` (#2D2A26), `appTextSecondary` (#8A8580), `appTextTertiary` (#B1ADA1)

---

## Dead Code (can be safely removed)

- `Features/DeleteConfirmation/DeleteConfirmationView.swift` — old 2-option delete dialog, unused
- `Features/Duplicates/DuplicateGroupDetailView.swift` — replaced by inline cards
- `Features/Similar/SimilarGroupDetailView.swift` — replaced by inline cards
- `Shared/Components/DeleteConfirmSheet.swift` — currently unused
- `Shared/Components/PhotoPreviewSheet.swift` — replaced by FloatingPhotoPreview
- `Features/PhotoViewer/PhotoViewerView.swift` — full-screen viewer, replaced by FloatingPhotoPreview sheet

---

## SwiftUI Pitfalls (lessons learned)

- **Sheet reads stale state:** Presenting a `.sheet` in the same run loop as state changes may read old values. Fix: `Group { if !data.isEmpty { SheetContent() } }` to defer rendering.
- **`withCheckedContinuation` + PHImageManager:** PHImageManager may call the callback multiple times (degraded + full quality). `withCheckedContinuation` crashes if resumed more than once. Use direct callbacks instead.
- **`let` struct properties:** `DuplicateGroup`, `SimilarGroup`, `ScreenshotGroupData` all have `let` arrays. Never mutate in place — use `compactMap` to create new instances with filtered arrays.
- **Sheet environment inheritance:** `.sheet` does not inherit `.environment()` from parent. Always pass `.environment(appState)` on every `.sheet` modifier.
- **`.scrollContentBackground(.hidden)`** on a `List` makes it transparent, exposing the sheet's dark default background. Do not use with sheets.
- **`appBodySemibold` font does not exist.** Use `.appBody` or `.appH3`.
- **Navigation re-trigger:** Setting a `@State` navigation binding to the same value doesn't re-trigger navigation. Fix: set to `nil` first, then `DispatchQueue.main.asyncAfter` set to the target value.

---

## Known Warnings (not bugs)

- `PHAssetResource.assetResources(for:)` triggers "Missing prefetched properties" warnings — happens when accessing file size metadata on main thread, does not affect functionality
- `Error Domain=com.apple.accounts Code=7` — simulator/Apple ID issue, not a code bug
- `FBSSceneSnapshotErrorDomain code 3` — iOS scene snapshot canceled during sheet animation, simulator only
- SourceKit cross-file resolution errors (e.g., "Cannot find type 'AppState' in scope") are IDE indexing issues, not build errors

---

## gstack
Use /browse from gstack for all web browsing. Never use mcp__claude-in-chrome__* tools.
Available skills: /office-hours, /plan-ceo-review, /plan-eng-review, /plan-design-review,
/design-consultation, /design-shotgun, /design-html, /review, /ship, /land-and-deploy,
/canary, /benchmark, /browse, /open-gstack-browser, /qa, /qa-only, /design-review,
/setup-browser-cookies, /setup-deploy, /setup-gbrain, /sync-gbrain, /retro, /investigate, /document-release,
/codex, /cso, /autoplan, /pair-agent, /careful, /freeze, /guard, /unfreeze, /gstack-upgrade, /learn.
