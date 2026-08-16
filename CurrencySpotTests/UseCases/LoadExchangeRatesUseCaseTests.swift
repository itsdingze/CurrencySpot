@testable import CurrencySpot
import Foundation
import Testing

@Suite("LoadExchangeRatesUseCase Tests")
struct LoadExchangeRatesUseCaseTests {
    private let repository = MockExchangeRateRepository()
    private let useCase: LoadExchangeRatesUseCase

    init() {
        useCase = LoadExchangeRatesUseCase(repository: repository)
    }

    @Test("a successful refresh publishes the fetched rates and clears the failure flag")
    func refreshSucceeds() async throws {
        repository.fetchExchangeRatesResult = .success([ExchangeRate(currencyCode: .eur, rate: 0.85)])

        guard case let .rates(rates, _, refreshFailed) = await useCase.refresh() else {
            Issue.record("expected .rates")
            return
        }

        #expect(rates.map(\.currencyCode) == [.eur])
        #expect(refreshFailed == false)
        #expect(repository.fetchExchangeRatesCallCount == 1)
    }

    @Test("a failed refresh falls back to saved rates and raises the failure flag")
    func refreshFallsBackToSaved() async {
        repository.fetchExchangeRatesResult = .failure(.networkError("offline"))
        repository.loadExchangeRatesResult = .success([ExchangeRate(currencyCode: .jpy, rate: 110)])

        guard case let .rates(rates, _, refreshFailed) = await useCase.refresh() else {
            Issue.record("expected .rates")
            return
        }

        #expect(rates.map(\.currencyCode) == [.jpy])
        #expect(refreshFailed)
    }

    @Test("a failed refresh with nothing saved surfaces the network error, not the load error")
    func refreshSurfacesOriginalError() async {
        repository.fetchExchangeRatesResult = .failure(.networkError("offline"))
        repository.loadExchangeRatesResult = .failure(.noCachedData)

        guard case let .unavailable(error) = await useCase.refresh() else {
            Issue.record("expected .unavailable")
            return
        }

        #expect(error == .networkError("offline"))
    }

    @Test("saved rates load without any network call")
    func savedAvoidsNetwork() async {
        repository.loadExchangeRatesResult = .success([ExchangeRate(currencyCode: .cad, rate: 1.25)])

        guard case let .rates(rates, _, refreshFailed) = await useCase.saved() else {
            Issue.record("expected .rates")
            return
        }

        #expect(rates.map(\.currencyCode) == [.cad])
        #expect(refreshFailed == false)
        #expect(repository.fetchExchangeRatesCallCount == 0)
    }

    @Test("shouldRefresh delegates to the repository", arguments: [true, false])
    func shouldRefreshDelegates(expected: Bool) async {
        repository.shouldRefreshRatesResult = expected

        #expect(await useCase.shouldRefresh() == expected)
    }

    @Test(
        "reconnect refreshes whenever the shown rates are missing, sampled, or stale",
        arguments: [
            (false, false, false, true),
            (true, true, false, true),
            (true, false, true, true),
            (true, false, false, false),
        ]
    )
    func reconnectPolicy(hasRates: Bool, isShowingSample: Bool, lastRefreshFailed: Bool, expected: Bool) async {
        repository.shouldRefreshRatesResult = false

        let shouldRefresh = await useCase.shouldRefreshOnReconnect(
            hasRates: hasRates,
            isShowingSample: isShowingSample,
            lastRefreshFailed: lastRefreshFailed
        )

        #expect(shouldRefresh == expected)
    }

    @Test("a healthy reconnect still refreshes when the repository says the rates are stale")
    func reconnectHonorsStaleness() async {
        repository.shouldRefreshRatesResult = true

        let shouldRefresh = await useCase.shouldRefreshOnReconnect(
            hasRates: true,
            isShowingSample: false,
            lastRefreshFailed: false
        )

        #expect(shouldRefresh)
    }

    @Test("sample rates come from the shipped fallback set")
    func sampleRates() {
        #expect(useCase.sampleRates().count == SampleExchangeRates.rates.count)
    }
}
