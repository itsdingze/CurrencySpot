import UIKit

// MARK: - RecognizeStillImageTextUseCase

final class RecognizeStillImageTextUseCase {
    private let recognizer: StillTextRecognitionService

    init(recognizer: StillTextRecognitionService) {
        self.recognizer = recognizer
    }

    func recognizeText(in image: UIImage) async throws -> StillRecognitionResult {
        try await recognizer.recognize(image)
    }

    func textItems(in result: StillRecognitionResult, fittedTo viewSize: CGSize) -> [RecognizedTextItem] {
        let mapping = AspectFitMapping(imageSize: result.imagePixelSize, viewSize: viewSize)
        return result.items.map { item in
            RecognizedTextItem(id: item.id, transcript: item.transcript, bounds: mapping.viewRect(for: item.bounds))
        }
    }
}
