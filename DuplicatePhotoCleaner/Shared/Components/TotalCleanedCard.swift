import SwiftUI

// MARK: - TotalCleanedCard

/// 底部已删除汇总卡片（简化版）
struct TotalCleanedCard: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        RoundedCard {
            VStack(alignment: .leading, spacing: 12) {
                // MARK: - 标题
                Text("Total Cleaned")
                    .font(.appSmallSemibold)
                    .foregroundStyle(Color.appTextSecondary)
                    .textCase(.uppercase)
                    .tracking(0.8)

                // MARK: - 已删除总量（绿色大字）
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(formatBytes(appState.cumulativeFreedBytes))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appSuccess)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.appSuccess)

                    Spacer()

                    // 删除项目数
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(appState.cumulativeDeletedCount)")
                            .font(.appH3)
                            .foregroundStyle(Color.appTextPrimary)
                        Text("items deleted")
                            .font(.appCaption)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useGB, .useMB]
        f.countStyle = .file
        return f.string(fromByteCount: bytes)
    }
}

// MARK: - Preview

#if DEBUG
struct TotalCleanedCard_Previews: PreviewProvider {
    static var previews: some View {
        let appState = AppState()
        appState.cumulativeFreedBytes = 850 * 1024 * 1024  // 850MB
        appState.cumulativeDeletedCount = 1234

        return TotalCleanedCard()
            .environment(appState)
            .padding()
            .background(Color.appBackground)
    }
}
#endif
