@testable import CurrencySpot
import Foundation
import Testing

@Suite("CurrencyHistoryViewModel Tests")
struct CurrencyHistoryViewModelTests {
    @Test("starts on the requested pair with no chart, an empty series and placeholder statistics")
    func initialState() throws {
        let viewModel = try HistoryTestGraph().makeHistoryViewModel(base: "USD", target: "GBP")

        #expect(viewModel.baseCurrency == "USD")
        #expect(viewModel.targetCurrency == "GBP")
        #expect(viewModel.selectedTimeRange == .threeMonths)
        #expect(viewModel.chartData == .idle)
        #expect(viewModel.displayedChartDataPoints.isEmpty)
        Self.expectNoStatistics(viewModel, header: "1 USD = — GBP")
    }

    @Test("loading the chart passes through .loading before landing on .loaded", .timeLimit(.minutes(1)))
    func loadPassesThroughLoading() async throws {
        let repository = MockHistoricalRateRepository()
        let gate = AsyncGate()
        repository.fetchBarrier = { await gate.wait() }
        let graph = try HistoryTestGraph(historicalRepository: repository)
        repository.fetchedDataToReturn = try Self.snapshots(rates: [1, 2, 3], endingBefore: graph.today)
        let viewModel = graph.makeHistoryViewModel()

        let load = Task { await viewModel.loadChart() }
        await waitUntil { repository.fetchHistoricalRatesCallCount == 1 }
        #expect(viewModel.chartData == .loading(previous: nil))

        gate.open()
        await load.value

        let points = try #require(viewModel.chartData.value)
        #expect(points.map(\.rate) == [1, 2, 3])
        #expect(viewModel.displayedChartDataPoints == points)
    }

    @Test("loading again after a completed load keeps the shown chart", .timeLimit(.minutes(1)))
    func repeatedLoadKeepsChart() async throws {
        let repository = MockHistoricalRateRepository()
        let graph = try HistoryTestGraph(historicalRepository: repository)
        repository.fetchedDataToReturn = try Self.snapshots(rates: [1, 2, 3], endingBefore: graph.today)
        let viewModel = graph.makeHistoryViewModel()
        await viewModel.loadChart()

        repository.fetchedDataToReturn = try Self.snapshots(rates: [4, 5, 6], endingBefore: graph.today)
        await viewModel.loadChart()

        #expect(viewModel.chartData.value?.map(\.rate) == [1, 2, 3])
    }

    @Test("picking another time range reloads the chart for that range", .timeLimit(.minutes(1)))
    func timeRangeChangeReloads() async throws {
        let viewModel = try HistoryTestGraph().makeHistoryViewModel()
        await viewModel.loadChart()

        viewModel.selectedTimeRange = .oneMonth

        await waitUntil {
            if case let .loaded(points) = viewModel.chartData {
                return !points.isEmpty && viewModel.chartSeriesID.range == .oneMonth
            }
            return false
        }
    }

    @Test("picking the current time range again leaves the chart alone")
    func sameTimeRangeIsNoOp() throws {
        let viewModel = try HistoryTestGraph().makeHistoryViewModel()

        viewModel.selectedTimeRange = .threeMonths

        #expect(viewModel.chartData == .idle)
    }

    @Test("a failed 5Y load shows the inline failure instead of the resident year and raises no global alert", .timeLimit(.minutes(1)))
    func archiveFailureIsInlineOnly() async throws {
        let repository = MockHistoricalRateRepository()
        repository.shouldThrowErrorOnFetch = true
        let graph = try HistoryTestGraph(historicalRepository: repository)
        repository.seedSeries(try Self.snapshots(rates: [0.9], endingBefore: graph.today))
        let viewModel = graph.makeHistoryViewModel()

        viewModel.selectedTimeRange = .fiveYears

        await waitUntil { viewModel.chartData.error != nil }
        #expect(graph.appState.errorHandler.currentError == nil)
    }

