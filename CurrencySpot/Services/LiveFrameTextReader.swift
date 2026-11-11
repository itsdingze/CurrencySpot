import Foundation
import Vision

nonisolated struct LiveFrameTextReader: Sendable {
    @concurrent
    func read(_ frame: CapturedFrame, languages: [Locale.Language]) async throws -> [RecognizedTextItem] {
        var request = RecognizeTextRequest()
        request.recognitionLanguages = languages
        let frameSize = frame.size
        request.minimumTextHeightFraction = RecognitionRegion.whole(frameSize).minimumTextHeightFraction
        let wholeFrame = NormalizedRect(x: 0, y: 0, width: 1, height: 1)
        let observations = try await request.perform(on: frame.pixelBuffer)
        let items = RecognizedTextMerger.merge(observations.compactMap {
            RecognizedTextCandidate($0, regionOfInterest: wholeFrame, imageSize: frameSize)
        })
        return LineInkGaps.marking(items, in: GrayscaleImage(lumaOf: frame.pixelBuffer))
    }
}
