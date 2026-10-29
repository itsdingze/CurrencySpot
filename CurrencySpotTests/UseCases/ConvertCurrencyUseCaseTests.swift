@testable import CurrencySpot
import Foundation
import Testing

@Suite("ConvertCurrencyUseCase")
struct ConvertCurrencyUseCaseTests {
    private let repository = MockExchangeRateRepository()

    private var convert: ConvertCurrencyUseCase {
        ConvertCurrencyUseCase(
            loadExchangeRates: LoadExchangeRatesUseCase(repository: repository, dateProvider: FixedDateProvider(MockExchangeRateRepository.now))
        )
    }

    @Test("converts with the saved rates without going online")
    func convertsWithSavedRates() async throws {
        repository.loadExchangeRatesResult = .success([
            ExchangeRate(currencyCode: "USD", rate: 1.0),
            ExchangeRate(currencyCode: "EUR", rate: 0.8),
            ExchangeRate(currencyCode: "JPY", rate: 160.0),
        ])

        let conversion = try await convert(amount: 100, from: "EUR", to: "JPY")

        #expect(conversion.converted == 20_000)
        #expect(repository.fetchExchangeRatesCallCount == 0)
    }

    @Test("downloads rates when none are saved")
    func downloadsWhenNothingIsSaved() async throws {
        repository.fetchExchangeRatesResult = .success([
            ExchangeRate(currencyCode: "USD", rate: 1.0),
            ExchangeRate(currencyCode: "EUR", rate: 0.5),
        ])

        let conversion = try await convert(amount: 10, from: "USD", to: "EUR")

        #expect(conversion.converted == 5)
    }

    @Test("a currency without a rate fails instead of converting one to one")
    func missingCurrencyFails() async throws {
        repository.loadExchangeRatesResult = .success([
            ExchangeRate(currencyCode: "USD", rate: 1.0),
            ExchangeRate(currencyCode: "EUR", rate: 0.8),
        ])

        await #expect(throws: ConvertCurrencyUseCase.Failure.noRate("XAU")) {
            try await convert(amount: 1, from: "USD", to: "XAU")
        }
    }

    @Test("no saved rates and no connection fails")
    func offlineWithoutRatesFails() async throws {
        repository.fetchExchangeRatesResult = .failure(.noInternetConnection)
        repository.loadExchangeRatesResult = .failure(.dataValidationError("empty"))

        await #expect(throws: ConvertCurrencyUseCase.Failure.ratesUnavailable(.noInternetConnection)) {
            try await convert(amount: 1, from: "USD", to: "EUR")
        }
    }
}
