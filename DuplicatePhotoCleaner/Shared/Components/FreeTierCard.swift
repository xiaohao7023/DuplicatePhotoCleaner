import SwiftUI

// MARK: - FreeTierCard

/// 顶部卡片 — 精致设计版本（免费用户：显示免费额度；付费用户：显示设备存储）
struct FreeTierCard: View {
    var onUpgrade: (() -> Void)?
    @Environment(AppState.self) private var appState
    @State private var storageInfo: (used: Double, total: Double) = (0, 0)

    var body: some View {
        VStack(spacing: 16) {
            if appState.isPurchased {
                proUserContent
            } else {
                freeUserContent
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color(hex: "F1EAE0"), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.02), radius: 30, x: 0, y: 8)
        .onAppear {
            loadStorageInfo()
        }
    }

    // MARK: - 付费用户内容
    private var proUserContent: some View {
        VStack(spacing: 16) {
            // 标题行
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.appSuccess)

                    Text("LIFETIME")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.appSuccess)
                        .tracking(0.8)
                }

                Spacer()

                Text("Storage: \(formatBytes(Int64(totalGB * 1024 * 1024 * 1024)))")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color(hex: "7C746A").opacity(0.8))
            }

            // 细长进度条 + 圆点指示器
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(hex: "FAF4ED"))
                        .frame(height: 6)

                    Capsule()
                        .fill(storageUsagePercentage > 0.9 ? Color.appDanger : Color.appSuccess)
                        .frame(width: geo.size.width * storageUsagePercentage, height: 6)

                    Circle()
                        .fill(storageUsagePercentage > 0.9 ? Color.appDanger : Color.appSuccess)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                        .shadow(color: .black.opacity(0.1), radius: 2)
                        .offset(x: geo.size.width * storageUsagePercentage - 6)
                }
            }
            .frame(height: 12)

            // 底部：已清理 + 会员状态
            HStack {
                HStack(spacing: 4) {
                    Text("Total cleaned:")
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundStyle(Color(hex: "726B63"))

                    Text(formatBytes(appState.cumulativeFreedBytes))
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.appSuccess)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 10))
                    Text("Active")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(Color.appSuccess)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(Color.appSuccess.opacity(0.1))
                )
            }
        }
    }

    // MARK: - 免费用户内容
    private var freeUserContent: some View {
        VStack(spacing: 16) {
            // 标题行
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.appPrimary)

                    Text("FREE TIER")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.appPrimary)
                        .tracking(0.8)
                }

                Spacer()

                Text("Free limit: \(formatBytes(AppState.freeTierTotalQuota))")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color(hex: "7C746A").opacity(0.8))
            }

            // 细长进度条 + 圆点指示器
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(hex: "FAF4ED"))
                        .frame(height: 6)

                    Capsule()
                        .fill(appState.freeQuotaProgress > 0.8 ? Color.appDanger : Color.appPrimary)
                        .frame(width: geo.size.width * appState.freeQuotaProgress, height: 6)

                    Circle()
                        .fill(appState.freeQuotaProgress > 0.8 ? Color.appDanger : Color.appPrimary)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                        .shadow(color: .black.opacity(0.1), radius: 2)
                        .offset(x: geo.size.width * appState.freeQuotaProgress - 6)
                }
            }
            .frame(height: 12)

            // 底部：已清理 + 升级按钮（额度预警时修改文案）
            HStack {
                HStack(spacing: 4) {
                    Text("Total cleaned:")
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundStyle(Color(hex: "726B63"))

                    Text(formatBytes(appState.cumulativeFreedBytes))
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.appSuccess)
                }

                Spacer()

                Button(action: { onUpgrade?() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 10))
                        Text(LocalizedStringKey(upgradeButtonTitle))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(upgradeButtonColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(upgradeButtonBg)
                    )
                }
                .buttonStyle(.plain)
            }

            // 免费额度预警文字
            if appState.freeQuotaProgress > 0.8 {
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                    Text(appState.freeQuotaProgress > 0.95
                         ? "You've almost used up your free limit. Upgrade to keep cleaning."
                         : String(format: "You've used %d%% of your free limit.", Int(appState.freeQuotaProgress * 100)))
                        .font(.system(size: 10.5, weight: .medium))
                }
                .foregroundStyle(Color.appDanger)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - 额度预警辅助属性
    private var upgradeButtonTitle: String {
        if appState.freeQuotaProgress > 0.95 { return "Limit Reached → Upgrade" }
        if appState.freeQuotaProgress > 0.8 { return "Almost Full → Upgrade" }
        return "Upgrade"
    }

    private var upgradeButtonColor: Color {
        appState.freeQuotaProgress > 0.8 ? .white : Color.appPrimary
    }

    private var upgradeButtonBg: Color {
        appState.freeQuotaProgress > 0.8 ? Color.appDanger : Color(hex: "FAF2EE")
    }

    // MARK: - Helper

    private var storageUsagePercentage: Double {
        guard totalGB > 0 else { return 0 }
        return usedGB / totalGB
    }

    private func loadStorageInfo() {
        if let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let totalSize = attributes[.systemSize] as? Int64,
           let freeSize = attributes[.systemFreeSize] as? Int64 {
            let totalGBValue = Double(totalSize) / (1024 * 1024 * 1024)
            let freeGBValue = Double(freeSize) / (1024 * 1024 * 1024)
            storageInfo = (used: totalGBValue - freeGBValue, total: totalGBValue)
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useGB, .useMB]
        f.countStyle = .file
        return f.string(fromByteCount: bytes)
    }

    private var usedGB: Double { storageInfo.used }
    private var totalGB: Double { storageInfo.total }
}

// MARK: - Preview

#if DEBUG
struct FreeTierCard_Previews: PreviewProvider {
    static var previews: some View {
        let appState = AppState()
        appState.freeDeletesUsedBytes = 50 * 1024 * 1024  // 50MB used

        return FreeTierCard()
            .environment(appState)
            .padding()
            .background(Color.appBackground)
    }
}
#endif
