import CoreGraphics
import Foundation

nonisolated struct RecognizedTextItem: Equatable, Sendable {
    let id: UUID
    let transcript: String
    let quad: Quad
    let characterSpans: [ClosedRange<CGFloat>]?
    let inkGaps: [ClosedRange<CGFloat>]?
    let alternateTranscripts: [String]

    init(
        id: UUID,
        transcript: String,
        quad: Quad,
        characterSpans: [ClosedRange<CGFloat>]? = nil,
        inkGaps: [ClosedRange<CGFloat>]? = nil,
        alternateTranscripts: [String] = []
    ) {
        self.id = id
        self.transcript = transcript
        self.quad = quad
        self.characterSpans = characterSpans
        self.inkGaps = inkGaps
        self.alternateTranscripts = alternateTranscripts
    }

    init(id: UUID, transcript: String, bounds: CGRect) {
        self.init(id: id, transcript: transcript, quad: Quad(bounds))
    }

    var bounds: CGRect {
        quad.boundingBox
    }

    func mapped(_ transform: (CGPoint) -> CGPoint) -> RecognizedTextItem {
        RecognizedTextItem(
            id: id,
            transcript: transcript,
            quad: quad.mapped(transform),
            characterSpans: characterSpans,
            inkGaps: inkGaps,
            alternateTranscripts: alternateTranscripts
        )
    }

    func with(inkGaps: [ClosedRange<CGFloat>]) -> RecognizedTextItem {
        RecognizedTextItem(
            id: id,
            transcript: transcript,
            quad: quad,
            characterSpans: characterSpans,
            inkGaps: inkGaps,
            alternateTranscripts: alternateTranscripts
        )
    }
}
