#if DEBUG

    import Foundation

    final class PreviewNetworkService: NetworkService {
        private let today: Date

        init(today: Date = Date()) {
            self.today = today
        }

        func fetchExchangeRates() async throws -> ExchangeRatesResponse {
            ExchangeRatesResponse(
                base: CurrencyCode.usd.rawValue,
                date: CETCalendar.dayString(for: today),
                rates: Self.sampleRates
            )
        }

        func fetchHistoricalRates(from startDate: Date, to endDate: Date) async throws -> HistoricalRatesResponse {
            try await fetchHistoricalRates(from: startDate, to: endDate, quotes: [])
        }

        func fetchHistoricalRates(from startDate: Date, to endDate: Date, quotes: [String]) async throws -> HistoricalRatesResponse {
            let calendar = CETCalendar.calendar
            let requested = quotes.isEmpty ? Set(Self.sampleRates.keys) : Set(quotes)
            var rates: [String: [String: Double]] = [:]

            var day = calendar.startOfDay(for: startDate)
            let last = calendar.startOfDay(for: endDate)
            var offset = 0
            while day <= last {
                let drift = 0.95 + Double(offset) / 290.0
                rates[CETCalendar.dayString(for: day)] = Self.sampleRates
                    .filter { requested.contains($0.key) }
                    .mapValues { $0 * drift }
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
                offset += 1
            }

            return HistoricalRatesResponse(
                base: CurrencyCode.usd.rawValue,
                startDate: CETCalendar.dayString(for: startDate),
                endDate: CETCalendar.dayString(for: endDate),
                rates: rates
            )
        }

        private static let sampleRates: [String: Double] = Dictionary(
            uniqueKeysWithValues: SampleExchangeRates.rates.map { ($0.key.rawValue, $0.value) }
        )
    }

#endif
