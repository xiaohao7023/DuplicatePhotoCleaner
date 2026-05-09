import SwiftUI

struct DeleteConfirmSheet: View {
    let preference: DeletePreference
    let count: Int
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.appWarning)

            Text("Delete \(count) Photo\(count > 1 ? "s" : "")?")
                .font(.appH2)
                .foregroundStyle(Color.appTextPrimary)

            HStack(spacing: 10) {
                Image(systemName: preference.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(preference.iconColor)
                Text(preference.label)
                    .font(.appCaption)
                    .foregroundStyle(Color.appTextSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.appBackgroundTertiary))

            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    Text("Cancel")
                        .font(.appSmallSemibold)
                        .foregroundStyle(Color.appTextPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).fill(Color.appBackgroundTertiary))
                }
                .buttonStyle(.plain)

                Button { onConfirm(); dismiss() } label: {
                    Text("Delete")
                        .font(.appSmallSemibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).fill(Color.appDanger))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .background(Color.appBackground)
        .presentationDetents([.fraction(0.42)])
    }
}
