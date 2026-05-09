import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var storeKit = StoreKitManager()
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var purchaseError: String?

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
                    Text("Delete duplicates, similar photos, blurry shots and screenshots to free up space.")
                        .font(.appBodyRegular).foregroundStyle(Color.appTextSecondary)
                        .multilineTextAlignment(.center).padding(.horizontal, 32)
                }

                VStack(alignment: .leading, spacing: 12) {
                    BenefitRow(icon: "checkmark.circle.fill", text: "Unlimited scans and cleanup")
                    BenefitRow(icon: "checkmark.circle.fill", text: "All detection features unlocked")
                    BenefitRow(icon: "checkmark.circle.fill", text: "Smart AI-powered recommendations")
                    BenefitRow(icon: "checkmark.circle.fill", text: "Future updates included")
                }
                .padding(.horizontal, Layout.pageHorizontalPadding)

                VStack(spacing: 12) {
                    if let lifetime = storeKit.lifetimeProduct {
                        PricingCard(product: lifetime, badge: "Best Value", badgeColor: .appSuccess,
                                    isSelected: selectedProduct?.id == lifetime.id || selectedProduct == nil)
                        { selectedProduct = lifetime }
                    }
                    if let yearly = storeKit.yearlyProduct {
                        PricingCard(product: yearly, badge: nil, badgeColor: .clear,
                                    isSelected: selectedProduct?.id == yearly.id)
                        { selectedProduct = yearly }
                    }
                }
                .padding(.horizontal, Layout.pageHorizontalPadding)

                PrimaryButton(title: isPurchasing ? "Processing..." : "Continue",
                              isDisabled: isPurchasing || selectedProduct == nil && storeKit.lifetimeProduct == nil)
                { purchase() }
                .padding(.horizontal, Layout.pageHorizontalPadding)

                if let error = purchaseError {
                    Text(error).font(.appCaption).foregroundStyle(Color.appDanger)
                }

                HStack(spacing: 16) {
                    Button("Restore Purchase") { Task { await storeKit.restorePurchases() } }
                        .font(.appCaption).foregroundStyle(Color.appTextSecondary)
                }
                .padding(.bottom, 40)
            }
        }
        .background(Color.appBackground)
        .task {
            await storeKit.loadProducts()
            selectedProduct = storeKit.lifetimeProduct
        }
    }

    private func purchase() {
        guard let product = selectedProduct else { return }
        isPurchasing = true; purchaseError = nil
        Task {
            let success = await storeKit.purchase(product)
            isPurchasing = false
            if success { dismiss() }
            else { purchaseError = "Purchase was not completed. Please try again." }
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

private struct PricingCard: View {
    let product: Product; let badge: String?; let badgeColor: Color
    let isSelected: Bool; let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().stroke(isSelected ? Color.appPrimary : Color.appTextQuaternary, lineWidth: 2).frame(width: 24, height: 24)
                    if isSelected { Circle().fill(Color.appPrimary).frame(width: 14, height: 14) }
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(product.displayName).font(.appBody).foregroundStyle(Color.appTextPrimary)
                        if let badge {
                            Text(badge).font(.appMicro).foregroundStyle(.white)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Capsule().fill(badgeColor))
                        }
                    }
                    Text(product.description).font(.appCaption).foregroundStyle(Color.appTextSecondary)
                }
                Spacer()
                Text(product.displayPrice).font(.appPrice).foregroundStyle(Color.appPrimary)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .stroke(isSelected ? Color.appPrimary.opacity(0.3) : Color.appDivider.opacity(0.5),
                        lineWidth: isSelected ? 1.5 : 0.5)
                .fill(Color.appSurface))
            .appleCardShadow()
        }
        .buttonStyle(.plain)
    }
}
