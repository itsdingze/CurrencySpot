//
//  DataCoordinator.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 3/24/25.
//

import Foundation

// MARK: - DataCoordinator

/// Orchestrates data operations across the network, persistence, and cache layers,
/// implementing the aggregate repository protocols the rest of the app depends on.
/// This is the single owner of post-fetch bookkeeping (persist, cache, stamp) and the
/// only layer that sees network DTOs; everything above it speaks domain types.
final class DataCoordinator {
    // MARK: - Dependencies

    private let networkService: NetworkService
    private let persistenceService: PersistenceService
    private let cacheService: CacheService
    private let syncStore: HistoricalSyncStore
    private let dateProvider: DateProvider
    private let logger: LoggerService

    /// Tail of the deferred historical-save chain. Writes run behind the snapshots
    /// returned to callers so rendering is never blocked on a persistence transaction.
    private var pendingHistoricalWrite: Task<Void, Never>?

    /// Bumped at the start of `clearAllData`. A fetch that began under an older epoch
    /// must not persist, record coverage, or surface data after the wipe — its rows
    /// belong to the world the user just erased.
    private var clearEpoch = 0

    // MARK: - Initialization

    /// - Parameter syncStore: Historical coverage window, reset alongside a full data clear so the
    ///   watermark never outlives the data it describes.
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

    /// Codes were validated at the network boundary (FrankfurterV2Mapper); this is a
    /// mechanical re-key into domain values.
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

    /// Fetches the latest rates and coordinates storage across layers.
    ///
    /// Throws on network failure rather than silently substituting saved rates: deciding
    /// whether to keep showing saved rates (and how to signal that) belongs to the caller.
    /// A failed fetch therefore never advances the last-fetch stamp, so stale rates can't
    /// read as freshly updated and the freshness TTL can't suppress the next live refresh.
    func fetchExchangeRates() async throws -> [ExchangeRate] {
        let response = try await networkService.fetchExchangeRates()

        var updatedRates = response.rates
        updatedRates[response.base] = 1.0
        let domainRates = Self.domainRates(from: updatedRates)

        // Store in cache and persistence concurrently with error handling
        async let cacheOperation: Void = cacheService.cacheExchangeRates(domainRates)
        async let persistOperation: Void = persistenceService.saveExchangeRates(updatedRates)

        // Attempt to store but don't fail if storage fails
        do {
            _ = try await (cacheOperation, persistOperation)
        } catch {
            logger.warning("Failed to store fetched rates: \(error.localizedDescription)", category: .data)
        }

        networkService.updateLastFetchDate(dateProvider.now())
        return domainRates
    }

