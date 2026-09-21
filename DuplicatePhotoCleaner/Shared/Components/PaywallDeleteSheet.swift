import SwiftUI
import StoreKit
import Combine

/// Unified paywall sheet — high-conversion design optimized for mobile
struct PaywallDeleteSheet: View {
    let selectedSizeBytes: Int64
    var showingUsage: Int64?
    var showingDeletedCount: Int = 0
    var totalCleanableBytes: Int64
    var onPurchaseSuccess: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var storeKit = StoreKitManager.shared
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var showingRestoreSuccess = false
    @State private var showingPrivacy = false
    @State private var showingTerms = false
    @State private var welcomeOfferRemainingSeconds = 0
    @State private var hasTrackedPaywallView = false

    private let welcomeOfferTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var formattedUsage: String? {
        guard let usage = showingUsage else { return nil }
        guard usage > 0 else { return showingDeletedCount > 0 ? "Size unavailable" : nil }
        return formatBytes(usage)
    }

    private var formattedRemainingQuota: String {
        formatBytes(appState.freeDeletesRemainingBytes)
    }

    private var welcomeOfferActive: Bool { welcomeOfferRemainingSeconds > 0 }

    private var welcomeOfferCountdown: String {
        let hours = welcomeOfferRemainingSeconds / 3600
        let minutes = (welcomeOfferRemainingSeconds % 3600) / 60
        let seconds = welcomeOfferRemainingSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private var totalCleanable: Int64 { appState.totalCleanableBytes }
    private var formattedCleanable: String? {
        totalCleanable > 0 ? formatBytes(totalCleanable) : nil
    }

    /// Calculate storage usage percentage
    private var storagePercent: Int {
        if let info = FileManager.default.getFilesystemInfo() {
            let percent = (info.used / info.total) * 100
            return min(99, max(1, Int(percent)))
        }
        return 92 // fallback
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top close button
            HStack {
                Spacer()
                Button("Maybe Later") {
                    appState.paywallDismissCount += 1
                    appState.deletesSincePaywallDismiss = 0
                    dismiss()
                }
                    .font(.system(size: 10, weight: .regular))
                    .tracking(1.2)
                    .foregroundStyle(Color(hex: "7C746A").opacity(0.6))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Color.black.opacity(0.05))
                    )
            }
            .padding(.top, 8)
            .padding(.horizontal, 20)

            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - Title & Urgency Badge
                    VStack(spacing: 12) {
                        // Urgency badge
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.appPrimary)
                            Text(String(format: "Storage warning: %d%% full", storagePercent))
                                .font(.system(size: 10, weight: .regular))
                                .tracking(0.8)
                                .foregroundStyle(Color.appPrimary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(Color(hex: "EAF3FF"))
                        )

