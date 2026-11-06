import Foundation

struct CurrencyMarkerBinder {
    private static let maxSpaces = 2

    private let text: NormalizedTranscript
    private let markers: [CurrencyMarker]

    init(text: NormalizedTranscript, markers: [CurrencyMarker]) {
        self.text = text
        self.markers = markers
    }

    func hasAdjacentSpaceGroupingMarker(_ span: Range<Int>) -> Bool {
        markers.contains { $0.allowsSpacedGrouping && isAdjacent($0, to: span) }
    }

    func hasAdjacentUnambiguousMarker(_ span: Range<Int>) -> Bool {
        markers.contains { !$0.needsMoneyShape && isAdjacent($0, to: span) }
    }

    private func isAdjacent(_ marker: CurrencyMarker, to span: Range<Int>) -> Bool {
        (span.upperBound <= marker.span.lowerBound && gap(fromNumber: span, toMarker: marker) != nil)
            || (marker.span.upperBound <= span.lowerBound && gap(fromMarker: marker, toNumber: span) != nil)
    }

    func bind(_ tokens: [NumberToken], canBind: (Int, CurrencyMarker) -> Bool) -> [Int: CurrencyMarker] {
        var bindings: [Int: CurrencyMarker] = [:]
        for marker in markers {
            let left = tokens.indices.last { tokens[$0].span.upperBound <= marker.span.lowerBound }
                .flatMap { index in gap(fromNumber: tokens[index].span, toMarker: marker).map { (index, $0) } }
            let right = tokens.indices.first { tokens[$0].span.lowerBound >= marker.span.upperBound }
                .flatMap { index in gap(fromMarker: marker, toNumber: tokens[index].span).map { (index, $0) } }
            let candidates = Self.nearestFirst(left, right, preferring: marker.placement) { tokens[$0].isYearShaped }
            let chosen = candidates.first { index in
                bindings[index] == nil && canBind(index, marker)
            }
            if let chosen { bindings[chosen] = marker }
        }
        return bindings
    }

    private func gap(fromNumber span: Range<Int>, toMarker marker: CurrencyMarker) -> Int? {
        let gap = span.upperBound..<marker.span.lowerBound
        return text.isBlank(gap, atMost: Self.maxSpaces) ? gap.count : nil
    }

    private func gap(fromMarker marker: CurrencyMarker, toNumber span: Range<Int>) -> Int? {
        guard marker.placement != .afterNumberOnly else { return nil }
        var gapStart = marker.span.upperBound
        if marker.allowsPunctuationGap, let punctuation = text.character(at: gapStart), ":)".contains(punctuation) {
            gapStart += 1
        }
        guard gapStart <= span.lowerBound else { return nil }
        let gap = gapStart..<span.lowerBound
        return text.isBlank(gap, atMost: Self.maxSpaces) ? span.lowerBound - marker.span.upperBound : nil
    }

    private static func nearestFirst(
        _ left: (index: Int, gap: Int)?,
        _ right: (index: Int, gap: Int)?,
        preferring placement: CurrencyMarker.Placement,
        isYearShaped: (Int) -> Bool
    ) -> [Int] {
        switch (left, right) {
        case let (left?, right?) where left.gap != right.gap:
            left.gap < right.gap ? [left.index, right.index] : [right.index, left.index]
        case let (left?, right?):
            tieOrder(
                preferred: placement == .beforeNumber ? right.index : left.index,
                other: placement == .beforeNumber ? left.index : right.index,
                isYearShaped: isYearShaped
            )
        case let (left?, nil):
            [left.index]
        case let (nil, right?):
            [right.index]
        case (nil, nil):
            []
        }
    }

    private static func tieOrder(preferred: Int, other: Int, isYearShaped: (Int) -> Bool) -> [Int] {
        isYearShaped(preferred) && !isYearShaped(other) ? [other, preferred] : [preferred, other]
    }
}
