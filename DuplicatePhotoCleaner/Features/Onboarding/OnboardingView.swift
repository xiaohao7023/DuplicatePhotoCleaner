import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var revealStep = -1

    private let features: [(icon: String, title: String, desc: String, color: Color)] = [
        ("lock.shield.fill", "Your Photos Stay Private", "All analysis happens 100% on-device.\nNothing is uploaded to the cloud.", .appSuccess),
        ("sparkles", "AI-Powered Smart Detection", "Finds duplicates, similar photos, and\nblurry shots you might miss.", .appPrimary),
        ("arrow.down.circle.fill", "Free Up Space in Minutes", "One scan identifies what to clean.\nReclaim gigabytes instantly.", .appTeal)
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // App branding
            HStack(spacing: 10) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Color.appPrimary)
                Text("Photo Cleaner")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.appTextPrimary)
            }
            .opacity(revealStep >= 0 ? 1 : 0)
            .offset(y: revealStep >= 0 ? 0 : 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 40)

            // Feature timeline
            VStack(spacing: 0) {
                ForEach(0..<features.count, id: \.self) { i in
                    featureRow(features[i], step: i + 1, isLast: i == features.count - 1)
                }
            }
            .padding(.leading, 4)

            Spacer(minLength: 24)

            // CTA
            PrimaryButton(title: "Get Started") { onComplete() }
                .opacity(revealStep >= 4 ? 1 : 0)
                .offset(y: revealStep >= 4 ? 0 : 20)
                .padding(.bottom, 48)
        }
        .padding(.horizontal, Layout.pageHorizontalPadding)
        .background(Color.appBackground)
        .onAppear { startRevealSequence() }
    }

    // MARK: - Feature Row

    @ViewBuilder
    private func featureRow(_ f: (icon: String, title: String, desc: String, color: Color), step: Int, isLast: Bool) -> some View {
        let isRevealed = revealStep >= step

        HStack(alignment: .top, spacing: 18) {
            // Timeline: icon + line
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(f.color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: f.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(f.color)
                }
                .scaleEffect(isRevealed ? 1 : 0.5)
                .opacity(isRevealed ? 1 : 0)

                if !isLast {
                    Rectangle()
                        .fill(f.color.opacity(0.2))
                        .frame(width: 2, height: 48)
                        .opacity(isRevealed ? 1 : 0)
                }
            }
            .frame(width: 40)

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(f.title)
                    .font(.appH3)
                    .foregroundStyle(Color.appTextPrimary)
                Text(f.desc)
                    .font(.appCaption)
                    .foregroundStyle(Color.appTextSecondary)
                    .lineSpacing(2)
            }
            .opacity(isRevealed ? 1 : 0)
            .offset(x: isRevealed ? 0 : 12)
            .padding(.top, 6)

            Spacer()
        }
        .padding(.bottom, isLast ? 0 : 8)
    }

    // MARK: - Animation

    private func startRevealSequence() {
        for step in -1...4 {
            let delay = step < 0 ? 0.1 : Double(step) * 0.4
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
                    revealStep = step
                }
            }
        }
    }
}
