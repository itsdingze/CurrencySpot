import Foundation

final class ConvertCurrencyUseCase {
    struct Conversion: Equatable {
        let amount: Decimal
        let from: CurrencyCode
        let to: CurrencyCode
        let converted: Decimal
    }

    enum Failure: Error, Equatable {
        case ratesUnavailable(AppError?)
        case noRate(CurrencyCode)
    }

    private let loadExchangeRates: LoadExchangeRatesUseCase

    init(loadExchangeRates: LoadExchangeRatesUseCase) {
        self.loadExchangeRates = loadExchangeRates
    }

    func callAsFunction(amount: Decimal, from: CurrencyCode, to: CurrencyCode) async throws(Failure) -> Conversion {
        let table = try await rateTable()
        for currency in [from, to] where table.usdRate(for: currency) == nil {
            throw .noRate(currency)
        }
        return Conversion(amount: amount, from: from, to: to, converted: table.convert(amount, from: from, to: to))
    }

    private func rateTable() async throws(Failure) -> RateTable {
        if case let .rates(rates, _, _) = await loadExchangeRates.saved(), !rates.isEmpty {
            return RateTable(rates)
        }
        switch await loadExchangeRates.refresh() {
        case let .rates(rates, _, _) where !rates.isEmpty:
            return RateTable(rates)
        case let .unavailable(error):
            throw .ratesUnavailable(error)
        case .rates:
            throw .ratesUnavailable(nil)
        }
    }
}
