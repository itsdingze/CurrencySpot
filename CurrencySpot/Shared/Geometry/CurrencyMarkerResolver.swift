//
//  CurrencyMarkerResolver.swift
//  CurrencySpot
//

import CoreGraphics
import Foundation

/// Associates a recognized number with a currency marker that OCR split into its
/// own item — "680" next to a standalone "円", or "¥" sitting before "680".
/// Such a number reads as a price even though its own transcript carries no
/// marker. Coordinates are in the camera view's space, shared by every item.
struct CurrencyMarkerResolver {
    /// Largest horizontal gap between number and marker, as a multiple of the
    /// number's height, for the marker to still count as sitting beside it.
    let maxGap: CGFloat
    /// Minimum vertical overlap, as a fraction of the shorter height, for the
    /// two to count as sharing a text line.
    let minLineOverlap: CGFloat

    /// IDs of the digit-bearing items that own a standalone currency marker.
    /// Each marker promotes only its single nearest number on the same line, so
    /// a marker between two figures can't flag both, and a stray marker can't
    /// flag a whole row.
    func numbersAdjacentToMarker(in items: [RecognizedTextItem]) -> Set<UUID> {
        let markers = items.filter { PriceClassifier.isStandaloneCurrencyMarker($0.transcript) }
        guard !markers.isEmpty else { return [] }
        let numbers = items.filter { $0.transcript.contains(where: \.isNumber) }
        guard !numbers.isEmpty else { return [] }

        return Set(markers.compactMap { marker in nearestNumber(to: marker.bounds, among: numbers)?.id })
    }

    /// The number whose box sits closest to the marker on the same line, within
    /// the gap tolerance; nil when none qualifies.
    private func nearestNumber(to marker: CGRect, among numbers: [RecognizedTextItem]) -> RecognizedTextItem? {
        numbers
            .compactMap { number in gap(from: number.bounds, to: marker).map { (number, $0) } }
            .min { $0.1 < $1.1 }?
            .0
    }

    /// Horizontal gap between the two boxes when they share a text line, else nil.
    private func gap(from number: CGRect, to marker: CGRect) -> CGFloat? {
        let verticalOverlap = min(number.maxY, marker.maxY) - max(number.minY, marker.minY)
        guard verticalOverlap > minLineOverlap * min(number.height, marker.height) else { return nil }
        let horizontalGap = max(number.minX, marker.minX) - min(number.maxX, marker.maxX)
        guard horizontalGap <= maxGap * number.height else { return nil }
        return horizontalGap
    }
}
