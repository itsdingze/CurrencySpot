import Foundation

// MARK: - DataCoordinator

final class DataCoordinator {
    // MARK: - Dependencies

    private let networkService: NetworkService
    private let persistenceService: PersistenceService
    private let cacheService: CacheService
    private let syncStore: HistoricalSyncStore
    private let dateProvider: DateProvider
    private let logger: LoggerService

    private var pendingHistoricalWrite: Task<Void, Never>?

    private var clearEpoch = 0

    // MARK: - Initialization

    init(
        networkService: NetworkService,
        persistenceService: PersistenceService,
        cacheService: CacheService,
        syncStore: HistoricalSyncStore = UserDefaultsHistoricalSyncStore(),
        dateProvider: DateProvider = SystemDateProvider(),
        logger: LoggerService = OSLogLoggerService()
    ) {
        self.networkService = networkService
        self.persistenceService = persistenceService
        self.cacheService = cacheService
        self.syncStore = syncStore
        self.dateProvider = dateProvider
        self.logger = logger
    }

    // MARK: - DTO -> Domain Mapping

    private static func domainRates(from rates: [String: Double]) -> [ExchangeRate] {
        rates.compactMap { code, rate in
            CurrencyCode(code).map { ExchangeRate(currencyCode: $0, rate: rate) }
        }
    }
}

// MARK: - ExchangeRateRepository

extension DataCoordinator: ExchangeRateRepository {
    func shouldRefreshRates() async -> Bool {
        await networkService.shouldFetchNewRates()
    }

    func lastFetchDate() -> Date? {
        networkService.getLastFetchDate()
    }

    func fetchExchangeRates() async throws -> [ExchangeRate] {
        let response = try await networkService.fetchExchangeRates()

        var updatedRates = response.rates
        updatedRates[response.base] = 1.0
        let domainRates = Self.domainRates(from: updatedRates)

        async let cacheOperation: Void = cacheService.cacheExchangeRates(domainRates)
        async let persistOperation: Void = persistenceService.saveExchangeRates(updatedRates)

        do {
            _ = try await (cacheOperation, persistOperation)
        } catch {
            logger.warning("Failed to store fetched rates: \(error.localizedDescription)", category: .data)
        }

        networkService.updateLastFetchDate(dateProvider.now())
        return domainRates
    }

    func loadExchangeRates() async throws -> [ExchangeRate] {
        if let cachedRates = await cacheService.getCachedExchangeRates(), !cachedRates.isEmpty {
            return cachedRates
        }

        do {
            let persistedRates = try await persistenceService.loadExchangeRates()
            if !persistedRates.isEmpty {
                await cacheService.cacheExchangeRates(persistedRates)
                return persistedRates
            }
        } catch {
            logger.warning("Failed to load from persistence: \(error.localizedDescription)", category: .persistence)
        }

        do {
            return try await fetchExchangeRates()
        } catch {
            logger.warning("Network fetch also failed: \(error.localizedDescription)", category: .network)
            throw error
        }
    }
}

// MARK: - HistoricalRateRepository

extension DataCoordinator: HistoricalRateRepository {
    func fetchHistoricalRates(in range: DateRange) async throws -> [HistoricalRateSnapshot] {
        let epoch = clearEpoch
        let historicalResponse = try await networkService.fetchHistoricalRates(
            from: range.start,
            to: range.end
        )

        guard epoch == clearEpoch else { throw CancellationError() }

        let snapshots = await Self.snapshots(from: historicalResponse.rates)

        guard epoch == clearEpoch else { throw CancellationError() }

        schedulePersist(of: historicalResponse.rates, from: range.start, through: range.end, epoch: epoch)
        networkService.updateLastFetchDate(dateProvider.now())
        return snapshots
    }

    func waitForPendingHistoricalWrites() async {
        await pendingHistoricalWrite?.value
    }

    func fetchTransientHistoricalRates(for currencies: [CurrencyCode], in range: DateRange) async throws -> [HistoricalRateSnapshot] {
        let epoch = clearEpoch
        let response = try await networkService.fetchHistoricalRates(
            from: range.start,
            to: range.end,
            quotes: currencies.map(\.rawValue)
        )
        guard epoch == clearEpoch else { throw CancellationError() }
        let snapshots = await Self.snapshots(from: response.rates)
        guard epoch == clearEpoch else { throw CancellationError() }
        return snapshots
    }

    func fetchAndPersistHistoricalRates(in range: DateRange) async throws {
        let epoch = clearEpoch
        let response = try await networkService.fetchHistoricalRates(from: range.start, to: range.end)
        guard epoch == clearEpoch else { throw CancellationError() }
        schedulePersist(of: response.rates, from: range.start, through: range.end, epoch: epoch)
        networkService.updateLastFetchDate(dateProvider.now())
    }

