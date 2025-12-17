//
//  DataOrchestrationUseCase.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 7/30/25.
//

import Foundation

// MARK: - DataOrchestrationUseCase

/// Use case responsible for orchestrating data loading from cache, SwiftData, and API
/// Extracted from HistoryViewModel to separate concerns
final class DataOrchestrationUseCase {
    // MARK: - Dependencies

    private let service: ExchangeRateService
    private let historicalDataAnalysisUseCase: HistoricalDataAnalysisUseCase
    private let cacheService: CacheService

    // MARK: - Initialization

    init(service: ExchangeRateService, historicalDataAnalysisUseCase: HistoricalDataAnalysisUseCase, cacheService: CacheService) {
        self.service = service
        self.historicalDataAnalysisUseCase = historicalDataAnalysisUseCase
        self.cacheService = cacheService
    }

    // MARK: - Public Interface

    /// Loads historical data for the specified currency and date range
    /// Returns the loaded data points and whether any new data was actually fetched from API
    func loadHistoricalData(
        for currency: String,
        dateRange: DateRange
    ) async throws -> (dataPoints: [HistoricalRateDataValue], newDataFetched: Bool, fetchedRanges: [DateRange]) {
        // Step 1: Check our in-memory cache first
        let cachedData = await cacheService.getCachedHistoricalData(for: currency) ?? []
        let cache = cachedData.isEmpty ? nil : CurrencyCache(data: cachedData)

        let missingRanges: [DateRange]
        do {
            missingRanges = try await historicalDataAnalysisUseCase.calculateMissingDateRanges(
                requiredRange: dateRange,
                cache: cache
            )
        } catch {
            AppLogger.warning("Error calculating missing ranges: \(error.localizedDescription)", category: .useCase)
            // If we can't calculate missing ranges, return what we have in cache
            return (dataPoints: cachedData, newDataFetched: false, fetchedRanges: [])
        }

        if missingRanges.isEmpty {
            // Cache covers everything we need
            AppLogger.infoPrivate("Cache hit: Using complete cached data for \(currency)", category: .cache)
            let cachedData = cache?.data ?? []
            return (dataPoints: cachedData, newDataFetched: false, fetchedRanges: [])
        }

        // Step 2: Look at SwiftData and fetch missing data
        var newDataPoints: [HistoricalRateDataValue] = []
        var actuallyFetchedRanges: [DateRange] = []

        for missingRange in missingRanges {
            do {
                // Only fetch if SwiftData doesn't have the required range
                let shouldFetch = try await shouldFetchMissingData(for: missingRange)
                if shouldFetch {
                    // Try to fetch the missing data from API
                    do {
                        try await service.fetchAndSaveHistoricalRates(
                            from: missingRange.start,
                            to: missingRange.end
                        )
                        // Track that this range was actually fetched from API
                        actuallyFetchedRanges.append(missingRange)
                        AppLogger.info("Fetched new data from API for range: \(TimeZoneManager.formatForAPI(missingRange.start)) to \(TimeZoneManager.formatForAPI(missingRange.end))", category: .network)
                    } catch {
                        AppLogger.warning("Failed to fetch from API: \(error.localizedDescription)", category: .network)
                        // Continue with what we have
                    }
                } else {
                    AppLogger.debug("Loading existing data from SwiftData for range: \(TimeZoneManager.formatForAPI(missingRange.start)) to \(TimeZoneManager.formatForAPI(missingRange.end))", category: .persistence)
                }

                // Load it from SwiftData (whether newly fetched or existing)
                let rangeData = try await service.loadHistoricalRatesForCurrency(
                    currency: currency,
                    startDate: TimeZoneManager.formatForAPI(missingRange.start),
                    endDate: TimeZoneManager.formatForAPI(missingRange.end)
                )
                newDataPoints.append(contentsOf: rangeData)
            } catch {
                AppLogger.warning("Error loading data for range: \(error.localizedDescription)", category: .useCase)
                // Continue with next range
            }
        }

        // Step 3: Merge and update cache
        let existingCachedData = cache?.data ?? []
        let mergedData = historicalDataAnalysisUseCase.mergeHistoricalData(existing: existingCachedData, new: newDataPoints)

        // Update the cache service
        await cacheService.cacheHistoricalData(mergedData, for: currency)

        AppLogger.infoPrivate("Cache updated: Loaded \(newDataPoints.count) new points for \(currency)", category: .cache)

        return (dataPoints: mergedData, newDataFetched: !actuallyFetchedRanges.isEmpty, fetchedRanges: actuallyFetchedRanges)
    }

    /// Gets cached data for a specific currency within the given date range
    func getCachedData(for currency: String, dateRange: DateRange) async -> [HistoricalRateDataValue] {
        guard let cachedData = await cacheService.getCachedHistoricalData(for: currency) else { return [] }

        // Filter cached data by current time range
        return cachedData.filter { entry in
            let date = entry.date
            return date >= dateRange.start && date <= dateRange.end
        }
    }

    /// Clears all cached data
    func clearAllCache() async {
        await cacheService.clearCache()
    }

    /// Determines if we should fetch missing data by comparing SwiftData's stored date range
    /// with the required range. Only fetch if required range extends beyond stored data
    /// AND there are actual business days in the gap.
    private func shouldFetchMissingData(for missingRange: DateRange) async throws -> Bool {
        // Get both earliest and latest dates in single batch
        guard let earliestStoredDate = try await service.getEarliestStoredDate(),
              let latestStoredDate = try await service.getLatestStoredDate()
        else {
            // No stored data - check if missing range has business days
            return await historicalDataAnalysisUseCase.hasActualDataGap(
                from: missingRange.start,
                to: missingRange.end
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
            // Required range is within stored range, no fetch needed
            return false
        }

        // Single hasActualDataGap call for the consolidated gap range
        return await historicalDataAnalysisUseCase.hasActualDataGap(
            from: gapStart,
            to: gapEnd
        )
    }
}
