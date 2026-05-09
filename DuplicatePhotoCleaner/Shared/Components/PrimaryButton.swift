import SwiftUI

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isDanger: Bool = false
    var isSecondary: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(.appH3)
            }
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(backgroundView)
            .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        }
        .disabled(isDisabled)
        .buttonStyle(.plain)
        .modifier(PressableScale(scale: 0.97))
        .opacity(isDisabled ? 0.6 : 1.0)
    }

    @ViewBuilder
    private var backgroundView: some View {
        if isDanger {
            Color.appDanger.opacity(0.08)
        } else if isSecondary {
            Color.appBackgroundTertiary
        } else {
            Color.appPrimary
                .shadow(color: Color.appPrimary.opacity(0.2), radius: 6, x: 0, y: 2)
        }
    }

    private var foregroundColor: Color {
        if isDanger { return .appDanger }
        if isSecondary { return .appTextPrimary }
        return .white
    }
}
