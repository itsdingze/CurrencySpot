import Foundation

nonisolated struct HistoricalRatesResponse: Codable, Sendable {
    let base: String
    let startDate: String
    let endDate: String
    let rates: [String: [String: Double]]

    private enum CodingKeys: String, CodingKey {
        case base
        case startDate = "start_date"
        case endDate = "end_date"
        case rates
    }
}