    /// Loads exchange rates with cache-first strategy and a network last resort.
    /// Throws when no real data can be obtained; presentation decides any mock fallback.
    func loadExchangeRates() async throws -> [ExchangeRate] {
        // Check cache first for fast response
        if let cachedRates = await cacheService.getCachedExchangeRates(), !cachedRates.isEmpty {
            return cachedRates
        }

        // Try to load from persistence
        do {
            let persistedRates = try await persistenceService.loadExchangeRates()
            if !persistedRates.isEmpty {
                await cacheService.cacheExchangeRates(persistedRates)
                return persistedRates
            }
        } catch {
            logger.warning("Failed to load from persistence: \(error.localizedDescription)", category: .persistence)
        }

        // No local data: try the network as a last resort. This is gated on actually
        // being unable to load locally, not on the freshness TTL.
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
    /// Fetches historical rates for a date range and returns the decoded snapshots immediately.
    /// The SwiftData save runs behind the returned data (`schedulePersist`), so a chart render
    /// is never blocked on a multi-thousand-row insert transaction.
    func fetchHistoricalRates(from startDate: Date, to endDate: Date) async throws -> [HistoricalRateSnapshot] {
        let epoch = clearEpoch
        let historicalResponse = try await networkService.fetchHistoricalRates(
            from: startDate,
            to: endDate
        )

        // A clear ran while this fetch was in flight. Throwing (rather than returning
        // stale snapshots) also keeps joiners from re-warming the wiped cache.
        guard epoch == clearEpoch else { throw CancellationError() }

        let snapshots = await Self.snapshots(from: historicalResponse.rates)

        // Re-check after the off-main mapping: a clear may have run during it.
        guard epoch == clearEpoch else { throw CancellationError() }

        schedulePersist(of: historicalResponse.rates, from: startDate, through: endDate, epoch: epoch)
        networkService.updateLastFetchDate(dateProvider.now())
        return snapshots
    }

    func waitForPendingHistoricalWrites() async {
        await pendingHistoricalWrite?.value
    }

    /// Pair-scoped fetch for archive views: decoded snapshots only, no persistence,
    /// no watermark record, no fetch-date stamp — the rows cover a single pair and
    /// must never be mistaken for all-currency coverage.
    func fetchTransientHistoricalRates(for currencies: [CurrencyCode], from startDate: Date, to endDate: Date) async throws -> [HistoricalRateSnapshot] {
        let epoch = clearEpoch
        let response = try await networkService.fetchHistoricalRates(
            from: startDate,
            to: endDate,
            quotes: currencies.map(\.rawValue)
        )
        guard epoch == clearEpoch else { throw CancellationError() }
        let snapshots = await Self.snapshots(from: response.rates)
        // Re-check after the off-main mapping: a clear may have run during it.
        guard epoch == clearEpoch else { throw CancellationError() }
        return snapshots
    }

    /// Fetch-to-disk for the archive backfill: persists and records like a normal
    /// fetch but skips the snapshot mapping — a five-year all-currency response is
    /// ~300k points, and the backfill would only throw them away.
    func fetchAndPersistHistoricalRates(from startDate: Date, to endDate: Date) async throws {
        let epoch = clearEpoch
        let response = try await networkService.fetchHistoricalRates(from: startDate, to: endDate)
        guard epoch == clearEpoch else { throw CancellationError() }
        schedulePersist(of: response.rates, from: startDate, through: endDate, epoch: epoch)
        networkService.updateLastFetchDate(dateProvider.now())
    }

    /// Persists fetched rates behind the returned snapshots, chaining writes in arrival order.
    /// The coverage watermark is recorded only after the save commits: recording first would,
    /// after a crash in between, claim coverage over rows that never landed — leaving chart
    /// gaps that gap detection would never refetch.
    private func schedulePersist(of rates: [String: [String: Double]], from startDate: Date, through endDate: Date, epoch: Int) {
        let previousWrite = pendingHistoricalWrite
        pendingHistoricalWrite = Task {
            await previousWrite?.value
            guard !Task.isCancelled, epoch == clearEpoch else { return }
            do {
                try await persistenceService.saveHistoricalExchangeRates(rates)
                // A clear may have started while the save was running; recording then
                // would claim coverage over a wiped store.
                guard epoch == clearEpoch else { return }
                syncStore.record(from: startDate, through: endDate, at: dateProvider.now())
            } catch {
                // The rendered rows never reached disk. Leaving them in the shared
                // series would let the next gap fetch anchor PAST this hole and record
                // coverage over dates that are not persisted — a hole gap detection
                // would never refetch. Evict the failed window so the cache reflects
                // persisted truth again.
                let cached = await cacheService.getCachedHistoricalData() ?? []
                await cacheService.cacheHistoricalData(cached.filter { $0.date < startDate || $0.date > endDate })
                logger.warning("Deferred historical save failed; window evicted and coverage not recorded: \(error.localizedDescription)", category: .persistence)
            }
        }
    }

    /// Re-keys validated DTO rows (FrankfurterV2Mapper checked codes, rates, and dates at the
    /// network boundary) into domain snapshots, sorted by date as cache merging expects.
    /// `@concurrent` because a year of rates is ~60k point structs — far too much work
    /// for the main actor this coordinator lives on.
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

    /// Loads all historical rates in range from persistence (the source of truth),
    /// with a network fallback on error.
    ///
    /// This deliberately does NOT read the in-memory cache: the historical cache is owned by
    /// `DataOrchestrationUseCase`, which reads it for gap detection and writes the merged result.
    /// Reading it here would shadow data just written by a fresh fetch (a successful 3-month fetch
    /// would still read back only the older, narrower cached window).
    func loadHistoricalRates(in range: DateRange) async throws -> [HistoricalRateSnapshot] {
        do {
            return try await persistenceService.loadHistoricalRates(
                from: range.start,
                to: range.end
            )
        } catch {
            logger.warning("Failed to load historical data from persistence: \(error.localizedDescription)", category: .persistence)

            // A read failure is exceptional — typically corrupt rows that just purged
            // themselves — so fetch unconditionally (no freshness gate): the refetch
            // re-inserts the purged dates now rather than after the TTL lapses. The
            // fetched snapshots are returned directly; re-reading persistence here
            // would race the deferred save.
            do {
                return try await fetchHistoricalRates(from: range.start, to: range.end)
            } catch {
                logger.warning("Network fetch for historical data also failed: \(error.localizedDescription)", category: .network)
            }

            // Return empty array as final fallback
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
        // Check cache first for fast response
        if let cachedTrends = await cacheService.getCachedTrendData() {
            return cachedTrends
        }

        // Load from persistence and update cache
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
        // Fence off in-flight fetches before anything else: a fetch landing while this
        // method is suspended would otherwise schedule a fresh, unguarded persist.
        clearEpoch += 1

        // Settle any deferred historical write, or it could land after the wipe
        // and resurrect rows under a freshly reset watermark.
        pendingHistoricalWrite?.cancel()
        await pendingHistoricalWrite?.value
        pendingHistoricalWrite = nil

        // Clear from persistence layer
        try await persistenceService.clearAllData()

        // Clear cache
        await cacheService.clearCache()

        // Clear last fetch date
        networkService.updateLastFetchDate(Date.distantPast)

        // Drop the historical coverage window, or it would claim coverage over the now-empty
        // store and leave charts blank with no refetch (same hazard the v2 migration guards against).
        syncStore.reset()
    }
}
