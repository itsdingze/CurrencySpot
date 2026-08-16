import Foundation

nonisolated struct ExchangeRatesResponse: Codable, Sendable {
    let base: String
    let date: String
    let rates: [String: Double]
}
