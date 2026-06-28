//
//  WatchlistStore.swift
//  CurrencySpot
//

import Foundation
import IdentifiedCollections
import Observation

// MARK: - WatchlistStore

/// The ordered list of currencies shown on the History tab, persisted across
/// launches. Independent of the Settings favorites — it seeds from them on first
/// launch, then is edited on its own.
@Observable
final class WatchlistStore {
    /// Keyed by the code itself so membership and removal are ID-based, while the
    /// array order is the user's manual drag order.
    private(set) var codes: IdentifiedArray<String, String>

    private let userDefaults: UserDefaults

    /// First launch seeds from `seed`, else the persisted Settings favorites, else
    /// the default — then persists so later launches read it independently.
    init(
        userDefaults: UserDefaults = .standard,
        seed: [String]? = nil
    ) {
        self.userDefaults = userDefaults

        if let persisted = userDefaults.stringArray(forKey: UserDefaultsKeys.historyWatchlist) {
            codes = Self.identified(persisted)
        } else {
            let initial = seed
                ?? userDefaults.stringArray(forKey: UserDefaultsKeys.favoriteCurrencies)
                ?? CurrencyDefaults.favoriteCurrencies
            codes = Self.identified(initial)
            userDefaults.set(codes.elements, forKey: UserDefaultsKeys.historyWatchlist)
        }
    }

    // MARK: - Queries

    func contains(_ code: String) -> Bool {
        codes[id: code] != nil
    }

    // MARK: - Mutations

    /// Appends a valid, non-duplicate code. Returns whether it was added.
    @discardableResult
    func add(_ code: String) -> Bool {
        guard CurrencyCode(code) != nil else { return false }

        // append(_:) is a no-op when the ID is already present.
        let (inserted, _) = codes.append(code)
        if inserted { persist() }
        return inserted
    }

    /// Removes a code by identity. Returns whether it was present.
    @discardableResult
    func remove(_ code: String) -> Bool {
        let removed = codes.remove(id: code) != nil
        if removed { persist() }
        return removed
    }

    func toggle(_ code: String) {
        if contains(code) {
            remove(code)
        } else {
            add(code)
        }
    }

    /// Replaces the entire watchlist with `seed` and persists it. Drives the
    /// Settings "Reset Preferences" action, which re-seeds from the just-reset
    /// default favorites.
    func reset(to seed: [String]) {
        codes = Self.identified(seed)
        persist()
    }

    /// Reorders the subset of codes named in `displayedOrder` to that order,
    /// leaving any code NOT in `displayedOrder` (e.g. the hidden base currency,
    /// or a code absent from the current rates) in its existing slot. Lets the
    /// History list drive reordering from its base-excluded view without the
    /// hidden rows shifting underneath it.
    func reorder(displayedOrder: [String]) {
        let displayed = Set(displayedOrder)
        var next = displayedOrder.makeIterator()
        let merged = codes.elements.map { code in
            displayed.contains(code) ? (next.next() ?? code) : code
        }
        codes = Self.identified(merged)
        persist()
    }

    // MARK: - Helpers

    private func persist() {
        userDefaults.set(codes.elements, forKey: UserDefaultsKeys.historyWatchlist)
    }

    /// Builds the collection dropping duplicates; `init(uniqueElements:)` would
    /// trap on the duplicates older persisted data can contain.
    private static func identified(_ codes: [String]) -> IdentifiedArray<String, String> {
        var array = IdentifiedArray<String, String>(id: \.self)
        for code in codes {
            array.append(code)
        }
        return array
    }
}