    private func schedulePersist(of rates: [String: [String: Double]], from startDate: Date, through endDate: Date, epoch: Int) {
        let previousWrite = pendingHistoricalWrite
        pendingHistoricalWrite = Task {
            await previousWrite?.value
            guard !Task.isCancelled, epoch == clearEpoch else { return }
            do {
                try await persistenceService.saveHistoricalExchangeRates(rates)
                guard epoch == clearEpoch else { return }
                syncStore.record(from: startDate, through: endDate, at: dateProvider.now())
            } catch {
                let cached = await cacheService.getCachedHistoricalData() ?? []
                await cacheService.cacheHistoricalData(cached.filter { $0.date < startDate || $0.date > endDate })
                logger.warning("Deferred historical save failed; window evicted and coverage not recorded: \(error.localizedDescription)", category: .persistence)
            }
        }
    }

    @concurrent
    private nonisolated static func snapshots(from rates: [String: [String: Double]]) async -> [HistoricalRateSnapshot] {
        rates.compactMap { dateString, currencyRates -> HistoricalRateSnapshot? in
            guard let date = TimeZoneManager.parseAPIDate(dateString) else { return nil }
            let points = currencyRates.compactMap { code, rate in
                CurrencyCode(code).map { HistoricalRatePoint(currencyCode: $0, rate: rate) }
            }
            return HistoricalRateSnapshot(date: date, rates: points)
        }
        .sorted { $0.date < $1.date }
    }

    func loadHistoricalRates(in range: DateRange) async throws -> [HistoricalRateSnapshot] {
        do {
            return try await persistenceService.loadHistoricalRates(
                from: range.start,
                to: range.end
            )
        } catch {
            logger.warning("Failed to load historical data from persistence: \(error.localizedDescription)", category: .persistence)

            // Fetched snapshots are returned directly; re-reading persistence here
            // would race the deferred save.
            do {
                return try await fetchHistoricalRates(in: range)
            } catch {
                logger.warning("Network fetch for historical data also failed: \(error.localizedDescription)", category: .network)
            }

            return []
        }
    }

    func earliestStoredDate() async throws -> Date? {
        try await persistenceService.getEarliestStoredDate()
    }

    func latestStoredDate() async throws -> Date? {
        try await persistenceService.getLatestStoredDate()
    }

    func cachedHistoricalRates() async -> [HistoricalRateSnapshot] {
        await cacheService.getCachedHistoricalData() ?? []
    }

    func mergeCachedHistoricalRates(_ new: [HistoricalRateSnapshot]) async -> [HistoricalRateSnapshot] {
        await cacheService.mergeHistoricalData(new)
    }
}

// MARK: - TrendRepository

extension DataCoordinator: TrendRepository {
    func loadTrendData() async throws -> [Trend] {
        if let cachedTrends = await cacheService.getCachedTrendData() {
            return cachedTrends
        }

        let persistedTrends = try await persistenceService.loadTrendData()
        await cacheService.cacheTrendData(persistedTrends)

        return persistedTrends
    }

    func saveTrendData(_ trends: [Trend]) async throws {
        try await persistenceService.saveTrendData(trends)
        await cacheService.cacheTrendData(trends)
    }

    func loadHistoricalRates(from startDate: Date, to endDate: Date) async throws -> [HistoricalRateSnapshot] {
        try await persistenceService.loadHistoricalRates(from: startDate, to: endDate)
    }
}

// MARK: - DataClearing

extension DataCoordinator: DataClearing {
    func clearAllData() async throws {
        clearEpoch += 1

        pendingHistoricalWrite?.cancel()
        await pendingHistoricalWrite?.value
        pendingHistoricalWrite = nil

        try await persistenceService.clearAllData()

        await cacheService.clearCache()

        networkService.updateLastFetchDate(Date.distantPast)

        syncStore.reset()
    }
}

extension DataCoordinator: ChartDataCacheRepository {
    func cachedChartData(for key: ChartCacheKey) async -> [ChartDataPoint]? {
        await cacheService.getCachedProcessedChartData(for: key.storageKey)
    }

    func storeChartData(_ data: [ChartDataPoint], for key: ChartCacheKey) async {
        await cacheService.cacheProcessedChartData(data, for: key.storageKey)
    }
}

extension DataCoordinator: SyncCoverageRepository {
    var coveredFrom: Date? { syncStore.from }
    var coveredThrough: Date? { syncStore.through }
    var coverageCheckedAt: Date? { syncStore.checkedAt }

    func recordCoverage(from: Date, through: Date, at now: Date) {
        syncStore.record(from: from, through: through, at: now)
    }
}
