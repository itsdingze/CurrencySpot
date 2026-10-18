import Foundation
import OSLog

// MARK: - DataCoordinator

final class DataCoordinator {
    // MARK: - Dependencies

    private let networkService: NetworkService
    private let persistenceService: PersistenceService
    private let cacheService: CacheService
    private let syncStore: HistoricalSyncStore
    private let fetchDateStore: RatesFetchDateStore
    private let dateProvider: DateProvider
    private let logger = Logger(category: .data)

    private var inFlightFetches: [CETDayRange: SharedHistoricalFetch] = [:]

    private var pendingHistoricalWrite: Task<Void, Error>?

    private var clearEpoch = 0

    // MARK: - Initialization

    init(
        networkService: NetworkService,
        persistenceService: PersistenceService,
        cacheService: CacheService,
        syncStore: HistoricalSyncStore,
        fetchDateStore: RatesFetchDateStore,
        dateProvider: DateProvider
    ) {
        self.networkService = networkService
        self.persistenceService = persistenceService
        self.cacheService = cacheService
        self.syncStore = syncStore
        self.fetchDateStore = fetchDateStore
        self.dateProvider = dateProvider
    }

    // MARK: - DTO -> Domain Mapping

    private static func domainRates(from rates: [String: Double]) -> [ExchangeRate] {
        rates.compactMap { code, rate in
            CurrencyCode(code).map { ExchangeRate(currencyCode: $0, rate: rate) }
        }
    }

    @concurrent
    private nonisolated static func snapshots(from rates: [String: [String: Double]]) async -> [HistoricalRateSnapshot] {
        rates.compactMap { dateString, currencyRates -> HistoricalRateSnapshot? in
            guard let date = CETCalendar.date(fromDayString: dateString) else { return nil }
            let points = currencyRates.compactMap { code, rate in
                CurrencyCode(code).map { HistoricalRatePoint(currencyCode: $0, rate: rate) }
            }
            return HistoricalRateSnapshot(date: date, rates: points)
        }
        .sorted { $0.date < $1.date }
    }

    // MARK: - Clear Fence

    private func ensureNotCleared(since epoch: Int) throws {
        guard epoch == clearEpoch else { throw CancellationError() }
    }
}

// MARK: - ExchangeRateRepository

extension DataCoordinator: ExchangeRateRepository {
    func lastFetchDate() -> Date? {
        fetchDateStore.lastFetchDate
    }

    func fetchExchangeRates() async throws -> [ExchangeRate] {
        let response = try await networkService.fetchExchangeRates()

        var updatedRates = response.rates
        updatedRates[response.base] = 1.0
        let domainRates = Self.domainRates(from: updatedRates)

        async let cacheOperation: Void = cacheService.cacheExchangeRates(domainRates)
        async let persistOperation: Void = persistenceService.saveExchangeRates(domainRates)

        do {
            _ = try await (cacheOperation, persistOperation)
        } catch {
            logger.warning("Failed to store fetched rates: \(error.localizedDescription, privacy: .public)")
        }

        fetchDateStore.lastFetchDate = dateProvider.now()
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
            logger.warning("Failed to load saved rates: \(error.localizedDescription, privacy: .public)")
        }

