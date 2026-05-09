import SwiftUI

struct ScanProgressView: View {
    @Bindable var progress: ScanProgressState
    let onCancel: () -> Void
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            ZStack {
                Circle().stroke(Color.appPrimary.opacity(0.15), lineWidth: 4).frame(width: 100, height: 100)
                Circle().trim(from: 0, to: progress.overallProgress)
                    .stroke(Color.appPrimary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 100, height: 100).rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: progress.overallProgress)
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 36, weight: .light)).foregroundStyle(Color.appPrimary)
                    .rotationEffect(.degrees(isAnimating ? 5 : -5))
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
            }
            .onAppear { isAnimating = true }

            VStack(spacing: 12) {
                Text("Scanning your photos...").font(.appH2).foregroundStyle(Color.appTextPrimary)
                Text(progress.phase.rawValue).font(.appBodyRegular).foregroundStyle(Color.appTextSecondary)
            }

            VStack(spacing: 8) {
                ProgressBar(value: progress.overallProgress).padding(.horizontal, 40)
                Text("\(Int(progress.overallProgress * 100))%").font(.appMonoSmall).foregroundStyle(Color.appTextTertiary)
            }

            if progress.overallProgress > 0.1 {
                RoundedCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Found so far").font(.appSmallSemibold).foregroundStyle(Color.appTextSecondary)
                            .textCase(.uppercase).tracking(0.6)
                        ScanStatRow(icon: "doc.on.doc.fill", label: "Duplicate groups", value: "\(progress.duplicatesFound)", color: .appPrimary)
                        ScanStatRow(icon: "square.stack.3d.up.fill", label: "Similar groups", value: "\(progress.similarGroupsFound)", color: .appTeal)
                        ScanStatRow(icon: "eye.trianglebadge.exclamationmark", label: "Blurry photos", value: "\(progress.blurryFound)", color: .appWarning)
                    }
                }.padding(.horizontal, 20)
            }
            Spacer()
            Button("Cancel", action: onCancel).font(.appBody).foregroundStyle(Color.appTextSecondary).padding(.bottom, 40)
        }
        .background(Color.appBackground)
    }
}

private struct ScanStatRow: View {
    let icon: String; let label: String; let value: String; let color: Color
    var body: some View {
        HStack {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(color).frame(width: 24)
            Text(label).font(.appCaption).foregroundStyle(Color.appTextSecondary)
            Spacer()
            Text(value).font(.appSmallSemibold).foregroundStyle(Color.appTextPrimary)
        }
    }
}
