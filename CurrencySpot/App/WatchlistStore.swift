import Foundation
import IdentifiedCollections
import Observation

// MARK: - WatchlistStore

@Observable
final class WatchlistStore {
    private(set) var codes: CurrencyCodeList

    private let userDefaults: UserDefaults

    init(
        userDefaults: UserDefaults = .standard,
        seed: [CurrencyCode]? = nil
    ) {
        self.userDefaults = userDefaults

        if let persisted = userDefaults.stringArray(forKey: UserDefaultsKeys.historyWatchlist) {
            codes = CurrencyCodeList.deduplicating(persisted.compactMap { CurrencyCode($0) })
        } else {
            let initial = seed
                ?? userDefaults.stringArray(forKey: UserDefaultsKeys.favoriteCurrencies)?.compactMap { CurrencyCode($0) }
                ?? CurrencyDefaults.favoriteCurrencies
            codes = CurrencyCodeList.deduplicating(initial)
            persist()
        }
    }

    // MARK: - Queries

    func contains(_ code: CurrencyCode) -> Bool {
        codes[id: code] != nil
    }

    // MARK: - Mutations

    @discardableResult
    func add(_ code: CurrencyCode) -> Bool {
        let (inserted, _) = codes.append(code)
        if inserted { persist() }
        return inserted
    }

    @discardableResult
    func remove(_ code: CurrencyCode) -> Bool {
        let removed = codes.remove(id: code) != nil
        if removed { persist() }
        return removed
    }

    func toggle(_ code: CurrencyCode) {
        if contains(code) {
            remove(code)
        } else {
            add(code)
        }
    }

    func reset(to seed: [CurrencyCode]) {
        codes = CurrencyCodeList.deduplicating(seed)
        persist()
    }

    func reorder(displayedOrder: [CurrencyCode]) {
        let displayed = Set(displayedOrder)
        var next = displayedOrder.makeIterator()
        let merged = codes.elements.map { code in
            displayed.contains(code) ? (next.next() ?? code) : code
        }
        codes = CurrencyCodeList.deduplicating(merged)
        persist()
    }

    // MARK: - Helpers

    private func persist() {
        userDefaults.set(codes.map(\.rawValue), forKey: UserDefaultsKeys.historyWatchlist)
    }
}
