@testable import CurrencySpot
import Foundation
import Testing
import UIKit

@Suite("RecognizeStillImageTextUseCase Tests")
struct RecognizeStillImageTextUseCaseTests {
    private let priceID = UUID()

    private var squareResult: StillRecognitionResult {
        StillRecognitionResult(
            items: [RecognizedTextItem(id: priceID, transcript: "¥1,200", bounds: CGRect(x: 10, y: 10, width: 80, height: 20))],
            imagePixelSize: CGSize(width: 100, height: 100)
        )
    }

    @Test("recognition returns what the recognizer read from the image")
    func recognitionReturnsTheRecognizedText() async throws {
        let useCase = RecognizeStillImageTextUseCase(recognizer: StubStillTextRecognizer(result: squareResult))

        let result = try await useCase.recognizeText(in: UIImage())

        #expect(result == squareResult)
    }

    @Test("a recognition failure reaches the caller")
    func recognitionFailurePropagates() async {
        struct RecognitionError: Error {}
        let useCase = RecognizeStillImageTextUseCase(recognizer: StubStillTextRecognizer(failure: RecognitionError()))

        await #expect(throws: RecognitionError.self) {
            try await useCase.recognizeText(in: UIImage())
        }
    }

    @Test("text is placed where the aspect-fitted image shows it in the viewport")
    func placesTextInTheLetterboxedViewport() {
        let useCase = RecognizeStillImageTextUseCase(recognizer: StubStillTextRecognizer())

        let items = useCase.textItems(in: squareResult, fittedTo: CGSize(width: 200, height: 100))

        #expect(items == [
            RecognizedTextItem(id: priceID, transcript: "¥1,200", bounds: CGRect(x: 60, y: 10, width: 80, height: 20)),
        ])
    }

    @Test("text scales with the viewport when the image is shown larger")
    func scalesTextWithTheViewport() {
        let useCase = RecognizeStillImageTextUseCase(recognizer: StubStillTextRecognizer())

        let items = useCase.textItems(in: squareResult, fittedTo: CGSize(width: 200, height: 300))

        #expect(items.map(\.bounds) == [CGRect(x: 20, y: 70, width: 160, height: 40)])
    }
}
