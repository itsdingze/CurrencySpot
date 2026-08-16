import Foundation

// MARK: - LoadExchangeRatesUseCase

struct LoadExchangeRatesUseCase {
    enum Outcome: Equatable {
        case rates([ExchangeRate], lastUpdated: Date?, refreshFailed: Bool)
        case unavailable(AppError?)
    }

    private let repository: ExchangeRateRepository

    init(repository: ExchangeRateRepository) {
        self.repository = repository
    }

    func shouldRefresh() async -> Bool {
        await repository.shouldRefreshRates()
    }

    func shouldRefreshOnReconnect(hasRates: Bool, isShowingSample: Bool, lastRefreshFailed: Bool) async -> Bool {
        if !hasRates || isShowingSample || lastRefreshFailed { return true }
        return await shouldRefresh()
    }

    func refresh() async -> Outcome {
        do {
            let rates = try await repository.fetchExchangeRates()
            return .rates(rates, lastUpdated: repository.lastFetchDate(), refreshFailed: false)
        } catch {
            return await saved(surfacing: AppError.from(error))
        }
    }

    func saved(surfacing pendingError: AppError? = nil) async -> Outcome {
        do {
            let rates = try await repository.loadExchangeRates()
            return .rates(rates, lastUpdated: repository.lastFetchDate(), refreshFailed: pendingError != nil)
        } catch {
            return .unavailable(pendingError ?? AppError.from(error))
        }
    }

    func sampleRates() -> [ExchangeRate] {
        SampleExchangeRates.getCurrencyRates()
    }
}
