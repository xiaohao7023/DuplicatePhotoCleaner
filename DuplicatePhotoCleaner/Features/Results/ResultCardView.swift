import SwiftUI

struct ResultCardView: View {
    let icon: String; let title: String; let count: Int; let sizeText: String; let color: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(color.opacity(0.12)).frame(width: 48, height: 48)
                    Image(systemName: icon).font(.system(size: 22)).foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.appBody).foregroundStyle(Color.appTextPrimary)
                    Text("\(count) items  •  \(sizeText)").font(.appCaption).foregroundStyle(Color.appTextSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.appTextQuaternary)
            }
            .padding(Layout.listItemPadding).cardBackground()
        }
        .buttonStyle(.plain).pressableScale()
    }
}
