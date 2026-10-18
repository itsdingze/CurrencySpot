@testable import CurrencySpot
import Foundation
import Testing

@Suite("ManageFavoritesUseCase Tests")
struct ManageFavoritesUseCaseTests {
    private let isolatedDefaults = IsolatedDefaults()
    private let favorites: CurrencyCodeListStore
    private let useCase: ManageFavoritesUseCase

    init() throws {
        favorites = CurrencyCodeListStore(
            defaults: try isolatedDefaults.make(),
            key: UserDefaultsKeys.favoriteCurrencies,
            seed: ["USD", "EUR", "GBP", "JPY"]
        )
        useCase = ManageFavoritesUseCase(favorites: favorites)
    }

    @Test("removing displayed offsets removes the codes shown at those rows")
    func removesCodesAtDisplayedOffsets() {
        useCase.remove(atOffsets: IndexSet([0, 2]))

        #expect(useCase.favorites == ["EUR", "JPY"])
    }

    @Test("moving rows reorders the favorites")
    func movesRows() {
        useCase.move(fromOffsets: IndexSet(integer: 3), toOffset: 0)

        #expect(useCase.favorites == ["JPY", "USD", "EUR", "GBP"])
    }

    @Test("adding appends a new favorite once")
    func addsOnce() {
        useCase.add("CHF")
        useCase.add("CHF")

        #expect(useCase.favorites == ["USD", "EUR", "GBP", "JPY", "CHF"])
    }

    @Test("addable currencies leave out every favorite, sorted by code")
    func addableCurrenciesExcludeFavorites() {
        let rates = [
            ExchangeRate(currencyCode: "NZD", rate: 1.6),
            ExchangeRate(currencyCode: "USD", rate: 1),
            ExchangeRate(currencyCode: "CHF", rate: 0.9),
            ExchangeRate(currencyCode: "EUR", rate: 0.92),
        ]

        let addable = useCase.addableCurrencies(from: rates, matching: "")

        #expect(addable.map(\.currencyCode) == ["CHF", "NZD"])
    }

    @Test("a search for a favorite's code finds nothing to add")
    func searchingAFavoriteFindsNothing() {
        let rates = [
            ExchangeRate(currencyCode: "USD", rate: 1),
            ExchangeRate(currencyCode: "NZD", rate: 1.6),
        ]

        #expect(useCase.addableCurrencies(from: rates, matching: "USD").isEmpty)
        #expect(useCase.addableCurrencies(from: rates, matching: "NZD").map(\.currencyCode) == ["NZD"])
    }
}