    @Test("a failed load with nothing to show shows the inline failure and raises no global alert", .timeLimit(.minutes(1)))
    func residentFailureIsInlineOnly() async throws {
        let repository = MockHistoricalRateRepository()
        repository.shouldThrowErrorOnFetch = true
        let graph = try HistoryTestGraph(historicalRepository: repository)
        let viewModel = graph.makeHistoryViewModel()

        await viewModel.loadChart()

        #expect(viewModel.chartData.error != nil)
        #expect(graph.appState.errorHandler.currentError == nil)
    }

    @Test("retrying after a failure loads the chart", .timeLimit(.minutes(1)))
    func retryAfterFailureLoads() async throws {
        let repository = MockHistoricalRateRepository()
        repository.shouldThrowErrorOnFetch = true
        let graph = try HistoryTestGraph(historicalRepository: repository)
        let viewModel = graph.makeHistoryViewModel()
        viewModel.selectedTimeRange = .fiveYears
        await waitUntil { viewModel.chartData.error != nil }

        repository.shouldThrowErrorOnFetch = false
        repository.transientDataToReturn = try Self.snapshots(rates: [1, 2, 3], endingBefore: graph.today)
        viewModel.retry()

        await waitUntil {
            if case let .loaded(points) = viewModel.chartData { return !points.isEmpty }
            return false
        }
    }

    @Test("statistics are formatted for display from the loaded series", .timeLimit(.minutes(1)))
    func statisticsFormatting() async throws {
        let repository = MockHistoricalRateRepository()
        let graph = try HistoryTestGraph(historicalRepository: repository)
        repository.fetchedDataToReturn = try Self.snapshots(rates: [1, 2, 3], endingBefore: graph.today)
        let viewModel = graph.makeHistoryViewModel(base: "USD", target: "EUR")

        await viewModel.loadChart()

        #expect(viewModel.formattedCurrentRate == "1 USD = 3 EUR")
        #expect(viewModel.formattedHighestRate == "3")
        #expect(viewModel.formattedLowestRate == "1")
        #expect(viewModel.formattedAverageRate == "2")
        #expect(viewModel.volatilityLevel == .veryHigh)
        #expect(viewModel.formattedVolatility == "Very High")
    }

    @Test("while the first load runs, the header and statistics show placeholders, not zero rates", .timeLimit(.minutes(1)))
    func loadingShowsPlaceholders() async throws {
        let repository = MockHistoricalRateRepository()
        let gate = AsyncGate()
        repository.fetchBarrier = { await gate.wait() }
        let graph = try HistoryTestGraph(historicalRepository: repository)
        repository.fetchedDataToReturn = try Self.snapshots(rates: [1, 2, 3], endingBefore: graph.today)
        let viewModel = graph.makeHistoryViewModel(base: "USD", target: "EUR")

        let load = Task { await viewModel.loadChart() }
        await waitUntil { repository.fetchHistoricalRatesCallCount == 1 }

        #expect(viewModel.chartData == .loading(previous: nil))
        Self.expectNoStatistics(viewModel)
        gate.open()
        await load.value
    }

    @Test("a failed first load shows placeholders, not zero rates", .timeLimit(.minutes(1)))
    func failedLoadShowsPlaceholders() async throws {
        let repository = MockHistoricalRateRepository()
        repository.shouldThrowErrorOnFetch = true
        let viewModel = try HistoryTestGraph(historicalRepository: repository).makeHistoryViewModel(base: "USD", target: "EUR")

        await viewModel.loadChart()

        #expect(viewModel.chartData.error != nil)
        Self.expectNoStatistics(viewModel)
    }

    @Test("a load that finds no days shows placeholders, not zero rates", .timeLimit(.minutes(1)))
    func emptyLoadShowsPlaceholders() async throws {
        let repository = MockHistoricalRateRepository()
        let viewModel = try HistoryTestGraph(historicalRepository: repository).makeHistoryViewModel(base: "USD", target: "EUR")

        await viewModel.loadChart()

        #expect(viewModel.chartData == .loaded([]))
        Self.expectNoStatistics(viewModel)
    }

