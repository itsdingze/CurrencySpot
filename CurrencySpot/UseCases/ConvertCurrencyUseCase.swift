import Foundation

final class ConvertCurrencyUseCase {
    struct Conversion: Equatable {
        let amount: Decimal
        let from: CurrencyCode
        let to: CurrencyCode
        let converted: Decimal
        let ratesDate: Date?
    }

    enum Failure: Error, Equatable {
        case ratesUnavailable(AppError?)
        case noRate(CurrencyCode)
    }

    private struct DatedRates {
        let table: RateTable
        let date: Date?

        init?(_ outcome: LoadExchangeRatesUseCase.Outcome) {
            guard case let .rates(rates, lastUpdated, _) = outcome, !rates.isEmpty else { return nil }
            table = RateTable(rates)
            date = lastUpdated
        }
    }

    private let loadExchangeRates: LoadExchangeRatesUseCase
    private let clock: ClockService
    private let refreshBudget: Duration = .seconds(4)

    init(loadExchangeRates: LoadExchangeRatesUseCase, clock: ClockService) {
        self.loadExchangeRates = loadExchangeRates
        self.clock = clock
    }

    func callAsFunction(amount: Decimal, from: CurrencyCode, to: CurrencyCode) async throws(Failure) -> Conversion {
        let rates = try await datedRates()
        for currency in [from, to] where rates.table.usdRate(for: currency) == nil {
            throw .noRate(currency)
        }
        return Conversion(
            amount: amount,
            from: from,
            to: to,
            converted: rates.table.convert(amount, from: from, to: to),
            ratesDate: rates.date
        )
    }

    private func datedRates() async throws(Failure) -> DatedRates {
        let isStale = await loadExchangeRates.shouldRefresh()
        let saved = DatedRates(await loadExchangeRates.saved())
        if let saved, !isStale { return saved }
        let outcome = await refreshed(givingUpAfterBudget: saved != nil)
        if let refreshed = DatedRates(outcome) { return refreshed }
        if case let .unavailable(error) = outcome { throw .ratesUnavailable(error) }
        throw .ratesUnavailable(nil)
    }

    private func refreshed(givingUpAfterBudget: Bool) async -> LoadExchangeRatesUseCase.Outcome {
        let refreshing = Task { await loadExchangeRates.refresh() }
        guard givingUpAfterBudget else { return await refreshing.value }
        let deadline = Task { [clock, refreshBudget] in
            try await clock.sleep(for: refreshBudget)
            refreshing.cancel()
        }
        defer { deadline.cancel() }
        return await refreshing.value
    }
}
