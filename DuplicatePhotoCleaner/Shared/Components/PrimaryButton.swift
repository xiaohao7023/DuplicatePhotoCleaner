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
                Text(LocalizedStringKey(title))
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

/// Identifies what kind of media a delete bar is acting on, so localized
/// selection/deletion messages can pick the correct singular/plural noun.
enum CleanupItemKind {
    case duplicate
    case similarPhoto
    case video
    case screenshot
    case blurryPhoto
    case unfavoritedPhoto
}

/// Shared bottom action used by every photo-cleanup detail screen.
struct CleanupDeleteBar: View {
    let selectedCount: Int
    let selectedBytes: Int64
    let itemKind: CleanupItemKind
    let action: () -> Void

    /// "N items selected" — noun keeps a singular base form; plural variations
    /// are resolved from Localizable.xcstrings per language.
    private var selectionKey: LocalizedStringKey {
        switch itemKind {
        case .duplicate: return "\(selectedCount) duplicate selected"
        case .similarPhoto: return "\(selectedCount) similar photo selected"
        case .video: return "\(selectedCount) video selected"
        case .screenshot: return "\(selectedCount) screenshot selected"
        case .blurryPhoto: return "\(selectedCount) blurry photo selected"
        case .unfavoritedPhoto: return "\(selectedCount) unfavorited photo selected"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    if selectedCount > 0 {
                        Text("Free up \(formatBytes(selectedBytes))")
                            .font(.appH3)
                            .foregroundStyle(Color.appTextPrimary)
                        Text(selectionKey)
                            .font(.appCaption)
                            .foregroundStyle(Color.appTextSecondary)
                    } else {
                        Text("No items selected")
                            .font(.appCaption)
                            .foregroundStyle(Color.appTextTertiary)
                    }
                }
                Spacer()
                Button(action: action) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 15, weight: .semibold))
                        Text(selectedCount > 0 ? "Delete \(selectedCount)" : "Delete")
                            .font(.appBody)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Color.appDanger))
                }
                .buttonStyle(.plain)
                .disabled(selectedCount == 0)
                .opacity(selectedCount == 0 ? 0.5 : 1)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(Color.appBackground)
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