    @Test("a single loaded day shows its rate, and volatility reads N/A rather than the no-data placeholder", .timeLimit(.minutes(1)))
    func singleDayShowsRateAndUnavailableVolatility() async throws {
        let repository = MockHistoricalRateRepository()
        let graph = try HistoryTestGraph(historicalRepository: repository)
        repository.fetchedDataToReturn = try Self.snapshots(rates: [2], endingBefore: graph.today)
        let viewModel = graph.makeHistoryViewModel(base: "USD", target: "EUR")

        await viewModel.loadChart()

        #expect(viewModel.formattedCurrentRate == "1 USD = 2 EUR")
        #expect(String(localized: viewModel.currentRateAccessibilityLabel) == "Current rate: 1 USD = 2 EUR")
        #expect(viewModel.formattedHighestRate == "2")
        #expect(viewModel.formattedLowestRate == "2")
        #expect(viewModel.formattedAverageRate == "2")
        #expect(viewModel.formattedVolatility == "N/A")
    }

    @Test("volatility describes the full daily series, not the downsampled chart line", .timeLimit(.minutes(1)))
    func volatilityUsesFullSeries() async throws {
        let repository = MockHistoricalRateRepository()
        repository.fetchedDataProvider = { from, to in
            Self.randomWalk(from: from, to: to, dailyMove: 0.0025)
        }
        let viewModel = try HistoryTestGraph(historicalRepository: repository).makeHistoryViewModel()

        viewModel.selectedTimeRange = .oneYear

        await waitUntil {
            if case let .loaded(points) = viewModel.chartData {
                return !points.isEmpty && viewModel.chartSeriesID.range == .oneYear
            }
            return false
        }
        #expect(viewModel.volatilityLevel == .veryLow)
    }

    @Test("chartSeriesID changes only when a new series' points land, not at selection time", .timeLimit(.minutes(1)))
    func chartSeriesIDFollowsThePoints() async throws {
        let viewModel = try HistoryTestGraph().makeHistoryViewModel()
        await viewModel.loadChart()
        let initialSeries = viewModel.chartSeriesID
        #expect(initialSeries.range == .threeMonths)

        viewModel.selectedTimeRange = .oneMonth
        #expect(viewModel.chartSeriesID == initialSeries)

        await waitUntil {
            if case .loaded = viewModel.chartData { return viewModel.chartSeriesID != initialSeries }
            return false
        }
        #expect(viewModel.chartSeriesID.range == .oneMonth)
    }

    @Test("follows the calculator's base currency and reloads for it", .timeLimit(.minutes(1)))
    func followsSharedBaseCurrency() async throws {
        let graph = try HistoryTestGraph()
        let viewModel = graph.makeHistoryViewModel(base: "USD", target: "GBP")
        await viewModel.loadChart()

        graph.ratesStore.updateBaseCurrency("EUR")

        await waitUntil { viewModel.baseCurrency == "EUR" }
        await waitUntil {
            if case .loaded = viewModel.chartData { return true }
            return false
        }
    }

    @Test("a data reset drops the shown chart and loads it again", .timeLimit(.minutes(1)))
    func dataResetReloadsChart() async throws {
        let repository = MockHistoricalRateRepository()
        let graph = try HistoryTestGraph(historicalRepository: repository)
        repository.fetchedDataToReturn = try Self.snapshots(rates: [1, 2, 3], endingBefore: graph.today)
        let viewModel = graph.makeHistoryViewModel()
        await viewModel.loadChart()
        let fetchesBeforeReset = repository.fetchHistoricalRatesCallCount
        let gate = AsyncGate()
        repository.fetchBarrier = { await gate.wait() }
        repository.seedSeries([])

        graph.appState.dataWasReset()

        await waitUntil { repository.fetchHistoricalRatesCallCount > fetchesBeforeReset }
        #expect(viewModel.chartData == .loading(previous: nil))
        gate.open()
        await waitUntil {
            if case let .loaded(points) = viewModel.chartData { return !points.isEmpty }
            return false
        }
    }

