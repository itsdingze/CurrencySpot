//
//  PersistenceService.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 7/31/25.
//

import Foundation
import SwiftData

// MARK: - PersistenceService Protocol

protocol PersistenceService {
    /// Saves exchange rates to persistent storage
    func saveExchangeRates(_ rates: [String: Double]) async throws

    /// Saves historical exchange rates to persistent storage
    func saveHistoricalExchangeRates(_ rates: [String: [String: Double]]) async throws

    /// Loads exchange rates from persistent storage
    func loadExchangeRates() async throws -> [ExchangeRateDataValue]

    /// Loads historical rates for specific date range and currency
    func loadHistoricalRatesForCurrency(
        currency: String,
        startDate: String,
        endDate: String
    ) async throws -> [HistoricalRateDataValue]

    /// Gets the earliest stored date in historical data
    func getEarliestStoredDate() async throws -> Date?

    /// Gets the latest stored date in historical data
    func getLatestStoredDate() async throws -> Date?

    /// Loads trend data from persistent storage
    func loadTrendData() async throws -> [TrendDataValue]

    /// Calculates and saves trend data based on historical rates
    func calculateAndSaveTrendData() async throws

    /// Checks if sufficient historical data exists for trend calculation
    func hasSufficientHistoricalDataForTrends() async throws -> Bool

    /// Checks if the provided date range affects trend calculation
    func doesDateRangeAffectTrends(startDate: Date, endDate: Date) async throws -> Bool

    /// Clears all data from persistent storage
    func clearAllData() async throws

    /// Loads historical rates as an async stream for memory-efficient processing
    func loadHistoricalRatesStream(
        currency: String,
        startDate: String,
        endDate: String
    ) -> AsyncStream<HistoricalRateDataValue>
}

// MARK: - SwiftDataPersistenceService

