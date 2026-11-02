import Foundation

struct PriceCandidate: Equatable, Sendable {
    let amount: Decimal
    let isPrice: Bool
    let range: Range<String.Index>
    let rangeIncludingMarker: Range<String.Index>

    var classification: PriceClassification {
        PriceClassification(amount: amount, isPrice: isPrice)
    }
}
