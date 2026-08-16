import Foundation

nonisolated struct FrankfurterV2Rate: Codable, Sendable {
    let date: String
    let base: String
    let quote: String
    let rate: Double
}
