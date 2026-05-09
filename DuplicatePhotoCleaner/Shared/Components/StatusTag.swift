import SwiftUI

enum StatusTagType {
    case success, warning, danger, info

    var color: Color {
        switch self {
        case .success: return .appSuccess
        case .warning: return .appWarning
        case .danger: return .appDanger
        case .info: return .appPrimary
        }
    }
}

struct StatusTag: View {
    let text: String
    let type: StatusTagType

    var body: some View {
        Text(text)
            .font(.appTinySemibold)
            .foregroundStyle(type.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(type.color.opacity(0.08))
            )
    }
}
