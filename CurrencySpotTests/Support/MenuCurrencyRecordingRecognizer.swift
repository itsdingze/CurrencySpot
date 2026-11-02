@testable import CurrencySpot
import Synchronization
import UIKit

nonisolated final class MenuCurrencyRecordingRecognizer: StillTextRecognitionService, Sendable {
    private let currencies = Mutex<[CurrencyCode]>([])

    var recordedCurrencies: [CurrencyCode] {
        currencies.withLock { $0 }
    }

    func recognitionLanguages(forMenuPricedIn _: CurrencyCode) -> [Locale.Language] {
        []
    }

    @concurrent
    func recognize(_: UIImage, menuCurrency: CurrencyCode) async throws -> StillRecognitionResult {
        currencies.withLock { $0.append(menuCurrency) }
        return .empty
    }
}
