import CoreGraphics

nonisolated struct RecognizedTextCandidate: Sendable {
    let item: RecognizedTextItem
    let confidence: Float

    fileprivate var area: CGFloat {
        item.bounds.width * item.bounds.height
    }

    fileprivate var identifyingText: String {
        item.transcript.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}

nonisolated enum RecognizedTextMerger {
    private static let sameLineOverlap: CGFloat = 0.5
    private static let fragmentContainment: CGFloat = 0.8
    private static let minimumFragmentTextLength = 4

    static func merge(_ candidates: [RecognizedTextCandidate]) -> [RecognizedTextItem] {
        let ranked = candidates.indices.sorted {
            (candidates[$0].confidence, candidates[$0].area) > (candidates[$1].confidence, candidates[$1].area)
        }
        var kept: [Int] = []
        for index in ranked {
            let matches = kept.filter { readSameText(candidates[$0], candidates[index]) }
            guard matches.allSatisfy({ isPart(candidates[$0], of: candidates[index]) }) else { continue }
            kept.removeAll { matches.contains($0) }
            kept.append(index)
        }
        return kept.sorted().map { candidates[$0].item }
    }

    private static func isPart(_ part: RecognizedTextCandidate, of whole: RecognizedTextCandidate) -> Bool {
        part.identifyingText.count < whole.identifyingText.count && whole.identifyingText.contains(part.identifyingText)
    }

    private static func readSameText(_ first: RecognizedTextCandidate, _ second: RecognizedTextCandidate) -> Bool {
        let shared = first.item.bounds.intersection(second.item.bounds)
        guard !shared.isNull else { return false }
        let sharedArea = shared.width * shared.height
        let unionArea = first.area + second.area - sharedArea
        return sharedArea / unionArea > sameLineOverlap
            || sharedArea / min(first.area, second.area) >= fragmentContainment && isFragment(first, of: second)
    }

    private static func isFragment(_ first: RecognizedTextCandidate, of second: RecognizedTextCandidate) -> Bool {
        let texts = [first.identifyingText, second.identifyingText].sorted { $0.count < $1.count }
        return texts[0].count >= minimumFragmentTextLength && texts[1].contains(texts[0])
    }
}