    @Test("a load that fetches new days refreshes the shared trends", .timeLimit(.minutes(1)))
    func newDataRefreshesTrends() async throws {
        let graph = try HistoryTestGraph()
        let viewModel = graph.makeHistoryViewModel()
        #expect(graph.trendsStore.trends.isEmpty)

        await viewModel.loadChart()

        #expect(graph.trendsStore.trends.count == SampleExchangeRates.trendData.count)
    }

    @Test("chart onboarding stays dismissed once the stored flag says it has been seen")
    func chartOnboardingSkippedWhenSeen() async throws {
        let graph = try HistoryTestGraph(preferences: InMemoryPreferencesStore(hasSeenChartOnboarding: true))
        let viewModel = graph.makeHistoryViewModel()

        await viewModel.presentChartOnboardingIfNeeded()

        #expect(viewModel.destination == nil)
    }

    @Test("chart onboarding presents on first visit and completing it records the flag")
    func chartOnboardingPresentsThenCompletes() async throws {
        let graph = try HistoryTestGraph()
        let viewModel = graph.makeHistoryViewModel()

        await viewModel.presentChartOnboardingIfNeeded()
        #expect(viewModel.destination == .chartOnboarding)

        viewModel.completeChartOnboarding()
        #expect(viewModel.destination == nil)
        #expect(graph.preferences.hasSeenChartOnboarding == true)
    }

    @Test("tapping the volatility info opens its popover")
    func volatilityInfoOpens() throws {
        let viewModel = try HistoryTestGraph().makeHistoryViewModel()

        viewModel.volatilityInfoTapped()

        #expect(viewModel.destination == .volatilityInfo)
    }

    // MARK: - Fixtures

    private static func expectNoStatistics(
        _ viewModel: CurrencyHistoryViewModel,
        header: String = "1 USD = — EUR",
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(viewModel.formattedCurrentRate == header, sourceLocation: sourceLocation)
        #expect(String(localized: viewModel.currentRateAccessibilityLabel) == "Current rate: not available", sourceLocation: sourceLocation)
        #expect(viewModel.formattedHighestRate == nil, sourceLocation: sourceLocation)
        #expect(viewModel.formattedLowestRate == nil, sourceLocation: sourceLocation)
        #expect(viewModel.formattedAverageRate == nil, sourceLocation: sourceLocation)
        #expect(viewModel.formattedVolatility == nil, sourceLocation: sourceLocation)
    }

    private static func snapshots(rates: [Double], endingBefore today: Date) throws -> [HistoricalRateSnapshot] {
        let calendar = CETCalendar.calendar
        return try rates.enumerated().map { offset, rate in
            let date = try #require(calendar.date(byAdding: .day, value: offset - rates.count, to: today))
            return HistoricalRateSnapshot(date: date, rates: [HistoricalRatePoint(currencyCode: "EUR", rate: rate)])
        }
    }

    private static func randomWalk(from: Date, to: Date, dailyMove: Double) -> [HistoricalRateSnapshot] {
        let calendar = CETCalendar.calendar
        var state: UInt64 = 42
        var rate = 1.0
        var day = calendar.startOfDay(for: from)
        var snapshots: [HistoricalRateSnapshot] = []
        while day <= to {
            snapshots.append(HistoricalRateSnapshot(date: day, rates: [HistoricalRatePoint(currencyCode: "EUR", rate: rate)]))
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            rate *= (state >> 33) & 1 == 0 ? 1 + dailyMove : 1 - dailyMove
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return snapshots
    }
}

private final class AsyncGate {
    private let continuation: AsyncStream<Void>.Continuation
    private let gate: Task<Void, Never>

    init() {
        let (stream, continuation) = AsyncStream.makeStream(of: Void.self)
        self.continuation = continuation
        gate = Task { for await _ in stream {} }
    }

    func wait() async {
        await gate.value
    }

    func open() {
        continuation.finish()
    }
}
