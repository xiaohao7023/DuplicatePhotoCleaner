import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var storeKit = StoreKitManager()
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var showingRestoreSuccess = false
    @State private var showingPrivacy = false
    @State private var showingTerms = false

    /// Optional callback — fires after successful purchase (used by delete-triggered paywall)
    var onPurchaseSuccess: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.appTextTertiary).frame(width: 32, height: 32)
                            .background(Circle().fill(Color.appBackgroundTertiary))
                    }
                }
                .padding(.horizontal, Layout.pageHorizontalPadding).padding(.top, 16)

                VStack(spacing: 16) {
                    ZStack {
                        Circle().fill(Color.appPrimary.opacity(0.12)).frame(width: 88, height: 88)
                        Image(systemName: "sparkles").font(.system(size: 36, weight: .light)).foregroundStyle(Color.appPrimary)
                    }
                    Text("Unlock Full Cleanup").font(.appH1).foregroundStyle(Color.appTextPrimary)
                    Text("One-time purchase to permanently unlock all cleanup features.")
                        .font(.appBodyRegular).foregroundStyle(Color.appTextSecondary)
                        .multilineTextAlignment(.center).padding(.horizontal, 32)
                }

                VStack(alignment: .leading, spacing: 12) {
                    BenefitRow(icon: "checkmark.circle.fill", text: "One-time purchase, use forever")
                    BenefitRow(icon: "checkmark.circle.fill", text: "All detection features unlocked")
                    BenefitRow(icon: "checkmark.circle.fill", text: "Smart AI-powered recommendations")
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

                VStack(spacing: 12) {
                    Button("Restore Purchase") { restorePurchases() }
                        .font(.appCaption).foregroundStyle(Color.appTextSecondary)

                    HStack(spacing: 16) {
                        Button("Terms of Use") { showingTerms = true }
                        Text("·").foregroundStyle(Color.appTextQuaternary)
                        Button("Privacy Policy") { showingPrivacy = true }
                    }
                    .font(.appTiny).foregroundStyle(Color.appTextTertiary)
                }
                .padding(.bottom, 40)
            }
        }
        .background(Color.appBackground)
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
                onPurchaseSuccess?()
                dismiss()
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
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(Color.appSuccess)
            Text(text).font(.appBodyRegular).foregroundStyle(Color.appTextPrimary)
            Spacer()
        }
    }
}