@ModelActor
actor SwiftDataPersistenceService: PersistenceService {
    // MARK: - Data Persistence Methods

    /// Saves the current exchange rates to SwiftData.
    ///
    /// - Parameter rates: A dictionary mapping currency codes to their exchange rates
    func saveExchangeRates(_ rates: [String: Double]) async throws {
        guard !rates.isEmpty else { return }

        try modelContext.transaction {
            try modelContext.delete(model: ExchangeRateData.self)

            // Save new rates
            for (currencyCode, rate) in rates {
                let exchangeRate = ExchangeRateData(
                    currencyCode: currencyCode,
                    rate: rate
                )
                modelContext.insert(exchangeRate)
            }

            try modelContext.save()
        }
    }

    /// Saves historical exchange rates to SwiftData.
    /// This version properly handles incremental saves without deleting existing data
    ///
    /// - Parameter rates: A dictionary mapping Date strings to currency rates
    func saveHistoricalExchangeRates(_ rates: [String: [String: Double]]) async throws {
        guard !rates.isEmpty else { return }

        try modelContext.transaction {
            // First, fetch existing dates to avoid duplicates
            let descriptor = FetchDescriptor<HistoricalRateData>()
            let existingData = try modelContext.fetch(descriptor)
            let existingDates = Set(existingData.map { TimeZoneManager.formatForAPI($0.date) })

            // Only process dates we don't already have
            let newRates = rates.filter { !existingDates.contains($0.key) }

            var newRateData: [HistoricalRateData] = []
            for (date, currencyRates) in newRates {
                let rateDataPoints = currencyRates.compactMap { currency, rate -> HistoricalRateDataPoint? in
                    return HistoricalRateDataPoint(
                        currencyCode: currency,
                        rate: rate
                    )
                }

                guard !rateDataPoints.isEmpty else { continue }

                do {
                    let historicalRateData = try HistoricalRateData(
                        dateString: date,
                        rates: rateDataPoints
                    )

                    newRateData.append(historicalRateData)
                } catch {
                    // Skip invalid dates - log but don't fail the entire operation
                    AppLogger.warning("Skipping invalid date: \(date) - \(error)", category: .persistence)
                    continue
                }
            }

            for rateData in newRateData {
                modelContext.insert(rateData)
            }

            try modelContext.save()
        }
    }

    // MARK: - Data Loading Methods

    /// Loads exchange rates from SwiftData and converts to value types.
    ///
    /// - Returns: An array of ExchangeRateDataValue objects sorted by currency code
    func loadExchangeRates() async throws -> [ExchangeRateDataValue] {
        let descriptor = FetchDescriptor<ExchangeRateData>(
            sortBy: [SortDescriptor(\.currencyCode)]
        )

        let swiftDataObjects = try modelContext.fetch(descriptor)
        return convertExchangeRateDataToValueTypes(swiftDataObjects)
    }

    /// Loads historical rates for specific date range and currency.
    func loadHistoricalRatesForCurrency(
        currency: String,
        startDate: String,
        endDate: String
    ) async throws -> [HistoricalRateDataValue] {
        guard let startDateObj = TimeZoneManager.parseAPIDate(startDate),
              let endDateObj = TimeZoneManager.parseAPIDate(endDate)
        else {
            throw AppError.dateCalculationError("Failed to parse date strings: start=\(startDate), end=\(endDate)")
        }

        // For large date ranges (> 1 year), process in chunks to prevent UI freezing
        let daysDifference = Calendar.current.dateComponents([.day], from: startDateObj, to: endDateObj).day ?? 0

        if daysDifference > 365 {
            return try await loadHistoricalRatesInChunks(
                currency: currency,
                startDate: startDateObj,
                endDate: endDateObj
            )
        } else {
            return try await loadHistoricalRatesDirectly(
                currency: currency,
                startDate: startDateObj,
                endDate: endDateObj
            )
        }
    }

    /// Direct loading for small date ranges (< 1 year)
    private func loadHistoricalRatesDirectly(
        currency: String,
        startDate: Date,
        endDate: Date
    ) async throws -> [HistoricalRateDataValue] {
        // Special handling for USD - load all data in the date range since USD is the base currency
        let predicate: Predicate<HistoricalRateData>
        if currency == "USD" {
            predicate = #Predicate<HistoricalRateData> { data in
                data.date >= startDate && data.date <= endDate
            }
        } else {
            predicate = #Predicate<HistoricalRateData> { data in
                data.date >= startDate &&
                    data.date <= endDate &&
                    data.rates.contains { rate in rate.currencyCode == currency }
            }
        }

        var descriptor = FetchDescriptor<HistoricalRateData>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date)]
        )
        descriptor.relationshipKeyPathsForPrefetching = [\.rates]

        let swiftDataObjects = try modelContext.fetch(descriptor)
        return await convertHistoricalRateDataToValueTypesFiltered(swiftDataObjects, targetCurrency: currency)
    }

    /// Chunked loading for large date ranges (> 1 year)
    private func loadHistoricalRatesInChunks(
        currency: String,
        startDate: Date,
        endDate: Date
    ) async throws -> [HistoricalRateDataValue] {
        var allResults: [HistoricalRateDataValue] = []
        let chunkSize = 365 // Process 1 year at a time

        var currentStart = startDate
        while currentStart < endDate {
            let currentEnd = min(
                Calendar.current.date(byAdding: .day, value: chunkSize, to: currentStart) ?? endDate,
                endDate
            )

            let chunkResults = try await loadHistoricalRatesDirectly(
                currency: currency,
                startDate: currentStart,
                endDate: currentEnd
            )

            allResults.append(contentsOf: chunkResults)

            currentStart = Calendar.current.date(byAdding: .day, value: 1, to: currentEnd) ?? endDate

            // Yield control between chunks
            await Task.yield()
        }

        // Sort final results by date
        return allResults.sorted { $0.date < $1.date }
    }

    // MARK: - Date Management Methods

    func getEarliestStoredDate() async throws -> Date? {
        // Create a descriptor that only fetches the date field and sorts by date
        var descriptor = FetchDescriptor<HistoricalRateData>(
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        descriptor.fetchLimit = 1 // Only fetch the first record

        guard let earliestRecord = try modelContext.fetch(descriptor).first else {
            return nil // No historical data stored at all
        }

        return earliestRecord.date
    }

    func getLatestStoredDate() async throws -> Date? {
        // Create a descriptor that only fetches the date field and sorts by date descending
        var descriptor = FetchDescriptor<HistoricalRateData>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1 // Only fetch the first record (which is the latest)

        guard let latestRecord = try modelContext.fetch(descriptor).first else {
            return nil // No historical data stored at all
        }

        return latestRecord.date
    }

    // MARK: - Trend Data Methods

    func loadTrendData() async throws -> [TrendDataValue] {
        let descriptor = FetchDescriptor<TrendData>()
        let swiftDataObjects = try modelContext.fetch(descriptor)
        return convertTrendDataToValueTypes(swiftDataObjects)
    }

    func calculateAndSaveTrendData() async throws {
        // Get the last 7 days of historical data for all currencies
        let calendar = TimeZoneManager.cetCalendar
        let now = Date()
        let endDate = calendar.startOfDay(for: now)
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate

        // Get all historical data within the 7-day range
        let predicate = #Predicate<HistoricalRateData> { data in
            data.date >= startDate && data.date <= endDate
        }
        let descriptor = FetchDescriptor<HistoricalRateData>(predicate: predicate)
        let historicalData: [HistoricalRateData] = try modelContext.fetch(descriptor)

        // Flatten historical data to get individual currency rates by date
        var currencyDateRates: [String: [(Date, Double)]] = [:]

        for historicalDay in historicalData {
            // Add all currencies from the rates array
            for ratePoint in historicalDay.rates {
                if currencyDateRates[ratePoint.currencyCode] == nil {
                    currencyDateRates[ratePoint.currencyCode] = []
                }
                currencyDateRates[ratePoint.currencyCode]?.append((historicalDay.date, ratePoint.rate))
            }

            // Don't add USD with fixed rate 1.0 - it will be calculated dynamically when needed
            // USD trends are the inverse of other currencies' trends
        }

        // Clear existing trend data and create new data in a transaction
        try modelContext.transaction {
            try modelContext.delete(model: TrendData.self)

            for (currencyCode, dateRates) in currencyDateRates {
                let sortedRates = dateRates.sorted { $0.0 < $1.0 } // Sort by date

                // Need at least 2 data points to calculate trend
                guard sortedRates.count >= 2,
                      let firstRate = sortedRates.first?.1,
                      let lastRate = sortedRates.last?.1
                else {
                    continue
                }

                // Calculate weekly percentage change
                let weeklyChange = ((lastRate - firstRate) / firstRate) * 100

                // Extract mini chart data (up to 7 days)
                let miniChartData = sortedRates.map(\.1)

                // Create and save TrendData
                let trendData = TrendData(
                    currencyCode: currencyCode,
                    weeklyChange: weeklyChange,
                    miniChartData: miniChartData
                )

                modelContext.insert(trendData)
            }

            try modelContext.save()
        }
    }

    func hasSufficientHistoricalDataForTrends() async throws -> Bool {
        let calendar = TimeZoneManager.cetCalendar
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate

        // Check if we have historical data within the last 7 days
        let predicate = #Predicate<HistoricalRateData> { data in
            data.date >= startDate && data.date <= endDate
        }
        let descriptor = FetchDescriptor<HistoricalRateData>(predicate: predicate)
        let historicalData: [HistoricalRateData] = try modelContext.fetch(descriptor)

        // We need at least 2 days of data to calculate meaningful trends
        return historicalData.count >= 2
    }

    func doesDateRangeAffectTrends(startDate: Date, endDate: Date) async throws -> Bool {
        let calendar = TimeZoneManager.cetCalendar
        let today = Date()
        let now = calendar.startOfDay(for: today)
        let trendWindowStart = calendar.date(byAdding: .day, value: -7, to: now) ?? now

        // Normalize input dates to start of day for consistent comparison
        let normalizedStartDate = calendar.startOfDay(for: startDate)
        let normalizedEndDate = calendar.startOfDay(for: endDate)

        // Check if the date range overlaps with the last 7 days (trend calculation window)
        // Overlap occurs if: startDate <= trendWindowEnd AND endDate >= trendWindowStart
        let trendWindowEnd = now

        let rangeOverlapsWithTrendWindow = normalizedStartDate <= trendWindowEnd && normalizedEndDate >= trendWindowStart

        if rangeOverlapsWithTrendWindow {
            AppLogger.info("Date range \(TimeZoneManager.formatForAPI(startDate)) to \(TimeZoneManager.formatForAPI(endDate)) affects trends", category: .persistence)
        } else {
            AppLogger.debug("Date range \(TimeZoneManager.formatForAPI(startDate)) to \(TimeZoneManager.formatForAPI(endDate)) does not affect trends", category: .persistence)
        }

        return rangeOverlapsWithTrendWindow
    }

    // MARK: - Data Management Methods

    func clearAllData() async throws {
        try modelContext.transaction {
            try modelContext.delete(model: ExchangeRateData.self)
            try modelContext.delete(model: HistoricalRateData.self)
            try modelContext.delete(model: TrendData.self)
            try modelContext.save()
        }
    }

    /// Loads historical rates as an async stream for memory-efficient processing
    /// This implementation processes data one record at a time to minimize memory usage
    nonisolated func loadHistoricalRatesStream(
        currency: String,
        startDate: String,
        endDate: String
    ) -> AsyncStream<HistoricalRateDataValue> {
        let actorRef = self

        return AsyncStream { continuation in
            Task {
                do {
                    guard let startDateObj = TimeZoneManager.parseAPIDate(startDate),
                          let endDateObj = TimeZoneManager.parseAPIDate(endDate)
                    else {
                        continuation.finish()
                        return
                    }

                    // Fetch data within the actor's isolated context
                    let dataValues = try await actorRef.fetchHistoricalDataForStream(
                        currency: currency,
                        startDate: startDateObj,
                        endDate: endDateObj
                    )

                    // Process and yield one record at a time
                    for value in dataValues {
                        continuation.yield(value)
                        await Task.yield()
                    }

                    continuation.finish()
                } catch {
                    // In case of error, finish the stream
                    continuation.finish()
                }
            }
        }
    }

    /// Helper method to fetch data within actor isolation
    private func fetchHistoricalDataForStream(
        currency: String,
        startDate: Date,
        endDate: Date
    ) async throws -> [HistoricalRateDataValue] {
        let predicate = #Predicate<HistoricalRateData> { data in
            data.date >= startDate &&
                data.date <= endDate &&
                data.rates.contains { rate in rate.currencyCode == currency }
        }

        var descriptor = FetchDescriptor<HistoricalRateData>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date)]
        )
        descriptor.relationshipKeyPathsForPrefetching = [\.rates]

        let swiftDataObjects = try modelContext.fetch(descriptor)

        var results: [HistoricalRateDataValue] = []
        for historicalData in swiftDataObjects {
            if let targetRatePoint = historicalData.rates.first(where: { $0.currencyCode == currency }) {
                let ratePoint = HistoricalRateDataPointValue(
                    currencyCode: targetRatePoint.currencyCode,
                    rate: targetRatePoint.rate
                )
                let value = HistoricalRateDataValue(
                    date: historicalData.date,
                    rates: [ratePoint]
                )
                results.append(value)
            }
        }

        return results
    }

    // MARK: - Data Conversion Helper Methods

    private func convertExchangeRateDataToValueTypes(_ swiftDataObjects: [ExchangeRateData]) -> [ExchangeRateDataValue] {
        swiftDataObjects.compactMap { exchangeRateData in
            let currencyCode = exchangeRateData.currencyCode
            let rate = exchangeRateData.rate
            return ExchangeRateDataValue(currencyCode: currencyCode, rate: rate)
        }
    }

    private func convertTrendDataToValueTypes(_ swiftDataObjects: [TrendData]) -> [TrendDataValue] {
        swiftDataObjects.compactMap { trendData in
            TrendDataValue(
                currencyCode: trendData.currencyCode,
                weeklyChange: trendData.weeklyChange,
                miniChartData: trendData.miniChartData
            )
        }
    }

    private func convertHistoricalRateDataToValueTypesFiltered(
        _ swiftDataObjects: [HistoricalRateData],
        targetCurrency _: String
    ) async -> [HistoricalRateDataValue] {
        var result: [HistoricalRateDataValue] = []
        result.reserveCapacity(swiftDataObjects.count)

        for (index, historicalData) in swiftDataObjects.enumerated() {
            // Yield control every 100 records to prevent UI freezing
            if index % 100 == 0 {
                await Task.yield()
            }

            // Convert ALL rates for this date to support any base-target currency conversion
            let valuePoints = historicalData.rates.map { rate in
                HistoricalRateDataPointValue(
                    currencyCode: rate.currencyCode,
                    rate: rate.rate
                )
            }

            result.append(HistoricalRateDataValue(date: historicalData.date, rates: valuePoints))
        }

        return result
    }
}
