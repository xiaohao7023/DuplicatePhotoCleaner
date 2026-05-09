import SwiftUI

extension Font {
    static let appH1 = Font.system(size: 22, weight: .semibold)
    static let appH2 = Font.system(size: 20, weight: .semibold)
    static let appH3 = Font.system(size: 17, weight: .semibold)
    static let appBody = Font.system(size: 16, weight: .medium)
    static let appBodyRegular = Font.system(size: 15, weight: .regular)
    static let appCaption = Font.system(size: 14, weight: .regular)
    static let appCaptionMedium = Font.system(size: 14, weight: .medium)
    static let appSmall = Font.system(size: 13, weight: .medium)
    static let appSmallSemibold = Font.system(size: 13, weight: .semibold)
    static let appTiny = Font.system(size: 12, weight: .medium)
    static let appTinySemibold = Font.system(size: 12, weight: .semibold)
    static let appMicro = Font.system(size: 11, weight: .semibold)
    static let appStatNumber = Font.system(size: 36, weight: .semibold)
    static let appPrice = Font.system(size: 24, weight: .semibold)
    static let appMonoSmall = Font.system(size: 12, weight: .medium, design: .monospaced)
}
