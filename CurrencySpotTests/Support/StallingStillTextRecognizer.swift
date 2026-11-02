@testable import CurrencySpot
import UIKit

nonisolated final class StallingStillTextRecognizer: StillTextRecognitionService, Sendable {
    nonisolated struct RequestCancelled: Error {}

    let stalledCurrencies: AsyncStream<CurrencyCode>
    private let stalled: AsyncStream<CurrencyCode>.Continuation
    private let stallingCurrency: CurrencyCode
    private let result: StillRecognitionResult

    init(stallingOn stallingCurrency: CurrencyCode, otherwise result: StillRecognitionResult = .empty) {
        (stalledCurrencies, stalled) = AsyncStream.makeStream()
        self.stallingCurrency = stallingCurrency
        self.result = result
    }

    func recognitionLanguages(forMenuPricedIn _: CurrencyCode) -> [Locale.Language] {
        []
    }

    @concurrent
    func recognize(_: UIImage, menuCurrency: CurrencyCode) async throws -> StillRecognitionResult {
        guard menuCurrency == stallingCurrency else { return result }
        let (untilCancelled, pending) = AsyncStream<Void>.makeStream()
        defer { pending.finish() }
        stalled.yield(menuCurrency)
        for await _ in untilCancelled {}
        throw RequestCancelled()
    }
}
