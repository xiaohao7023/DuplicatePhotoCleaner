import SwiftUI

struct StorageOverviewView: View {
    let usedGB: Double
    let totalGB: Double
    let freedBytes: Int64
    let deletedCount: Int

    private var availableGB: Double { totalGB - usedGB }
    private var usedPercent: Double { usedGB / totalGB }

    var body: some View {
        RoundedCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "internaldrive.fill").font(.system(size: 18)).foregroundStyle(Color.appPrimary)
                    Text("Storage Overview").font(.appH3).foregroundStyle(Color.appTextPrimary)
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 8) {
                    ProgressBar(value: usedPercent, color: progressColor)
                    HStack {
                        Text(String(format: "%.1f GB used", usedGB)).font(.appCaption).foregroundStyle(Color.appTextSecondary)
                        Spacer()
                        Text(String(format: "%.1f GB available", availableGB))
                            .font(.appCaption).foregroundStyle(availableGB < 10 ? Color.appWarning : Color.appTextSecondary)
                    }
                }

                if deletedCount > 0 {
                    Divider().foregroundStyle(Color.appDividerLight)
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles").font(.system(size: 14)).foregroundStyle(Color.appSuccess)
                        Text("\(deletedCount) photos cleaned  •  \(formatBytes(freedBytes)) freed")
                            .font(.appCaption).foregroundStyle(Color.appTextSecondary)
                    }
                }
            }
        }
    }

    private var progressColor: Color {
        if availableGB < 5 { return .appDanger }
        if availableGB < 10 { return .appWarning }
        return .appPrimary
    }

    private func formatBytes(_ b: Int64) -> String {
        let f = ByteCountFormatter(); f.allowedUnits = [.useGB, .useMB]; f.countStyle = .file
        return f.string(fromByteCount: b)
    }
}
