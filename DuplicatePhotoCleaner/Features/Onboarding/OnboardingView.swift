import SwiftUI
import Photos
import StoreKit

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var page = 0
    @State private var stage: OnboardingStage = .introduction
    @State private var permissionManager = PhotoPermissionManager()
    @State private var showPermissionAlert = false

    private let pageCount = 3

    var body: some View {
        Group {
            switch stage {
            case .introduction:
                introductionView
            case .scanning:
                OnboardingScanView()
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .onAppear {
            // 老用户：跳过介绍，直接进首页（扫描+付费页）
            if appState.hasCompletedOnboarding && stage == .introduction {
                stage = .scanning
            }
        }
        .alert("Photo Access Required", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Not Now", role: .cancel) { appState.hasCompletedOnboarding = true }
        } message: {
            Text("Allow photo access to scan your library and estimate how much space can be cleaned.")
        }
    }

    // MARK: - Introduction (3 pages)

    private var introductionView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Dupes")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appTextPrimary)
                Spacer()
                Text("\(page + 1) / \(pageCount)")
                    .font(.appCaptionMedium)
                    .foregroundStyle(Color.appTextTertiary)
            }
            .padding(.top, 18)

            TabView(selection: $page) {
                introPage(.welcome).tag(0)
                introPage(.found).tag(1)
                introPage(.aiClean).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 7) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? Color.appPrimary : Color.appTextTertiary.opacity(0.2))
                        .frame(width: index == page ? 24 : 7, height: 7)
                        .animation(.easeOut(duration: 0.2), value: page)
                }
            }
            .padding(.bottom, 24)

            PrimaryButton(
                title: page == pageCount - 1 ? "Allow Photo Access" : "Continue",
                icon: page == pageCount - 1 ? "photo.on.rectangle" : "arrow.right"
            ) {
                HapticManager.selection()
                if page == pageCount - 1 {
                    requestAccessAndScan()
                } else {
                    withAnimation(.easeOut(duration: 0.25)) { page += 1 }
                }
            }

            Text(page == pageCount - 1
                 ? "Dupes only requests access to analyze and clean the photos you choose."
                 : "Your library is analyzed privately on this device.")
                .font(.appMicro)
                .foregroundStyle(Color.appTextTertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
        }
        .padding(.horizontal, Layout.pageHorizontalPadding)
        .padding(.bottom, 34)
    }

    private enum IntroPageKind { case welcome, found, aiClean }

    @ViewBuilder
    private func introPage(_ kind: IntroPageKind) -> some View {
        VStack(spacing: 0) {
            Spacer()
            illustration(for: kind)
            Spacer().frame(height: 44)
            pageCopy(for: kind)
            Spacer()
        }
    }

    @ViewBuilder
    private func pageCopy(for kind: IntroPageKind) -> some View {
        switch kind {
        case .welcome:
            copyBlock(eyebrow: "MEET DUPES", accent: .appPrimary,
                      title: "Keep the photos you love.",
                      message: "Duplicates, similar shots, blurry bursts and forgotten videos quietly eat your storage. Dupes finds them all in one scan.")
        case .found:
            copyBlock(eyebrow: "ONE SMART SCAN", accent: .appTeal,
                      title: "See everything cluttering your iPhone.",
                      message: "Your library is organized into simple categories with real numbers, so you always know exactly what is worth removing.")
        case .aiClean:
            copyBlock(eyebrow: "AI DOES THE WORK", accent: .appPrimary,
                      title: "Delete the clutter, keep the best.",
                      message: "AI picks the best shot and flags the rest for you. Nothing is ever removed without your review and confirmation.")
        }
    }

    private func copyBlock(eyebrow: String, accent: Color, title: String, message: String) -> some View {
        VStack(spacing: 0) {
            Text(verbatim: eyebrow)
                .font(.system(size: 11, weight: .semibold)).tracking(2)
                .foregroundStyle(accent)
            Text(LocalizedStringKey(title))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appTextPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
            Text(LocalizedStringKey(message))
                .font(.appBody)
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 16)
                .padding(.horizontal, 8)
        }
    }

    // MARK: Illustrations (mock-UI style, no plain icon circles)

    @ViewBuilder
    private func illustration(for kind: IntroPageKind) -> some View {
        switch kind {
        case .welcome: welcomeIllustration
        case .found: foundIllustration
        case .aiClean: aiCleanIllustration
        }
    }

    /// Page 1 — storage snapshot card with reclaimable headline and category chips.
    private var welcomeIllustration: some View {
        ZStack(alignment: .bottom) {
            Image("OnboardingWelcomeArtwork")
                .resizable()
                .scaledToFit()
                .frame(width: 252, height: 190)
                .offset(y: -48)
                .accessibilityHidden(true)

            VStack(spacing: 14) {
                VStack(spacing: 10) {
                    Text(verbatim: "RECLAIMABLE SPACE")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(Color.appTextTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(verbatim: "12.8 GB")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.appBackgroundTertiary)
                            Capsule()
                                .fill(Color.appPrimaryGradient)
                                .frame(width: proxy.size.width * 0.62)
                        }
                    }
                    .frame(height: 8)
                }
                .padding(15)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.appDividerLight, lineWidth: 1))
                .shadow(color: Color.appPrimary.opacity(0.08), radius: 22, x: 0, y: 10)

                HStack(spacing: 7) {
                    chip("DUPES", count: "128", color: .appPrimary)
                    chip("SIMILAR", count: "96", color: .appTeal)
                    chip("SCREENSHOTS", count: "240", color: Color.indigo)
                }
            }
            .padding(.horizontal, 16)
            .offset(y: 48)
        }
        .frame(height: 284)
    }

    private func chip(_ label: String, count: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Text(verbatim: count)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(verbatim: label)
                .font(.system(size: 8.5, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Color.appTextTertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color.white))
        .overlay(Capsule().strokeBorder(Color.appDividerLight, lineWidth: 1))
        .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 3)
    }

    /// Page 2 — 2x2 category tiles, mirroring the dashboard's scan categories.
    private var foundIllustration: some View {
        ZStack {
            Image("OnboardingScanArtwork")
                .resizable()
                .scaledToFit()
                .frame(width: 270, height: 270)
                .accessibilityHidden(true)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 11),
                GridItem(.flexible(), spacing: 11)
            ], spacing: 11) {
                foundTile(icon: "photo.stack.fill", title: "Duplicates", count: "128", color: .appPrimary)
                foundTile(icon: "square.on.square", title: "Similar", count: "96", color: .appTeal)
                foundTile(icon: "camera.viewfinder", title: "Screenshots", count: "240", color: Color.indigo)
                foundTile(icon: "video.fill", title: "Videos", count: "23", color: Color(hex: "9E6E59"))
            }
            .padding(.horizontal, 27)
            .padding(.vertical, 8)
        }
        .frame(height: 270)
    }

    private func foundTile(icon: String, title: String, count: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(color.opacity(0.1)))
            Text(verbatim: count)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appTextPrimary)
            Text(verbatim: title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(RoundedRectangle(cornerRadius: 17, style: .continuous).fill(Color.white.opacity(0.84)))
        .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).strokeBorder(Color.white.opacity(0.95), lineWidth: 1))
        .shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 4)
    }

    /// Page 3 — AI picks the best shot, flags the rest for review.
    private var aiCleanIllustration: some View {
        ZStack {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.appPrimaryGradient))
                    Text(verbatim: "AI CLEANUP")
                        .font(.system(size: 9.5, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(Color.appPrimaryLight)
                    Spacer()
                    Text(verbatim: "3 of 4 kept")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.65))
                }

                ZStack(alignment: .bottom) {
                    Image("OnboardingAISelectionArtwork")
                        .resizable()
                        .scaledToFill()
                        .frame(height: 146)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                colors: [.clear, Color.black.opacity(0.42)],
                                startPoint: .center,
                                endPoint: .bottom
                            )
                        )

                    HStack(spacing: 7) {
                        reviewBadge(title: "KEEP", subtitle: "Best shot", color: Color.appSuccess)
                        reviewBadge(title: "REMOVE", subtitle: "Similar", color: Color.appDanger)
                    }
                    .padding(9)
                }
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

                HStack(spacing: 6) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Color(hex: "8ED7D0"))
                    Text(verbatim: "You confirm every deletion")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.78))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.10)))
            }
            .padding(15)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(hex: "0B213B")))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.appPrimary.opacity(0.28), lineWidth: 1))
            .shadow(color: Color.appPrimary.opacity(0.18), radius: 22, x: 0, y: 10)
            .padding(.horizontal, 20)
        }
    }

    private func reviewBadge(title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: title == "KEEP" ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: title)
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.7)
                Text(verbatim: subtitle)
                    .font(.system(size: 8.5, weight: .medium))
                    .opacity(0.78)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.48), in: Capsule())
    }

    // MARK: - Permission

    private func requestAccessAndScan() {
        Task {
            let status = await permissionManager.requestPermission()
            if status == .authorized || status == .limited {
                withAnimation(.easeInOut(duration: 0.3)) { stage = .scanning }
            } else {
                showPermissionAlert = true
            }
        }
    }
}

