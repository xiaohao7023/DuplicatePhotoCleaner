import SwiftUI

enum Layout {
    static let pageHorizontalPadding: CGFloat = 20
    static let headerToContent: CGFloat = 12
    static let cardSpacing: CGFloat = 12
    static let sectionSpacing: CGFloat = 20
    static let scrollBottomPadding: CGFloat = 100
    static let cardPadding: CGFloat = 20
    static let listItemPadding: CGFloat = 16
}

enum Radius {
    static let sm: CGFloat = 6
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
    static let xl: CGFloat = 16
}

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}
