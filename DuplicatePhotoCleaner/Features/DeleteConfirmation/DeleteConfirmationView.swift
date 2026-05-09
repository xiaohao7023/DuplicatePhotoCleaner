import SwiftUI
import Photos

struct DeleteConfirmationView: View {
    let photosToDelete: [PHAsset]
    let onDelete: (Bool) -> Void
    @Environment(\.dismiss) private var dismiss

    private var totalSize: Int64 {
        photosToDelete.reduce(0) { total, asset in
            let resources = PHAssetResource.assetResources(for: asset)
            return total + (resources.first?.value(forKey: "fileSize") as? Int64 ?? 0)
        }
    }

    private var formattedSize: String {
        let f = ByteCountFormatter(); f.allowedUnits = [.useGB, .useMB]; f.countStyle = .file
        return f.string(fromByteCount: totalSize)
    }

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle().fill(Color.appDangerBG).frame(width: 72, height: 72)
                Image(systemName: "trash.fill").font(.system(size: 28)).foregroundStyle(Color.appDanger)
            }
            VStack(spacing: 8) {
                Text("Delete \(photosToDelete.count) Photos?").font(.appH2).foregroundStyle(Color.appTextPrimary)
                Text("You'll free up \(formattedSize) of storage space.")
                    .font(.appBodyRegular).foregroundStyle(Color.appTextSecondary).multilineTextAlignment(.center)
            }
            VStack(spacing: 12) {
                Button { onDelete(false); dismiss() } label: {
                    HStack {
                        Image(systemName: "trash.slash").font(.system(size: 18)).foregroundStyle(Color.appPrimary).frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Move to Recently Deleted").font(.appBody).foregroundStyle(Color.appTextPrimary)
                            Text("Photos kept for 30 days, then auto-deleted").font(.appCaption).foregroundStyle(Color.appTextSecondary)
                        }
                        Spacer()
                        StatusTag(text: "Recommended", type: .success)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .stroke(Color.appPrimary.opacity(0.3), lineWidth: 1.5).fill(Color.appPrimary.opacity(0.04)))
                }.buttonStyle(.plain)

                Button { onDelete(true); dismiss() } label: {
                    HStack {
                        Image(systemName: "trash.fill").font(.system(size: 18)).foregroundStyle(Color.appDanger).frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Delete Permanently").font(.appBody).foregroundStyle(Color.appDanger)
                            Text("Cannot be undone").font(.appCaption).foregroundStyle(Color.appTextSecondary)
                        }
                        Spacer()
                    }
                    .padding(16).background(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous).fill(Color.appDangerBG))
                }.buttonStyle(.plain)
            }
            Button("Cancel") { dismiss() }.font(.appBody).foregroundStyle(Color.appTextSecondary).padding(.top, 8)
        }
        .padding(24).background(Color.appBackground)
    }
}
