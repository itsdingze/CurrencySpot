//
//  ConvertedPlateMetrics.swift
//  CurrencySpot
//

import CoreGraphics

/// Sizes the converted-price plate's text so it visually matches the
/// original price it covers.
enum ConvertedPlateMetrics {
    /// Detected boxes include padding around the glyphs, so the text inside
    /// renders at roughly three quarters of the box height.
    private static let glyphHeightRatio: CGFloat = 0.75
    /// Floor for tiny or degenerate boxes; below this the amount is illegible.
    private static let minimumFontSize: CGFloat = 11
    /// Corner radius tracks box height so small tags stay crisp, capped so large
    /// plates don't read as pills.
    private static let cornerRadiusRatio: CGFloat = 0.25
    private static let maximumCornerRadius: CGFloat = 8

    static func fontSize(forBoxHeight height: CGFloat) -> CGFloat {
        max(minimumFontSize, height * glyphHeightRatio)
    }

    /// Shared by the converted plate and the detection outline so both round
    /// proportionally to the box they cover.
    static func cornerRadius(forBoxHeight height: CGFloat) -> CGFloat {
        min(maximumCornerRadius, height * cornerRadiusRatio)
    }
}
