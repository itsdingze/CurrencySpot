import AppIntents
import Foundation

nonisolated struct CurrencyEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "intent.currency.type"
    static let defaultQuery = CurrencyEntityQuery()

    let code: CurrencyCode
    private let isConvertedTo: Bool

    init(code: CurrencyCode) {
        self.init(code: code, isConvertedTo: false)
    }

    private init(code: CurrencyCode, isConvertedTo: Bool) {
        self.code = code
        self.isConvertedTo = isConvertedTo
    }

    static func convertedTo(_ code: CurrencyCode) -> CurrencyEntity {
        CurrencyEntity(code: code, isConvertedTo: true)
    }

    var id: String { code.rawValue }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: title,
            subtitle: "\(code.uncachedLocalizedName)",
            synonyms: ["\(code.uncachedLocalizedName)"]
        )
    }

    private var title: LocalizedStringResource {
        isConvertedTo ? .intentCurrencyConvertTo(currency: code.rawValue) : "\(code.rawValue)"
    }
}

nonisolated struct CurrencyEntityQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [CurrencyEntity] {
        identifiers.compactMap { CurrencyCode($0) }.map(CurrencyEntity.init)
    }

    func entities(matching string: String) async throws -> [CurrencyEntity] {
        await CurrencyCatalog.search(string, in: .appGroup).map(CurrencyEntity.init)
    }

    func suggestedEntities() async throws -> [CurrencyEntity] {
        await MainActor.run { CurrencyCatalog.suggested(in: .appGroup) }.map(CurrencyEntity.init)
    }
}

nonisolated struct FavoriteCurrencyOptions: DynamicOptionsProvider {
    func results() async throws -> [CurrencyEntity] {
        try await CurrencyEntityQuery().suggestedEntities().map { .convertedTo($0.code) }
    }
}