                        // Main title
                        if let usage = formattedUsage {
                            Text(cleanupResultTitle(for: usage))
                                .font(.system(size: 26, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.appTextPrimary)
                                .multilineTextAlignment(.center)
                            Text("\(formattedRemainingQuota) of free cleanup remains")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.appTextSecondary)
                        } else if let cleanable = formattedCleanable {
                            Text("Free Up \(cleanable) Right Now")
                                .font(.system(size: 26, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color(hex: "2C2926"))
                                .multilineTextAlignment(.center)
                        } else {
                            Text("Unlock Full Cleanup")
                                .font(.system(size: 26, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color(hex: "2C2926"))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 8)

                    // MARK: - Premium Pricing Card (with corner ribbon)
                    PremiumPricingCard(
                        displayPrice: storeKit.lifetimeProduct?.displayPrice,
                        showsWelcomeOffer: welcomeOfferActive,
                        countdown: welcomeOfferCountdown
                    )
                        .padding(.horizontal, Layout.pageHorizontalPadding)

                    // MARK: - CTA Button (before benefits)
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
                        } else if storeKit.isLoading {
                            Button { } label: {
                                Text("Loading...")
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
                        } else {
                            Button { } label: {
                                Text("Unable to load products")
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

                        annualPriceAnchor
                    }
                    .padding(.horizontal, Layout.pageHorizontalPadding)
                    .padding(.top, 4)

                    // MARK: - Benefits Grid (2x2 layout)
                    BenefitsGrid()
                        .padding(.horizontal, Layout.pageHorizontalPadding)

                    // MARK: - Bottom Links
                    HStack(spacing: 12) {
                        Button("Restore Purchase") { restorePurchases() }
                            .foregroundStyle(Color.black)
                            .underline()
                        Text("•").foregroundStyle(Color.black)
                        Button("Terms of Use") { showingTerms = true }
                            .foregroundStyle(Color.black)
                            .underline()
                        Text("•").foregroundStyle(Color.black)
                        Button("Privacy Policy") { showingPrivacy = true }
                            .foregroundStyle(Color.black)
                            .underline()
                    }
                    .font(.system(size: 15, weight: .medium))
                    .padding(.top, 16)

                    if let error = purchaseError {
                        Text(error).font(.appCaption).foregroundStyle(Color.appDanger)
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .background(Color.appBackground)
        .presentationDetents([.large])
        .interactiveDismissDisabled(isPurchasing)
        .task {
            if !hasTrackedPaywallView {
                hasTrackedPaywallView = true
                await StudioAnalytics.shared.track(.paywallViewed, properties: [
                    "default_plan": "lifetime",
                    "source": paywallSource
                ])
            }
            configureWelcomeOffer()
            await storeKit.loadProducts()
        }
        .onReceive(welcomeOfferTimer) { now in
            updateWelcomeOfferRemaining(at: now)
        }
        .alert("Restore Successful", isPresented: $showingRestoreSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your purchase has been restored.")
        }
        .sheet(isPresented: $showingPrivacy) {
            LegalDocumentView(type: .privacyPolicy)
        }
        .sheet(isPresented: $showingTerms) {
            LegalDocumentView(type: .termsOfUse)
        }
    }

    // MARK: - Actions

    private var paywallSource: String {
        if showingUsage != nil { return "cleanup_result" }
        if selectedSizeBytes > 0 { return "quota_exceeded" }
        return "general"
    }

    @ViewBuilder
    private var annualPriceAnchor: some View {
        VStack(spacing: 3) {
            Button {
                if let yearly = storeKit.yearlyProduct {
                    purchase(yearly)
                } else {
                    Task { await storeKit.loadProducts() }
                }
            } label: {
                VStack(spacing: 5) {
                    HStack(spacing: 7) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 13, weight: .semibold))

                        Text(storeKit.yearlyProduct == nil && storeKit.isLoading
                             ? "Loading annual option…"
                             : "Or choose Annual")
                            .font(.system(size: 13, weight: .semibold))

                        Spacer(minLength: 4)

                        if !storeKit.isLoading {
                            Text("$14.99/year")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                    }

                    if !storeKit.isLoading {
                        Text("Renews every year • Cancel anytime")
                            .font(.system(size: 10, weight: .medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .opacity(0.68)
                    }
                }
                .foregroundStyle(Color.appPrimary.opacity(0.9))
                .padding(.horizontal, 15)
                .padding(.vertical, 11)
                .frame(minHeight: 54)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.appPrimary.opacity(0.075))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.appPrimary.opacity(0.22), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isPurchasing || storeKit.isLoading)
            .accessibilityLabel("Annual membership, purchased directly")

            if let error = storeKit.productLoadError, !storeKit.isLoading, storeKit.yearlyProduct == nil {
                Text("Annual option unavailable. Tap to retry.")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Color.appTextTertiary)
                    .accessibilityHint(error)
            }
        }
        .padding(.top, 2)
    }

    private func purchase(_ product: Product) {
        isPurchasing = true; purchaseError = nil
        Task {
            let success = await storeKit.purchase(product)
            isPurchasing = false
            if success {
                appState.purchasedProductIDs = storeKit.purchasedProductIDs
                onPurchaseSuccess?()
            } else {
                purchaseError = "Purchase was not completed. Please try again."
            }
        }
    }

    private func restorePurchases() {
        isPurchasing = true; purchaseError = nil
        Task {
            await storeKit.restorePurchases()
            isPurchasing = false
            appState.purchasedProductIDs = storeKit.purchasedProductIDs
            if appState.isPurchased {
                showingRestoreSuccess = true
            } else {
                purchaseError = "No previous purchases found."
            }
        }
    }

    private func formatBytes(_ b: Int64) -> String {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useGB, .useMB]
        f.countStyle = .file
        return f.string(fromByteCount: b)
    }

    private func cleanupResultTitle(for cleaned: String) -> LocalizedStringKey {
        if cleaned == "Size unavailable" {
            return "We Cleaned \(showingDeletedCount) photo for You"
        }
        return "We've Saved You \(cleaned)"
    }

    private func configureWelcomeOffer() {
        updateWelcomeOfferRemaining(at: Date())
    }

