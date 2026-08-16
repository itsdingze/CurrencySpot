import CoreGraphics

enum ConvertedPlateMetrics {
    private static let glyphHeightRatio: CGFloat = 0.75
    private static let minimumFontSize: CGFloat = 11
    private static let cornerRadiusRatio: CGFloat = 0.25
    private static let maximumCornerRadius: CGFloat = 8
    static let horizontalInflation: CGFloat = 8
    static let verticalInflation: CGFloat = 6

    static func fontSize(forBoxHeight height: CGFloat) -> CGFloat {
        max(minimumFontSize, height * glyphHeightRatio)
    }

    static func cornerRadius(forBoxHeight height: CGFloat) -> CGFloat {
        min(maximumCornerRadius, height * cornerRadiusRatio)
    }
}
