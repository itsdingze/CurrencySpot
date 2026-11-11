import Foundation
import Observation

@Observable
final class HistoryBaseCurrencyStore {
    private(set) var pickedBase: CurrencyCode?

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
        pickedBase = defaults.string(forKey: UserDefaultsKeys.historyBaseCurrency).flatMap { CurrencyCode($0) }
    }

    func pick(_ code: CurrencyCode) {
        pickedBase = code
        defaults.set(code.rawValue, forKey: UserDefaultsKeys.historyBaseCurrency)
    }

    func clear() {
        pickedBase = nil
        defaults.removeObject(forKey: UserDefaultsKeys.historyBaseCurrency)
    }
}