    private func updateWelcomeOfferRemaining(at date: Date) {
        welcomeOfferRemainingSeconds = max(0, Int(ceil(appState.welcomeOfferDeadline.timeIntervalSince(date))))
    }
}

// MARK: - Premium Pricing Card (with corner ribbon)

private struct PremiumPricingCard: View {
    let displayPrice: String?
    let showsWelcomeOffer: Bool
    let countdown: String

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main content
            VStack(spacing: 12) {
                if showsWelcomeOffer {
                    Text("NEW USER WELCOME")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.appPrimary))

                    VStack(spacing: 3) {
                        Text("Welcome window reserved for")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.appTextSecondary)
                        Text(countdown)
                            .font(.system(size: 25, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.appPrimary)
                            .contentTransition(.numericText())
                    }
                }

                // Price display
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(displayPrice ?? "—")
                        .font(.system(size: 46, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: "2C2926"))
                }

                // Subtitle
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(hex: "2C2926"))
                    Text("Lifetime Unlocked")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color(hex: "2C2926"))
                }

                Text("No subscription • Pay once, own forever")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(Color(hex: "7C746A"))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)

        }
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

// MARK: - Benefits Grid (2x2 layout)

private struct BenefitsGrid: View {
    var body: some View {
        VStack(spacing: 12) {
            // Section header
            HStack {
                Text("WHAT YOU'LL UNLOCK")
                    .font(.system(size: 10, weight: .regular))
                    .tracking(2)
                    .foregroundStyle(Color(hex: "7C746A"))

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Color.appPrimary)
                    Text("Lifetime Value")
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(Color.appPrimary)
                }
            }
            .padding(.bottom, 2)

            // 2x2 Grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                // Row 1
                BenefitCard(
                    icon: "photo.stack",
                    iconColor: Color.appPrimary,
                    iconBgColor: Color(hex: "FDF1EB"),
                    title: "Instant Dupes",
                    subtitle: "Wipe identical photos"
                )
                BenefitCard(
                    icon: "video.fill",
                    iconColor: Color(hex: "9E6E59"),
                    iconBgColor: Color(hex: "F6ECE6"),
                    title: "Video Purge",
                    subtitle: "Find heavy record files"
                )

                // Row 2
                BenefitCard(
                    icon: "clock.fill",
                    iconColor: Color.indigo,
                    iconBgColor: Color.indigo.opacity(0.1),
                    title: "Save Hours",
                    subtitle: "Zero manual sorting"
                )
                BenefitCard(
                    icon: "checkmark.circle.fill",
                    iconColor: Color(hex: "10B981"),
                    iconBgColor: Color(hex: "10B981").opacity(0.1),
                    title: "Unlimited",
                    subtitle: "Clean forever"
                )
            }

            // Full-width cards
            VStack(spacing: 10) {
                // Smart AI - highlight card
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "FAF0EB"))
                            .frame(width: 36, height: 36)
                        Image(systemName: "sparkles")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.appPrimary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("Smart AI Selection")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(Color(hex: "2C2926"))

                            Text("POPULAR")
                                .font(.system(size: 7, weight: .medium))
                                .tracking(0.5)
                                .foregroundStyle(Color.appPrimary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(Color(hex: "FAF0EB"))
                                )
                        }

                        Text("Automatically picks the sharpest shot for you")
                            .font(.system(size: 9, weight: .regular))
                            .foregroundStyle(Color(hex: "7C746A"))
                    }

                    Spacer()
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color(hex: "EAE3D5"), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.02), radius: 12, x: 0, y: 4)

                // Future Updates card
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.blue)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Future Updates Included")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(Color(hex: "2C2926"))

                        Text("Wiping engine advances, smart filters and upgrades are 100% free")
                            .font(.system(size: 9, weight: .regular))
                            .foregroundStyle(Color(hex: "7C746A"))
                    }

                    Spacer()
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color(hex: "EAE3D5"), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.02), radius: 12, x: 0, y: 4)
            }
        }
    }
}

private struct BenefitCard: View {
    let icon: String
    let iconColor: Color
    let iconBgColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(iconBgColor)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(iconColor)
            }

            Text(title)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Color(hex: "2C2926"))

            Text(subtitle)
                .font(.system(size: 8.5, weight: .regular))
                .foregroundStyle(Color(hex: "7C746A"))
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(hex: "EAE3D5"), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.02), radius: 12, x: 0, y: 4)
    }
}