private enum OnboardingStage { case introduction, scanning }

// MARK: - Scan + Lifetime Paywall (final step)

private struct OnboardingScanView: View {
    @Environment(AppState.self) private var appState
    @State private var orchestrator = ScanOrchestrator()
    @State private var scanData = ScanResultData()
    @State private var dupState = CategoryScanState()
    @State private var simState = CategoryScanState()
    @State private var ssState = CategoryScanState()
    @State private var vidState = CategoryScanState()
    @State private var blurState = CategoryScanState()
    @State private var unfavState = CategoryScanState()
    @State private var activeCategory: ScanCategory = .screenshots
    @State private var hasStarted = false
    @State private var isScanComplete = false
    @State private var storeKit = StoreKitManager.shared
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var showingPrivacy = false
    @State private var showingTerms = false
    @State private var hasTrackedPaywallView = false

    // Home navigation（扫完原地变首页，四张卡直连分类页）
    @State private var showingSettings = false
    @State private var showDuplicates = false
    @State private var showSimilar = false
    @State private var showScreenshots = false
    @State private var showVideos = false

    private let categories: [ScanCategory] = [.screenshots, .videos, .unfavorites, .duplicates, .similar, .blurry]

    var body: some View {
        NavigationStack {
            homeContent
                .navigationDestination(isPresented: $showDuplicates) {
                    DuplicateGroupsView(groups: scanData.duplicateGroups) { updated in
                        withAnimation { scanData.duplicateGroups = updated }
                        dupState.update(fromDuplicateGroups: updated)
                        appState.totalCleanableBytes = totalCleanableBytes
                        appState.totalCleanableCount = totalCleanableCount
                    }
                }
                .navigationDestination(isPresented: $showSimilar) {
                    SimilarGroupsView(groups: scanData.similarGroups) { updated in
                        withAnimation { scanData.similarGroups = updated }
                        simState.update(fromSimilarGroups: updated)
                        appState.totalCleanableBytes = totalCleanableBytes
                        appState.totalCleanableCount = totalCleanableCount
                    }
                }
                .navigationDestination(isPresented: $showScreenshots) {
                    ScreenshotsView(groups: scanData.screenshotGroups) { updated in
                        withAnimation { scanData.screenshotGroups = updated }
                        ssState.update(fromScreenshotGroups: updated)
                        appState.totalCleanableBytes = totalCleanableBytes
                        appState.totalCleanableCount = totalCleanableCount
                    }
                }
                .navigationDestination(isPresented: $showVideos) {
                    VideosView(videos: scanData.videos) { updated in
                        scanData.videos = updated
                        vidState.update(fromVideos: updated)
                        appState.totalCleanableBytes = totalCleanableBytes
                        appState.totalCleanableCount = totalCleanableCount
                    }
                }
                .sheet(isPresented: $showingSettings) {
                    NavigationStack { SettingsView() }
                }
        }
    }

