import SwiftUI

struct DeletePreferencePickerView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var selection: DeletePreference = .recentlyDeleted
    var onConfirm: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "trash.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.appDanger)

            Text("Delete Mode")
                .font(.appH3)
                .foregroundStyle(Color.appTextPrimary)

            Text("Choose how you'd like to delete photos.\nYou can change this later in Settings.")
                .font(.appCaption)
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                ForEach(DeletePreference.allCases) { option in
                    PreferenceOptionRow(option: option, isSelected: selection == option) {
                        selection = option
                    }
                }
            }

            // 免费额度预警（仅免费用户、配额 > 80% 时显示）
            if !appState.isPurchased && appState.freeQuotaProgress > 0.8 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                    Text(appState.freeQuotaProgress > 0.95
                         ? "Free limit almost used up — \(formatRemaining) left"
                         : "\(Int((1 - appState.freeQuotaProgress) * 100))% free quota remaining (\(formatRemaining))")
                        .font(.system(size: 10.5, weight: .medium))
                }
                .foregroundStyle(Color.appDanger)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            }

            if let onConfirm {
                Button {
                    appState.deletePreference = selection
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        onConfirm()
                    }
                } label: {
                    Text("Confirm & Delete")
                        .font(.appSmallSemibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).fill(Color.appDanger))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    appState.deletePreference = selection
                    dismiss()
                } label: {
                    Text("Save")
                        .font(.appSmallSemibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).fill(Color.appPrimary))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(Color.appBackground)
        .presentationDetents([.fraction(0.6)])
        .onAppear { selection = appState.deletePreference }
    }

    private var formatRemaining: String {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useGB, .useMB]
        f.countStyle = .file
        return f.string(fromByteCount: appState.freeDeletesRemainingBytes)
    }
}

private struct PreferenceOptionRow: View {
    let option: DeletePreference
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: option.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(option.iconColor)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(option.label)
                        .font(.appBody)
                        .foregroundStyle(Color.appTextPrimary)
                    Text(option.description)
                        .font(.appCaption)
                        .foregroundStyle(Color.appTextSecondary)
                }
                Spacer()
                let iconName = isSelected ? "checkmark.circle.fill" : "circle"
                let iconColor = isSelected ? Color.appPrimary : Color.appTextQuaternary
                Image(systemName: iconName)
                    .font(.system(size: 22))
                    .foregroundStyle(iconColor)
            }
            .padding(14)
            .background(optionRowBackground)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var optionRowBackground: some View {
        let bgColor = isSelected ? Color.appPrimary.opacity(0.06) : Color.appBackgroundSecondary
        RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
            .fill(bgColor)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .stroke(isSelected ? Color.appPrimary.opacity(0.3) : Color.clear, lineWidth: 1.5)
            )
    }
}
