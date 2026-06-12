//
//  DataOrchestrationUseCase.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 7/30/25.
//

import Foundation

// MARK: - DataOrchestrationUseCase

/// Use case responsible for orchestrating historical data loading: gap detection,
/// fetch decisions, and merging. Cache mechanics live behind HistoricalRateRepository.
final class DataOrchestrationUseCase {
    // MARK: - Dependencies

    private let repository: HistoricalRateRepository
    private let historicalDataAnalysisUseCase: HistoricalDataAnalysisUseCase
    private let dateProvider: DateProvider
    private let logger: LoggerService

    // MARK: - Initialization

    init(
        repository: HistoricalRateRepository,
        historicalDataAnalysisUseCase: HistoricalDataAnalysisUseCase,
        dateProvider: DateProvider = SystemDateProvider(),
        logger: LoggerService = OSLogLoggerService()
    ) {
        self.repository = repository
        self.historicalDataAnalysisUseCase = historicalDataAnalysisUseCase
        self.dateProvider = dateProvider
        self.logger = logger
    }

    // MARK: - Public Interface

    /// Loads historical data for the specified currency and date range
    /// Returns the loaded data points and whether any new data was actually fetched from API
    func loadHistoricalData(
        for currency: CurrencyCode,
        dateRange: DateRange
    ) async throws -> (dataPoints: [HistoricalRateSnapshot], newDataFetched: Bool, fetchedRanges: [DateRange]) {
        // Step 1: Check the in-memory cache first
        let cachedData = await repository.cachedHistoricalRates(for: currency)
        let cache = cachedData.isEmpty ? nil : CurrencyCache(data: cachedData)

        let missingRanges: [DateRange]
        do {
            missingRanges = try await historicalDataAnalysisUseCase.calculateMissingDateRanges(
                requiredRange: dateRange,
                cache: cache
            )
        } catch {
            logger.warning("Error calculating missing ranges: \(error.localizedDescription)", category: .useCase)
            // If we can't calculate missing ranges, return what we have in cache
            return (dataPoints: cachedData, newDataFetched: false, fetchedRanges: [])
        }

        if missingRanges.isEmpty {
            // Cache covers everything we need
            logger.infoPrivate("Cache hit: Using complete cached data for \(currency)", category: .cache)
            let cachedData = cache?.data ?? []
            return (dataPoints: cachedData, newDataFetched: false, fetchedRanges: [])
        }

        // Step 2: Look at SwiftData and fetch missing data
        var newDataPoints: [HistoricalRateSnapshot] = []
        var actuallyFetchedRanges: [DateRange] = []

        for missingRange in missingRanges {
            do {
                // Only fetch if SwiftData doesn't have the required range
                let shouldFetch = try await shouldFetchMissingData(for: missingRange)
                if shouldFetch {
                    // Try to fetch the missing data from API
                    do {
                        try await repository.fetchAndSaveHistoricalRates(
                            from: missingRange.start,
                            to: missingRange.end
                        )
                        // Track that this range was actually fetched from API
                        actuallyFetchedRanges.append(missingRange)
                        // Record coverage even if the response was empty, so known-empty days
                        // aren't refetched on every chart open.
                        historicalDataAnalysisUseCase.recordSync(
                            from: missingRange.start,
                            through: missingRange.end,
                            now: dateProvider.now()
                        )
                        logger.info("Fetched new data from API for range: \(TimeZoneManager.formatForAPI(missingRange.start)) to \(TimeZoneManager.formatForAPI(missingRange.end))", category: .network)
                    } catch {
                        logger.warning("Failed to fetch from API: \(error.localizedDescription)", category: .network)
                        // Continue with what we have
                    }
                } else {
                    logger.debug("Loading existing data from SwiftData for range: \(TimeZoneManager.formatForAPI(missingRange.start)) to \(TimeZoneManager.formatForAPI(missingRange.end))", category: .persistence)
                }

                // Load it from SwiftData (whether newly fetched or existing)
                let rangeData = try await repository.loadHistoricalRates(
                    for: currency,
                    in: missingRange
                )
                newDataPoints.append(contentsOf: rangeData)
            } catch {
                logger.warning("Error loading data for range: \(error.localizedDescription)", category: .useCase)
                // Continue with next range
            }
        }

        // Step 3: Merge and update cache
        let existingCachedData = cache?.data ?? []
        let mergedData = historicalDataAnalysisUseCase.mergeHistoricalData(existing: existingCachedData, new: newDataPoints)

        await repository.replaceCachedHistoricalRates(mergedData, for: currency)

        logger.infoPrivate("Cache updated: Loaded \(newDataPoints.count) new points for \(currency)", category: .cache)

        return (dataPoints: mergedData, newDataFetched: !actuallyFetchedRanges.isEmpty, fetchedRanges: actuallyFetchedRanges)
    }

    /// Gets cached data for a specific currency within the given date range
    func getCachedData(for currency: CurrencyCode, dateRange: DateRange) async -> [HistoricalRateSnapshot] {
        let cachedData = await repository.cachedHistoricalRates(for: currency)

        // Filter cached data by current time range
        return cachedData.filter { entry in
            entry.date >= dateRange.start && entry.date <= dateRange.end
        }
    }

    /// Determines if we should fetch missing data by comparing SwiftData's stored date range
    /// with the required range. Only fetch if required range extends beyond stored data
    /// AND there are actual business days in the gap.
    private func shouldFetchMissingData(for missingRange: DateRange) async throws -> Bool {
        // Get both earliest and latest dates in single batch
        guard let earliestStoredDate = try await repository.earliestStoredDate(),
              let latestStoredDate = try await repository.latestStoredDate()
        else {
            // No stored data - fetch unless the coverage watermark says we already checked it
            return historicalDataAnalysisUseCase.shouldFetchGap(
                gapStart: missingRange.start,
                gapEnd: missingRange.end,
                now: dateProvider.now()
            )
        }

        let calendar = TimeZoneManager.cetCalendar
        let requiredStart = calendar.startOfDay(for: missingRange.start)
        let requiredEnd = calendar.startOfDay(for: missingRange.end)
        let storedStart = calendar.startOfDay(for: earliestStoredDate)
        let storedEnd = calendar.startOfDay(for: latestStoredDate)

        // Determine the actual gap range that needs fetching
        let gapStart: Date
        let gapEnd: Date

        if requiredStart < storedStart, requiredEnd > storedEnd {
            // Required range spans beyond both ends - check entire missing range
            gapStart = requiredStart
            gapEnd = requiredEnd
        } else if requiredStart < storedStart {
            // Need data before earliest stored
            gapStart = requiredStart
            gapEnd = storedStart
        } else if requiredEnd > storedEnd {
            // Need data after latest stored
            gapStart = storedEnd
            gapEnd = requiredEnd
        } else {
            // Required range is within stored range — every day we need is already persisted.
            // This includes today once its data has landed: we deliberately don't re-poll it within
            // the day (intraday revisions are cosmetic, and refetching the whole window would
            // reintroduce over-fetching). The empty-today case takes the `requiredEnd > storedEnd`
            // branch above, where shouldFetchGap's TTL governs the live-edge recheck.
            return false
        }

        // Fetch the consolidated gap unless the coverage watermark already covers it.
        return historicalDataAnalysisUseCase.shouldFetchGap(
            gapStart: gapStart,
            gapEnd: gapEnd,
            now: dateProvider.now()
        )
    }
}
