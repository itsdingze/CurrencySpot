import CoreGraphics
import Vision

nonisolated extension RecognizedTextCandidate {
    private static let maximumReadings = 5

    init?(_ observation: RecognizedTextObservation, regionOfInterest: NormalizedRect, imageSize: CGSize) {
        let readings = observation.topCandidates(Self.maximumReadings)
        guard let topCandidate = readings.first else { return nil }
        func imagePoint(_ point: NormalizedPoint) -> CGPoint {
            point.toImageCoordinates(from: regionOfInterest, imageSize: imageSize, origin: .upperLeft)
        }
        let item = RecognizedTextItem(
            id: observation.uuid,
            transcript: topCandidate.string,
            quad: Quad(
                topLeft: imagePoint(observation.topLeft),
                topRight: imagePoint(observation.topRight),
                bottomRight: imagePoint(observation.bottomRight),
                bottomLeft: imagePoint(observation.bottomLeft)
            ),
            characterSpans: Self.characterSpans(of: topCandidate, along: Quad(normalized: observation)),
            alternateTranscripts: readings.dropFirst().map(\.string)
        )
        self.init(item: item, confidence: topCandidate.confidence)
    }

    private static func characterSpans(of text: RecognizedText, along line: Quad) -> [ClosedRange<CGFloat>]? {
        let transcript = text.string
        guard transcript.contains(where: \.isNumber) else { return nil }
        var spans: [ClosedRange<CGFloat>] = []
        var index = transcript.startIndex
        while index < transcript.endIndex {
            let next = transcript.index(after: index)
            guard let glyph = text.boundingBox(for: index ..< next) else { return nil }
            spans.append(line.baselineSpan(of: Quad(normalized: glyph)))
            index = next
        }
        return spans
    }
}

private nonisolated extension Quad {
    init(normalized region: some QuadrilateralProviding) {
        self.init(
            topLeft: CGPoint(x: region.topLeft.x, y: region.topLeft.y),
            topRight: CGPoint(x: region.topRight.x, y: region.topRight.y),
            bottomRight: CGPoint(x: region.bottomRight.x, y: region.bottomRight.y),
            bottomLeft: CGPoint(x: region.bottomLeft.x, y: region.bottomLeft.y)
        )
    }
}