        do {
            return try await fetchExchangeRates()
        } catch {
            logger.warning("Network fetch also failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
}

// MARK: - HistoricalRateRepository

extension DataCoordinator: HistoricalRateRepository {
    func cachedHistoricalRates() async -> [HistoricalRateSnapshot] {
        await cacheService.getCachedHistoricalData() ?? []
    }

    func fetchAndMergeHistoricalRates(in range: DateRange) async throws -> [HistoricalRateSnapshot] {
        let days = CETDayRange(range)
        if let joined = joinInFlightFetch(covering: days) {
            return try await joined.value().filter { days.contains($0.date) }
        }

        let fetch = startSharedFetch(of: range, keyedBy: days)
        defer {
            if inFlightFetches[days] === fetch {
                inFlightFetches[days] = nil
            }
        }
        return try await fetch.value().filter { days.contains($0.date) }
    }

    func loadAndMergeStoredHistoricalRates(in range: DateRange) async throws -> [HistoricalRateSnapshot] {
        let epoch = clearEpoch
        let rows = try await loadStoredHistoricalRates(in: range)
        try ensureNotCleared(since: epoch)
        _ = await cacheService.mergeHistoricalData(rows)
        return rows
    }

    private func joinInFlightFetch(covering days: CETDayRange) -> SharedHistoricalFetch? {
        for (key, fetch) in inFlightFetches where key.covers(days) && fetch.join() {
            return fetch
        }
        return nil
    }

    private func startSharedFetch(of range: DateRange, keyedBy days: CETDayRange) -> SharedHistoricalFetch {
        let epoch = clearEpoch
        let fetch = SharedHistoricalFetch(task: Task {
            try await self.fetchMergeAndPersist(range, epoch: epoch)
        })
        _ = fetch.join()
        inFlightFetches[days] = fetch
        return fetch
    }

    private func fetchMergeAndPersist(_ range: DateRange, epoch: Int) async throws -> [HistoricalRateSnapshot] {
        let response = try await networkService.fetchHistoricalRates(from: range.start, to: range.end)
        try Task.checkCancellation()
        try ensureNotCleared(since: epoch)

        let snapshots = await Self.snapshots(from: response.rates)
        try ensureNotCleared(since: epoch)

        _ = await cacheService.mergeHistoricalData(snapshots)
        try ensureNotCleared(since: epoch)

        schedulePersist(of: response.rates, from: range.start, through: range.end, epoch: epoch)
        return snapshots
    }
}

// MARK: - StoredHistoricalRateRepository

extension DataCoordinator: StoredHistoricalRateRepository {
    func loadStoredHistoricalRates(in range: DateRange) async throws -> [HistoricalRateSnapshot] {
        await settlePendingWrites()
        do {
            return try await persistenceService.loadHistoricalRates(from: range.start, to: range.end)
        } catch PersistenceError.undecodableRowsPurged {
            syncStore.reset()
            throw PersistenceError.undecodableRowsPurged
        }
    }

    func earliestStoredDate() async throws -> Date? {
        await settlePendingWrites()
        return try await persistenceService.getEarliestStoredDate()
    }

    func latestStoredDate() async throws -> Date? {
        await settlePendingWrites()
        return try await persistenceService.getLatestStoredDate()
    }

    private func settlePendingWrites() async {
        _ = await pendingHistoricalWrite?.result
    }
}

// MARK: - ArchiveRepository

extension DataCoordinator: ArchiveRepository {
    func fetchTransientHistoricalRates(for currencies: [CurrencyCode], in range: DateRange) async throws -> [HistoricalRateSnapshot] {
        let epoch = clearEpoch
        let response = try await networkService.fetchHistoricalRates(
            from: range.start,
            to: range.end,
            quotes: currencies.map(\.rawValue)
        )
        try ensureNotCleared(since: epoch)
        let snapshots = await Self.snapshots(from: response.rates)
        try ensureNotCleared(since: epoch)
        return snapshots
    }

    func fetchAndPersistHistoricalRates(in range: DateRange) async throws {
        let epoch = clearEpoch
        let response = try await networkService.fetchHistoricalRates(from: range.start, to: range.end)
        try ensureNotCleared(since: epoch)
        try await schedulePersist(of: response.rates, from: range.start, through: range.end, epoch: epoch).value
    }

    func pruneHistoricalRates(before cutoff: Date) async throws {
        try await persistenceService.deleteHistoricalRates(before: cutoff)
    }

    func archiveStoredBounds() async throws -> (earliest: Date?, latest: Date?) {
        for fetch in Array(inFlightFetches.values) {
            await fetch.waitUntilFinished()
        }
        let earliest = try await earliestStoredDate()
        let latest = try await latestStoredDate()
        return (earliest, latest)
    }
}

// MARK: - Deferred Historical Writes

extension DataCoordinator {
    @discardableResult
    private func schedulePersist(
        of rates: [String: [String: Double]],
        from startDate: Date,
        through endDate: Date,
        epoch: Int
    ) -> Task<Void, Error> {
        let previousWrite = pendingHistoricalWrite
        let write = Task {
            _ = await previousWrite?.result
            try Task.checkCancellation()
            try ensureNotCleared(since: epoch)
            do {
                try await persistenceService.saveHistoricalExchangeRates(rates)
            } catch {
                await evictFromSharedSeries(from: startDate, through: endDate)
                logger.warning("Deferred historical save failed; window evicted and coverage not recorded: \(error.localizedDescription, privacy: .public)")
                throw error
            }
            try ensureNotCleared(since: epoch)
            syncStore.record(from: startDate, through: endDate, at: dateProvider.now())
        }
        pendingHistoricalWrite = write
        return write
    }

    private func evictFromSharedSeries(from startDate: Date, through endDate: Date) async {
        let cached = await cacheService.getCachedHistoricalData() ?? []
        await cacheService.cacheHistoricalData(cached.filter { $0.date < startDate || $0.date > endDate })
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
}

// MARK: - DataClearing

extension DataCoordinator: DataClearing {
    func clearAllData() async throws {
        clearEpoch += 1

        for fetch in inFlightFetches.values {
            fetch.abandon()
        }
        inFlightFetches.removeAll()

        let pending = pendingHistoricalWrite
        pending?.cancel()
        _ = await pending?.result
        if pendingHistoricalWrite == pending {
            pendingHistoricalWrite = nil
        }

        try await persistenceService.clearAllData()

        await cacheService.clearCache()

        fetchDateStore.lastFetchDate = nil

        syncStore.reset()
    }
}

// MARK: - ChartDataCacheRepository

extension DataCoordinator: ChartDataCacheRepository {
    func cachedChartData(for key: ChartCacheKey) async -> [ChartDataPoint]? {
        await cacheService.getCachedProcessedChartData(for: key)
    }

    func storeChartData(_ data: [ChartDataPoint], for key: ChartCacheKey) async {
        await cacheService.cacheProcessedChartData(data, for: key)
    }
}

// MARK: - SyncCoverageRepository

extension DataCoordinator: SyncCoverageRepository {
    var coveredFrom: Date? { syncStore.from }
    var coveredThrough: Date? { syncStore.through }
    var coverageCheckedAt: Date? { syncStore.checkedAt }

    func recordCoverage(from: Date, through: Date, at now: Date) {
        syncStore.record(from: from, through: through, at: now)
    }
}

// MARK: - CETDayRange

private nonisolated struct CETDayRange: Hashable {
    let start: Date
    let end: Date

    init(_ range: DateRange) {
        let calendar = CETCalendar.calendar
        start = calendar.startOfDay(for: range.start)
        end = calendar.startOfDay(for: range.end)
    }

    func covers(_ other: CETDayRange) -> Bool {
        start <= other.start && end >= other.end
    }

    func contains(_ date: Date) -> Bool {
        date >= start && date <= end
    }
}
