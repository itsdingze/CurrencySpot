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

    static func fontSize(forBoxHeight height: CGFloat) -> CGFloat {
        max(minimumFontSize, height * glyphHeightRatio)
    }
}
