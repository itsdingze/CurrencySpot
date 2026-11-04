@testable import CurrencySpot
import AppIntents
import Foundation
import Testing

@Suite("CurrencyEntity")
struct CurrencyEntityTests {
    @Test("Spotlight's one-tap Convert shortcuts read To and the currency, while the pickers keep the plain code")
    func shortcutOptionsNameTheCurrencyConvertedTo() async throws {
        let options = try await FavoriteCurrencyOptions().results()
        let suggestions = try await CurrencyEntityQuery().suggestedEntities()
        try #require(!suggestions.isEmpty)

        #expect(options.map(\.id) == suggestions.map(\.id))
        #expect(options.map { Self.english($0.displayRepresentation.title) } == suggestions.map { "To \($0.id)" })
        #expect(suggestions.map { Self.english($0.displayRepresentation.title) } == suggestions.map(\.id))
    }

    private static func english(_ resource: LocalizedStringResource) -> String {
        var resource = resource
        resource.locale = Locale(identifier: "en")
        return String(localized: resource)
    }
}
