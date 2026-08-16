import CoreGraphics
import Foundation

struct CurrencyMarkerResolver {
    let maxGap: CGFloat
    let minLineOverlap: CGFloat

    func numbersAdjacentToMarker(in items: [RecognizedTextItem]) -> Set<UUID> {
        let markers = items.filter { PriceClassifier.isStandaloneCurrencyMarker($0.transcript) }
        guard !markers.isEmpty else { return [] }
        let numbers = items.filter { $0.transcript.contains(where: \.isNumber) }
        guard !numbers.isEmpty else { return [] }

        return Set(markers.compactMap { marker in nearestNumber(to: marker.bounds, among: numbers)?.id })
    }

    private func nearestNumber(to marker: CGRect, among numbers: [RecognizedTextItem]) -> RecognizedTextItem? {
        numbers
            .compactMap { number in gap(from: number.bounds, to: marker).map { (number, $0) } }
            .min { $0.1 < $1.1 }?
            .0
    }

    private func gap(from number: CGRect, to marker: CGRect) -> CGFloat? {
        let verticalOverlap = min(number.maxY, marker.maxY) - max(number.minY, marker.minY)
        guard verticalOverlap > minLineOverlap * min(number.height, marker.height) else { return nil }
        let horizontalGap = max(number.minX, marker.minX) - min(number.maxX, marker.maxX)
        guard horizontalGap <= maxGap * number.height else { return nil }
        return horizontalGap
    }
}
