import Foundation

nonisolated struct CurrencyListEntry: Identifiable, Equatable, Sendable {
    let code: CurrencyCode
    let name: String
    let rate: Double

    var id: CurrencyCode { code }
}
