import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let description: String
    var buttonTitle: String? = nil
    var buttonAction: (() -> Void)? = nil

    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.appBackgroundTertiary)
                    .frame(width: 88, height: 88)
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(Color.appTextSecondary)
            }
            .scaleEffect(isAnimating ? 1.03 : 1.0)
            .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear { isAnimating = true }

            VStack(spacing: 8) {
                Text(title)
                    .font(.appH2)
                    .foregroundStyle(Color.appTextPrimary)
                Text(description)
                    .font(.appBodyRegular)
                    .foregroundStyle(Color.appTextSecondary)
                    .multilineTextAlignment(.center)
            }

            if let buttonTitle, let buttonAction {
                PrimaryButton(title: buttonTitle, icon: "plus", action: buttonAction)
                    .frame(maxWidth: 240)
            }
        }
        .padding(.horizontal, 40)
        .padding(.top, 60)
    }
}
