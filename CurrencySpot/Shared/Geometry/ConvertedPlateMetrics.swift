import CoreGraphics

enum ConvertedPlateMetrics {
    static let tokenOverhang: CGFloat = 2
    static let outlineGrowthAlong: CGFloat = 3
    static let fontPeerRatio: CGFloat = 1.5

    private static let minimumFontSize: CGFloat = 11
    private static let maximumFontSize: CGFloat = 28
    private static let fontToTextHeight: CGFloat = 0.85
    private static let cornerRadiusRatio: CGFloat = 0.25
    private static let maximumCornerRadius: CGFloat = 8
    private static let minimumOutlineGrowthAcross: CGFloat = 2.5
    private static let minimumOutlineHeight: CGFloat = 14

    static func fontSize(forTextHeight height: CGFloat) -> CGFloat {
        min(maximumFontSize, max(minimumFontSize, height * fontToTextHeight))
    }

    static func horizontalPadding(forFontSize fontSize: CGFloat) -> CGFloat {
        max(5, 0.4 * fontSize)
    }

    static func baseHeight(forFontSize fontSize: CGFloat) -> CGFloat {
        (1.2 * fontSize + 3).rounded()
    }

    static func minimumHeight(forFontSize fontSize: CGFloat) -> CGFloat {
        (0.7 * fontSize + 6).rounded()
    }

    static func cornerRadius(forHeight height: CGFloat) -> CGFloat {
        min(maximumCornerRadius, height * cornerRadiusRatio)
    }

    static func outlineGrowthAcross(forTokenHeight height: CGFloat) -> CGFloat {
        max(minimumOutlineGrowthAcross, (minimumOutlineHeight - height) / 2)
    }
}
