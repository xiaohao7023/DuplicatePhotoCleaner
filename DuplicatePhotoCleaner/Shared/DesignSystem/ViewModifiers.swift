import SwiftUI

struct AppleCardShadow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: Color(hex: "2D2A26").opacity(0.02), radius: 1, x: 0, y: 0.5)
            .shadow(color: Color(hex: "2D2A26").opacity(0.03), radius: 3, x: 0, y: 1)
            .shadow(color: Color(hex: "2D2A26").opacity(0.02), radius: 8, x: 0, y: 3)
    }
}

struct PressableScale: ViewModifier {
    let scale: CGFloat
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1.0)
            .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) { isPressed = pressing }
            }, perform: {})
    }
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .fill(Color.appSurface)
            )
            .modifier(AppleCardShadow())
    }
}

struct SectionHeaderStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.appSmallSemibold)
            .foregroundStyle(Color.appTextSecondary)
            .textCase(.uppercase)
            .tracking(0.6)
            .padding(.horizontal, Layout.pageHorizontalPadding)
            .padding(.top, Layout.sectionSpacing)
            .padding(.bottom, 8)
    }
}

extension View {
    func appleCardShadow() -> some View { modifier(AppleCardShadow()) }
    func pressableScale(_ scale: CGFloat = 0.98) -> some View { modifier(PressableScale(scale: scale)) }
    func cardBackground() -> some View { modifier(CardBackground()) }
    func sectionHeaderStyle() -> some View { modifier(SectionHeaderStyle()) }

    func hapticOnTap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) -> some View {
        self.onTapGesture {
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }
    }
}
