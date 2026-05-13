import SwiftUI
import StoreKit

/// Paywall sheet shown when a free user tries to delete.
/// Dynamic title/subtitle based on selection, auto-executes delete on purchase success.
struct PaywallDeleteSheet: View {
    let selectedSizeBytes: Int64
    let selectedCount: Int
    let contentType: String // "photos", "videos", "duplicates"
    var onPurchaseSuccess: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var storeKit = StoreKitManager()
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var showingRestoreSuccess = false
    @State private var showingPrivacy = false
    @State private var showingTerms = false

    private var formattedSize: String {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useGB, .useMB]
        f.countStyle = .file
        return f.string(fromByteCount: selectedSizeBytes)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 8)

                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.appPrimary.opacity(0.12))
                                .frame(width: 72, height: 72)
                            Image(systemName: "sparkles")
                                .font(.system(size: 30, weight: .light))
                                .foregroundStyle(Color.appPrimary)
                        }

                        Text("Ready to free up \(formattedSize)?")
                            .font(.appH2)
                            .foregroundStyle(Color.appTextPrimary)
                            .multilineTextAlignment(.center)

                        Text("\(selectedCount) \(contentType) selected")
                            .font(.appBodyRegular)
                            .foregroundStyle(Color.appTextSecondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        BenefitRow(icon: "checkmark.circle.fill", text: "One-time purchase, forever")
                        BenefitRow(icon: "checkmark.circle.fill", text: "All detection features")
                        BenefitRow(icon: "checkmark.circle.fill", text: "Smart AI recommendations")
                        BenefitRow(icon: "checkmark.circle.fill", text: "Future updates included")
                    }
                    .padding(.horizontal, Layout.pageHorizontalPadding)

                    if let product = storeKit.lifetimeProduct {
                        PrimaryButton(
                            title: isPurchasing ? "Processing..." : "Unlock Lifetime — \(product.displayPrice)",
                            isDisabled: isPurchasing
                        ) { purchase(product) }
                        .padding(.horizontal, Layout.pageHorizontalPadding)
                    } else if storeKit.isLoading {
                        PrimaryButton(title: "Loading...", isDisabled: true) {}
                            .padding(.horizontal, Layout.pageHorizontalPadding)
                    } else {
                        PrimaryButton(title: "Unable to load products", isDisabled: true) {}
                            .padding(.horizontal, Layout.pageHorizontalPadding)
                    }

                    if let error = purchaseError {
                        Text(error).font(.appCaption).foregroundStyle(Color.appDanger)
                    }
                }
            }

            // Bottom links
            VStack(spacing: 10) {
                Button("Maybe Later") { dismiss() }
                    .font(.appBody)
                    .foregroundStyle(Color.appTextSecondary)

                HStack(spacing: 16) {
                    Button("Restore Purchase") { restorePurchases() }
                        .font(.appCaption).foregroundStyle(Color.appTextSecondary)

                    HStack(spacing: 12) {
                        Button("Terms of Use") { showingTerms = true }
                        Text("·").foregroundStyle(Color.appTextQuaternary)
                        Button("Privacy Policy") { showingPrivacy = true }
                    }
                    .font(.appTiny).foregroundStyle(Color.appTextTertiary)
                }
            }
            .padding(.bottom, 40)
            .padding(.top, 16)
        }
        .background(Color.appBackground)
        .presentationDetents([.fraction(0.75)])
        .interactiveDismissDisabled(isPurchasing)
        .task {
            await storeKit.loadProducts()
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

    private func purchase(_ product: Product) {
        isPurchasing = true; purchaseError = nil
        Task {
            let success = await storeKit.purchase(product)
            isPurchasing = false
            if success {
                appState.purchasedProductIDs = storeKit.purchasedProductIDs
                onPurchaseSuccess()
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
}

private struct BenefitRow: View {
    let icon: String; let text: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color.appSuccess)
            Text(text)
                .font(.appBodyRegular)
                .foregroundStyle(Color.appTextPrimary)
            Spacer()
        }
    }
}
