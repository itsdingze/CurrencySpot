import Foundation
import IdentifiedCollections

// MARK: - ManageFavoritesUseCase

final class ManageFavoritesUseCase {
    private let favoritesStore: CurrencyCodeListStore

    init(favorites: CurrencyCodeListStore) {
        favoritesStore = favorites
    }

    var favorites: [CurrencyCode] {
        favoritesStore.codes.elements
    }

    func add(_ code: CurrencyCode) {
        favoritesStore.add(code)
    }

    func remove(atOffsets offsets: IndexSet) {
        let codes = offsets.map { favoritesStore.codes[$0] }
        for code in codes {
            favoritesStore.remove(code)
        }
    }

    func move(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        favoritesStore.move(fromOffsets: offsets, toOffset: destination)
    }

    func addableCurrencies(from rates: [ExchangeRate], matching searchText: String) -> [ExchangeRate] {
        CurrencySearch.results(
            in: rates,
            excluding: Set(favoritesStore.codes),
            matching: searchText
        )
    }
}
