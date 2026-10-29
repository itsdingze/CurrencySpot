import AppIntents
import Foundation

nonisolated struct CurrencyEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "intent.currency.type"
    static let defaultQuery = CurrencyEntityQuery()

    let code: CurrencyCode

    var id: String { code.rawValue }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(code.rawValue)",
            subtitle: "\(code.uncachedLocalizedName)",
            synonyms: ["\(code.uncachedLocalizedName)"]
        )
    }
}

nonisolated struct CurrencyEntityQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [CurrencyEntity] {
        identifiers.compactMap { CurrencyCode($0) }.map(CurrencyEntity.init)
    }

    func entities(matching string: String) async throws -> [CurrencyEntity] {
        await CurrencyCatalog.search(string).map(CurrencyEntity.init)
    }

    func suggestedEntities() async throws -> [CurrencyEntity] {
        await MainActor.run { CurrencyCatalog.suggested(in: .standard) }.map(CurrencyEntity.init)
    }
}
