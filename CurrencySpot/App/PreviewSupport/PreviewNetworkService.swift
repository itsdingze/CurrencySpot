#if DEBUG

    import Foundation

    final class PreviewNetworkService: NetworkService {
        private let today: Date
        private var lastFetch: Date?

        init(today: Date = Date()) {
            self.today = today
        }

        func shouldFetchNewRates() async -> Bool {
            false
        }

        func fetchExchangeRates() async throws -> ExchangeRatesResponse {
            ExchangeRatesResponse(
                base: CurrencyCode.usd.rawValue,
                date: TimeZoneManager.formatForAPI(today),
                rates: Self.sampleRates
            )
        }

        func fetchHistoricalRates(from startDate: Date, to endDate: Date) async throws -> HistoricalRatesResponse {
            try await fetchHistoricalRates(from: startDate, to: endDate, quotes: [])
        }

        func fetchHistoricalRates(from startDate: Date, to endDate: Date, quotes: [String]) async throws -> HistoricalRatesResponse {
            let calendar = TimeZoneManager.cetCalendar
            let requested = quotes.isEmpty ? Set(Self.sampleRates.keys) : Set(quotes)
            var rates: [String: [String: Double]] = [:]

            var day = calendar.startOfDay(for: startDate)
            let last = calendar.startOfDay(for: endDate)
            var offset = 0
            while day <= last {
                let drift = 0.95 + Double(offset) / 290.0
                rates[TimeZoneManager.formatForAPI(day)] = Self.sampleRates
                    .filter { requested.contains($0.key) }
                    .mapValues { $0 * drift }
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
                offset += 1
            }

            return HistoricalRatesResponse(
                base: CurrencyCode.usd.rawValue,
                startDate: TimeZoneManager.formatForAPI(startDate),
                endDate: TimeZoneManager.formatForAPI(endDate),
                rates: rates
            )
        }

        func updateLastFetchDate(_ date: Date) {
            lastFetch = date
        }

        func getLastFetchDate() -> Date? {
            lastFetch
        }

        private static let sampleRates: [String: Double] = Dictionary(
            uniqueKeysWithValues: SampleExchangeRates.rates.map { ($0.key.rawValue, $0.value) }
        )
    }

#endif
