import SwiftUI

// MARK: - SmartScanHeader

/// 自动扫描状态指示器
struct SmartScanHeader: View {
    let isScanning: Bool
    let currentCategory: ScanCategory?

    var body: some View {
        RoundedCard {
            HStack(spacing: 12) {
                if isScanning {
                    // MARK: - 扫描中
                    ProgressView()
                        .tint(Color.appPrimary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Smart Scan in Progress...")
                            .font(.appBody)
                            .foregroundStyle(Color.appTextPrimary)

                        if let category = currentCategory {
                            Text("Scanning \(category.displayName)")
                                .font(.appCaption)
                                .foregroundStyle(Color.appTextSecondary)
                        }
                    }

                    Spacer()
                } else {
                    // MARK: - 扫描完成
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.appSuccess)

                    Text("Smart Scan Complete!")
                        .font(.appBody)
                        .foregroundStyle(Color.appTextPrimary)

                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SmartScanHeader_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            SmartScanHeader(isScanning: true, currentCategory: .duplicates)
            SmartScanHeader(isScanning: false, currentCategory: nil)
        }
        .padding()
        .background(Color.appBackground)
    }
}
#endif
