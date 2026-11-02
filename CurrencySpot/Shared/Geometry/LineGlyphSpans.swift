import CoreGraphics

nonisolated struct LineGlyphSpans {
    private static let markerReachInLineHeights: CGFloat = 0.4
    private static let plausibleWidthRatio: CGFloat = 3
    private static let plausibleCenterShift: CGFloat = 0.25

    private let characters: [Character]
    private let estimated: [ClosedRange<CGFloat>]
    private let measured: [ClosedRange<CGFloat>]?
    private let lineHeightFraction: CGFloat

    init(_ item: RecognizedTextItem) {
        let characters = Array(item.transcript)
        self.characters = characters
        estimated = Self.estimatedSpans(of: characters)
        measured = item.characterSpans.flatMap { $0.count == characters.count ? $0 : nil }
        let width = item.quad.width
        lineHeightFraction = width > 0 ? item.quad.height / width : 0
    }

    func tokenSpan(of token: Range<Int>, includingMarker withMarker: Range<Int>) -> ClosedRange<CGFloat> {
        guard let spans = spans(for: withMarker) else { return 0...0 }
        let span = union(of: withMarker, in: spans)
        let reach = Self.markerReachInLineHeights * lineHeightFraction
        let start = withMarker.lowerBound < token.lowerBound
            ? min(
                span.lowerBound,
                max(span.lowerBound - reach, precedingTextEnd(before: withMarker.lowerBound, in: spans))
            )
            : span.lowerBound
        let end = withMarker.upperBound > token.upperBound
            ? max(
                span.upperBound,
                min(span.upperBound + reach, followingTextStart(after: withMarker.upperBound, in: spans))
            )
            : span.upperBound
        return start...end
    }

    private func spans(for range: Range<Int>) -> [ClosedRange<CGFloat>]? {
        guard !range.isEmpty, range.lowerBound >= 0, range.upperBound <= characters.count else { return nil }
        guard let measured, isPlausible(union(of: range, in: measured), against: union(of: range, in: estimated)) else {
            return estimated
        }
        return measured
    }

    private func union(of range: Range<Int>, in spans: [ClosedRange<CGFloat>]) -> ClosedRange<CGFloat> {
        let visible = range.filter { !characters[$0].isWhitespace }.map { spans[$0] }
        let counted = visible.isEmpty ? Array(spans[range]) : visible
        return (counted.map(\.lowerBound).min() ?? 0)...(counted.map(\.upperBound).max() ?? 0)
    }

    private func isPlausible(_ measured: ClosedRange<CGFloat>, against estimate: ClosedRange<CGFloat>) -> Bool {
        let measuredWidth = measured.upperBound - measured.lowerBound
        let estimatedWidth = estimate.upperBound - estimate.lowerBound
        guard measuredWidth > 0, estimatedWidth > 0 else { return false }
        let ratio = measuredWidth / estimatedWidth
        let shift = abs(measured.midpoint - estimate.midpoint)
        return ratio <= Self.plausibleWidthRatio && ratio >= 1 / Self.plausibleWidthRatio
            && shift <= Self.plausibleCenterShift
    }

    private func precedingTextEnd(before offset: Int, in spans: [ClosedRange<CGFloat>]) -> CGFloat {
        let text = characters.indices.prefix(offset).last { characters[$0].isLetter || characters[$0].isNumber }
        return text.map { spans[$0].upperBound } ?? 0
    }

    private func followingTextStart(after offset: Int, in spans: [ClosedRange<CGFloat>]) -> CGFloat {
        let text = characters.indices.dropFirst(offset).first { characters[$0].isLetter || characters[$0].isNumber }
        return text.map { spans[$0].lowerBound } ?? 1
    }

    private static func estimatedSpans(of characters: [Character]) -> [ClosedRange<CGFloat>] {
        let widths = characters.map { $0.isWide ? CGFloat(2) : 1 }
        let total = max(widths.reduce(0, +), 1)
        var cursor: CGFloat = 0
        return widths.map { width in
            defer { cursor += width }
            return cursor / total...(cursor + width) / total
        }
    }
}

private nonisolated extension ClosedRange where Bound == CGFloat {
    var midpoint: CGFloat {
        (lowerBound + upperBound) / 2
    }
}

private nonisolated extension Character {
    var isWide: Bool {
        unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x1100...0x115F, 0x2E80...0xA4CF, 0xAC00...0xD7A3, 0xF900...0xFAFF, 0xFE30...0xFE4F,
                 0xFF00...0xFF60, 0xFFE0...0xFFE6: true
            default: false
            }
        }
    }
}
