import Foundation

final class LinePriceReader {
    struct Reading {
        let amount: Decimal
        let isPrice: Bool
        let token: Range<Int>
        let tokenIncludingMarker: Range<Int>
    }

    private struct ClassificationKey: Hashable {
        let transcript: String
        let baseCurrency: CurrencyCode
    }

    private static let memoCapacity = 512

    private var memo: [ClassificationKey: [PriceCandidate]] = [:]

    func readings(
        of item: RecognizedTextItem,
        marker: StandaloneCurrencyMarker?,
        baseCurrency: CurrencyCode
    ) -> [Reading] {
        if let marker {
            let joined = marker.attached(to: item.transcript)
            let shift = marker.side == .leading ? 1 : 0
            return readings(in: joined, shiftedBy: shift, within: item.transcript.count, baseCurrency: baseCurrency)
        }
        return readings(in: item.transcript, shiftedBy: 0, within: item.transcript.count, baseCurrency: baseCurrency)
    }

    private func readings(in transcript: String, shiftedBy shift: Int, within length: Int, baseCurrency: CurrencyCode) -> [Reading] {
        Self.readings(of: candidates(in: transcript, baseCurrency: baseCurrency), in: transcript, shiftedBy: shift, within: length)
    }

    private func candidates(in transcript: String, baseCurrency: CurrencyCode) -> [PriceCandidate] {
        let key = ClassificationKey(transcript: transcript, baseCurrency: baseCurrency)
        if let memoized = memo[key] {
            return memoized
        }
        if memo.count >= Self.memoCapacity {
            memo.removeAll(keepingCapacity: true)
        }
        let candidates = PriceClassifier(baseCurrency: baseCurrency).candidates(in: transcript)
        memo[key] = candidates
        return candidates
    }

    private static func readings(of candidates: [PriceCandidate], in transcript: String, shiftedBy shift: Int, within length: Int) -> [Reading] {
        func offsets(_ range: Range<String.Index>) -> Range<Int> {
            let lower = transcript.distance(from: transcript.startIndex, to: range.lowerBound) - shift
            let upper = transcript.distance(from: transcript.startIndex, to: range.upperBound) - shift
            return min(max(lower, 0), length)..<min(max(upper, 0), length)
        }
        return candidates.map { candidate in
            Reading(
                amount: candidate.amount,
                isPrice: candidate.isPrice,
                token: offsets(candidate.range),
                tokenIncludingMarker: offsets(candidate.rangeIncludingMarker)
            )
        }
    }
}
