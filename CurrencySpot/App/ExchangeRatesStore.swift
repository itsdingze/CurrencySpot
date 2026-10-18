import Foundation
import Observation

// MARK: - ExchangeRatesStore

@Observable
final class ExchangeRatesStore {
    private(set) var rates: [ExchangeRate] = []
    private(set) var lastUpdated: Date?
    private(set) var isShowingSampleRates = false

    private(set) var baseCurrency: CurrencyCode = .usd

    func update(rates: [ExchangeRate], lastUpdated: Date?, isShowingSampleRates: Bool) {
        self.rates = rates
        self.lastUpdated = lastUpdated
        self.isShowingSampleRates = isShowingSampleRates
    }

    func updateBaseCurrency(_ currency: CurrencyCode) {
        baseCurrency = currency
    }
}
