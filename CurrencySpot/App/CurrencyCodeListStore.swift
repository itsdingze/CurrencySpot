import Foundation
import IdentifiedCollections
import Observation

// MARK: - CurrencyCodeListStore

@Observable
final class CurrencyCodeListStore {
    private(set) var codes: CurrencyCodeList

    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults, key: String, seed: [CurrencyCode]) {
        self.defaults = defaults
        self.key = key

        if let persisted = defaults.stringArray(forKey: key) {
            codes = .deduplicating(persisted.compactMap { CurrencyCode($0) })
        } else {
            codes = .deduplicating(seed)
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
        codes = .deduplicating(seed)
        persist()
    }

    func reorder(displayedOrder: [CurrencyCode]) {
        let displayed = Set(displayedOrder)
        var next = displayedOrder.makeIterator()
        let merged = codes.elements.map { code in
            displayed.contains(code) ? (next.next() ?? code) : code
        }
        codes = .deduplicating(merged)
        persist()
    }

    func move(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        codes.move(fromOffsets: offsets, toOffset: destination)
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        defaults.set(codes.map(\.rawValue), forKey: key)
    }
}

// MARK: - Favorites and Watchlist

extension CurrencyCodeListStore {
    static func favorites(in defaults: UserDefaults) -> CurrencyCodeListStore {
        CurrencyCodeListStore(
            defaults: defaults,
            key: UserDefaultsKeys.favoriteCurrencies,
            seed: CurrencyDefaults.favoriteCurrencies
        )
    }

    static func watchlist(in defaults: UserDefaults, seededFrom favorites: CurrencyCodeListStore) -> CurrencyCodeListStore {
        CurrencyCodeListStore(
            defaults: defaults,
            key: UserDefaultsKeys.historyWatchlist,
            seed: favorites.codes.elements
        )
    }
}