    private var homeContent: some View {
        VStack(spacing: 0) {
            if !isScanComplete {
                VStack(spacing: 7) {
                    Text("Analyzing Your Storage")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appTextPrimary)
                    Text("Results appear as soon as we find them")
                        .font(.appCaption)
                        .foregroundStyle(Color.appTextSecondary)
                }
                .padding(.top, 20)
                .padding(.bottom, 18)
            }

            ScrollView {
                VStack(spacing: 20) {
                    if isScanComplete {
                        paywallContent
                            .transition(.opacity)
                    } else {
                        cleanupGauge
                        scanActivity
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, Layout.pageHorizontalPadding)
                .padding(.bottom, 16)
            }

            if !isScanComplete {
                VStack(spacing: 10) {
                    ProgressView(value: overallProgress)
                        .tint(Color.appPrimary)
                    HStack {
                        Text(scanStatusText)
                        Spacer()
                        Text(String(format: "%.0f%%", overallProgress * 100))
                            .monospacedDigit()
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.appTextSecondary)
                }
                .padding(.horizontal, Layout.pageHorizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, 18)
            }
        }
        .task { await startScanIfNeeded() }
        .task { await storeKit.loadProducts() }
        .onChange(of: isScanComplete) { _, complete in
            guard complete, !hasTrackedPaywallView else { return }
            hasTrackedPaywallView = true
            Task {
                await StudioAnalytics.shared.track(.paywallViewed, properties: [
                    "default_plan": "lifetime",
                    "source": "onboarding_scan"
                ])
            }
        }
        .overlay(alignment: .topTrailing) {
            if !isScanComplete {
                Button {
                    Task { await completeOnboarding(entry: "scan_close") }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.appTextSecondary)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.appBackgroundSecondary))
                }
                .padding(.top, 12)
                .padding(.trailing, Layout.pageHorizontalPadding)
            } else {
                Button { showingSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.appTextPrimary)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color.white))
                        .overlay(Circle().strokeBorder(Color.appDividerLight, lineWidth: 1))
                }
                .padding(.top, 12)
                .padding(.trailing, Layout.pageHorizontalPadding)
            }
        }
        .sheet(isPresented: $showingPrivacy) { LegalDocumentView(type: .privacyPolicy) }
        .sheet(isPresented: $showingTerms) { LegalDocumentView(type: .termsOfUse) }
    }

    // MARK: Final step — scan result + lifetime paywall

    @ViewBuilder
    private var paywallContent: some View {
        VStack(spacing: 18) {
            // 1. Scan result snapshot — cleanable photo content on top
            storageSnapshot

            // 2. Lifetime pricing card + CTA
            if !appState.isPurchased {
                onboardingPricingCard

                VStack(spacing: 8) {
                if let product = storeKit.lifetimeProduct {
                    Button {
                        purchase(product)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14))
                            Text(isPurchasing ? "Processing..." : "Buy Once, Clean Forever")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.appPrimary)
                        )
                        .shadow(color: Color.appPrimary.opacity(0.25), radius: 18, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(isPurchasing)
                } else {
                    Button { } label: {
                        Text(storeKit.isLoading ? "Loading..." : "Unable to load products")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.gray)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(true)
                }

                HStack(spacing: 5) {
                    Image(systemName: "checkmark.shield.fill")
                    Text("One purchase • Lifetime access • No subscription")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.appTextSecondary)

                if let purchaseError {
                    Text(purchaseError)
                        .font(.appMicro)
                        .foregroundStyle(Color.appDanger)
                }
            }
            } // end if !isPurchased

            // 3. Compact benefits row
            benefitsRow

            // 4. Legal links — scroll with content, no floating bar
            HStack(spacing: 14) {
                Button("Restore") { restorePurchases() }
                Button("Terms") { showingTerms = true }
                Button("Privacy") { showingPrivacy = true }
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.appTextSecondary)
            .padding(.top, 4)
        }
        .padding(.top, 12)
    }

    private var onboardingPricingCard: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = Int(appState.welcomeOfferDeadline.timeIntervalSince(context.date))
            let showOffer = remaining > 0
            return VStack(spacing: 12) {
                if showOffer {
                    Text("NEW USER WELCOME")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.appPrimary))

                    HStack(spacing: 5) {
                        Text("Welcome window reserved for")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.appTextSecondary)
                        Text(verbatim: countdownText(remaining))
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.appPrimary)
                            .contentTransition(.numericText())
                    }
                }

                Text(storeKit.lifetimeProduct?.displayPrice ?? "—")
                    .font(.system(size: 46, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(hex: "2C2926"))

                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                    Text("Lifetime Unlocked")
                        .font(.system(size: 12, weight: .regular))
                }
                .foregroundStyle(Color(hex: "2C2926"))

                Text("No subscription • Pay once, own forever")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(Color(hex: "7C746A"))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color(hex: "EAE3D5"), lineWidth: 1)
            )
            .shadow(color: Color.appPrimary.opacity(0.1), radius: 36, x: 0, y: 12)
        }
    }

    private func countdownText(_ seconds: Int) -> String {
        String(format: "%02d:%02d", (seconds / 60), seconds % 60)
    }

    private var benefitsRow: some View {
        HStack(spacing: 9) {
            benefitChip(icon: "photo.stack", title: "Instant Dupes", subtitle: "Wipe identical photos", color: .appPrimary)
            benefitChip(icon: "video.fill", title: "Video Purge", subtitle: "Find heavy files", color: Color(hex: "9E6E59"))
            benefitChip(icon: "clock.fill", title: "Save Hours", subtitle: "Zero manual sorting", color: Color.indigo)
        }
    }

    private func benefitChip(icon: String, title: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
            Text(verbatim: title)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Color.appTextPrimary)
            Text(verbatim: subtitle)
                .font(.system(size: 9, weight: .regular))
                .foregroundStyle(Color.appTextTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(Color.appDividerLight, lineWidth: 1))
    }

    // MARK: - Scan result snapshot

    private var storageSnapshot: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("SPACE YOU COULD RECLAIM")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(Color.appTextSecondary)
                Text(formatBytes(totalCleanableBytes))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appPrimary)
                    .contentTransition(.numericText())
                Text("A quick snapshot of your photo library")
                    .font(.appCaption)
                    .foregroundStyle(Color.appTextSecondary)
            }

            GeometryReader { proxy in
                HStack(spacing: 3) {
                    Capsule()
                        .fill(Color.appPrimaryGradient)
                        .frame(width: max(8, proxy.size.width * photoShare))
                    Capsule()
                        .fill(ScanCategory.videos.color)
                }
            }
            .frame(height: 12)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                snapshotCard(title: "Duplicates", bytes: dupState.sizeBytes, count: dupState.count, icon: "square.on.square", color: Color.appPrimary) {
                    showDuplicates = true
                }
                snapshotCard(title: "Similar", bytes: simState.sizeBytes, count: simState.count, icon: "photo.stack", color: Color(hex: "9E6E59")) {
                    showSimilar = true
                }
                snapshotCard(title: "Screenshots", bytes: ssState.sizeBytes, count: ssState.count, icon: "camera.viewfinder", color: Color.indigo) {
                    showScreenshots = true
                }
                snapshotCard(title: "Videos", bytes: vidState.sizeBytes, count: vidState.count, icon: "video.fill", color: Color(hex: "9E6E59")) {
                    showVideos = true
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.appDividerLight, lineWidth: 1)
        )
    }

    /// 可点击的分类入口卡：图标 + 数量 + 可清理空间
    private func snapshotCard(
        title: String,
        bytes: Int64,
        count: Int,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(color)
                    Text(LocalizedStringKey(title))
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Color.appTextSecondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.appTextTertiary)
                }
                Text(isScanComplete && count > 0 ? "\(count)" : "—")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appTextPrimary)
                Text(count > 0 ? formatBytes(bytes) : "Nothing found")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Color.appTextTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(13)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(color.opacity(0.07))
            )
        }
        .buttonStyle(.plain)
    }


    // MARK: - Scanning UI

    private var scanActivity: some View {
        HStack(spacing: 12) {
            Image(systemName: activeCategory.icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(activeCategory.color)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(activeCategory.color.opacity(0.1))
                )
            VStack(alignment: .leading, spacing: 4) {
                Text("Scanning \(activeCategory.displayName)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.appTextPrimary)
                Text("Building your private storage overview…")
                    .font(.appMicro)
                    .foregroundStyle(Color.appTextSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
        )
    }

    private var cleanupGauge: some View {
        ZStack {
            Circle()
                .stroke(Color.appBackgroundTertiary, lineWidth: 14)
            Circle()
                .trim(from: 0, to: max(0.015, overallProgress))
                .stroke(Color.appPrimaryGradient, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.45), value: overallProgress)

            VStack(spacing: 5) {
                Text("FOUND SO FAR")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Color.appTextSecondary)
                Text(formatBytes(totalCleanableBytes))
                    .font(.system(size: 31, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appPrimary)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4, dampingFraction: 0.82), value: totalCleanableBytes)
                Text("\(totalCleanableCount) items")
                    .font(.appMicro)
                    .foregroundStyle(Color.appTextTertiary)
                    .contentTransition(.numericText())
            }
        }
        // The stroke is centered on the circle path. Keep it inside a larger
        // layout box so the ScrollView cannot crop the rounded cap at the top.
        .padding(8)
        .frame(width: 192, height: 192)
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var overallProgress: Double {
        categories.reduce(0) { result, category in
            let state = state(for: category)
            return result + (state.isDone ? 1 : state.progress)
        } / Double(categories.count)
    }

    private var totalCleanableBytes: Int64 {
        categories.reduce(0) { $0 + state(for: $1).sizeBytes }
    }

    private var totalCleanableCount: Int {
        categories.reduce(0) { $0 + state(for: $1).count }
    }

    private var videoShare: Double {
        guard totalCleanableBytes > 0 else { return 0 }
        return Double(vidState.sizeBytes) / Double(totalCleanableBytes)
    }

    private var photoShare: Double { 1 - videoShare }

    private var scanStatusText: String {
        state(for: activeCategory).isDone ? String(localized: "Preparing your results…") : String(localized: "Scanning \(activeCategory.displayName)…")
    }

    private func state(for category: ScanCategory) -> CategoryScanState {
        switch category {
        case .screenshots: return ssState
        case .videos: return vidState
        case .duplicates: return dupState
        case .similar: return simState
        case .blurry: return blurState
        case .unfavorites: return unfavState
        }
    }

    private func startScanIfNeeded() async {
        guard !hasStarted else { return }
        hasStarted = true

        for category in categories {
            withAnimation(.easeInOut(duration: 0.25)) { activeCategory = category }
            switch category {
            case .screenshots:
                scanData.screenshotGroups = await orchestrator.scanScreenshots(state: ssState)
            case .videos:
                scanData.videos = await orchestrator.scanVideos(state: vidState)
            case .duplicates:
                scanData.duplicateGroups = await orchestrator.scanDuplicates(state: dupState)
            case .similar:
                scanData.similarGroups = await orchestrator.scanSimilar(state: simState, fastFirstPass: true)
            case .blurry:
                scanData.blurryPhotos = await orchestrator.scanBlurry(state: blurState, fastFirstPass: true)
            case .unfavorites:
                scanData.unfavoritedPhotos = await orchestrator.scanUnfavorites(state: unfavState)
            }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) { }
        }

        appState.preloadedScanData = scanData
        appState.totalCleanableBytes = totalCleanableBytes
        appState.totalCleanableCount = totalCleanableCount
        appState.hasCompletedSuccessfulScan = true
        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
            isScanComplete = true
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "0 MB" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    // MARK: - Purchase (lifetime first)

    private func purchase(_ product: Product) {
        HapticManager.selection()
        isPurchasing = true
        purchaseError = nil
        Task {
            let success = await storeKit.purchase(product)
            isPurchasing = false
            if success {
                appState.purchasedProductIDs = storeKit.purchasedProductIDs
                await completeOnboarding(entry: "first_launch_purchase")
            } else {
                purchaseError = "The purchase was not completed. Please try again."
            }
        }
    }

    private func restorePurchases() {
        Task {
            await storeKit.restorePurchases()
            appState.purchasedProductIDs = storeKit.purchasedProductIDs
            if appState.isPurchased {
                await completeOnboarding(entry: "first_launch_restore")
            }
        }
    }

    private func completeOnboarding(entry: String) async {
        await StudioAnalytics.shared.track(.onboardingCompleted, properties: ["entry": entry])
        // 原地变首页：只置位标记，不切换页面
        appState.hasCompletedOnboarding = true
    }
}
