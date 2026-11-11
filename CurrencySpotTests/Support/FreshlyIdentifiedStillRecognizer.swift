@testable import CurrencySpot
import UIKit

nonisolated struct FreshlyIdentifiedStillRecognizer: StillTextRecognitionService {
    let lines: [(transcript: String, bounds: CGRect)]
    let imagePixelSize: CGSize

    func recognitionLanguages(forMenuPricedIn currency: CurrencyCode) -> [Locale.Language] {
        [Locale.Language(identifier: currency == "JPY" ? "ja-JP" : "en-US")]
    }

    @concurrent
    func recognize(_: UIImage, menuCurrency _: CurrencyCode) async throws -> StillRecognitionResult {
        StillRecognitionResult(
            items: lines.map { RecognizedTextItem(id: UUID(), transcript: $0.transcript, bounds: $0.bounds) },
            imagePixelSize: imagePixelSize
        )
    }
}
