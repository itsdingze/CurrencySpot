import CoreGraphics
import Foundation

nonisolated struct RecognizedTextItem: Equatable, Sendable {
    let id: UUID
    let transcript: String
    let quad: Quad
    let characterSpans: [ClosedRange<CGFloat>]?

    init(
        id: UUID,
        transcript: String,
        quad: Quad,
        characterSpans: [ClosedRange<CGFloat>]? = nil
    ) {
        self.id = id
        self.transcript = transcript
        self.quad = quad
        self.characterSpans = characterSpans
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
            characterSpans: characterSpans
        )
    }
}
