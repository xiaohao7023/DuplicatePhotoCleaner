import SwiftUI

// MARK: - V1.1: Free Tier Usage Card

/// Dashboard 卡片，展示免费额度使用状态
struct FreeTierUsageCard: View {
    @Environment(AppState.self) private var appState

    private var formattedUsed: String {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useGB, .useMB]
        f.countStyle = .file
        return f.string(fromByteCount: appState.freeDeletesUsedBytes)
    }

    private var formattedRemaining: String {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useGB, .useMB]
        f.countStyle = .file
        return f.string(fromByteCount: appState.freeDeletesRemainingBytes)
    }

    private var formattedTotal: String {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useGB, .useMB]
        f.countStyle = .file
        return f.string(fromByteCount: AppState.freeTierTotalQuota)
    }

    var body: some View {
        RoundedCard {
            VStack(alignment: .leading, spacing: 12) {
                // 标题行
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.appPrimary)

                        Text("FREE TIER")
                            .font(.appTinySemibold)
                            .foregroundStyle(Color.appTextSecondary)
                            .textCase(.uppercase)
                            .tracking(0.8)
                    }

                    Spacer()

                    if appState.isFreeTierExhausted {
                        Text("Limit Reached")
                            .font(.appTinySemibold)
                            .foregroundStyle(Color.appDanger)
                    }
                }

                // 进度条
                VStack(alignment: .leading, spacing: 6) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // 背景条
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.appBackgroundTertiary)
                                .frame(height: 8)

                            // 进度条
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.appPrimary,
                                            appState.freeQuotaProgress > 0.8 ? Color.appDanger : Color.appPrimary
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * appState.freeQuotaProgress, height: 8)
                                .animation(.easeInOut(duration: 0.3), value: appState.freeQuotaProgress)
                        }
                    }
                    .frame(height: 8)

                    // 使用详情
                    HStack {
                        Text("\(formattedUsed) used")
                            .font(.appCaption)
                            .foregroundStyle(Color.appTextSecondary)

                        Spacer()

                        Text("\(formattedRemaining) remaining")
                            .font(.appCaption)
                            .foregroundStyle(
                                appState.freeDeletesRemainingBytes > 0
                                    ? Color.appSuccess
                                    : Color.appDanger
                            )
                    }
                }

                // 说明文字
                Text("Free limit: \(formattedTotal). Upgrade for unlimited cleaning.")
                    .font(.appCaption)
                    .foregroundStyle(Color.appTextTertiary)
                    .multilineTextAlignment(.leading)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct FreeTierUsageCard_Previews: PreviewProvider {
    static var previews: some View {
        let appState = AppState()
        appState.freeDeletesUsedBytes = 50 * 1024 * 1024  // 50MB used

        return FreeTierUsageCard()
            .environment(appState)
            .padding()
            .background(Color.appBackground)
    }
}
#endif
