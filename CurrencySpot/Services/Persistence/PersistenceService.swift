//
//  PersistenceService.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 7/31/25.
//

import Foundation
import SwiftData

// MARK: - PersistenceService Protocol

/// `nonisolated` keeps the protocol out of MainActor default isolation so the
/// `@ModelActor` conformer can satisfy it; `Sendable` lets MainActor callers hand
/// the existential to nonisolated async work.
nonisolated protocol PersistenceService: Sendable {
    /// Saves exchange rates to persistent storage
    func saveExchangeRates(_ rates: [String: Double]) async throws

    /// Saves historical exchange rates to persistent storage
    func saveHistoricalExchangeRates(_ rates: [String: [String: Double]]) async throws

    /// Loads exchange rates from persistent storage
    func loadExchangeRates() async throws -> [ExchangeRate]

    /// Loads historical rates containing the given currency within a date range
    func loadHistoricalRates(currency: String, from startDate: Date, to endDate: Date) async throws -> [HistoricalRateSnapshot]

    /// Loads all historical rates (every currency) within a date range
    func loadHistoricalRates(from startDate: Date, to endDate: Date) async throws -> [HistoricalRateSnapshot]

    /// Gets the earliest stored date in historical data
    func getEarliestStoredDate() async throws -> Date?

    /// Gets the latest stored date in historical data
    func getLatestStoredDate() async throws -> Date?

    /// Loads trend data from persistent storage
    func loadTrendData() async throws -> [Trend]

    /// Replaces all stored trend data with the given values
    func saveTrendData(_ trends: [Trend]) async throws

    /// Clears all data from persistent storage
    func clearAllData() async throws
}

// MARK: - SwiftDataPersistenceService

@ModelActor
actor SwiftDataPersistenceService: PersistenceService {
    // @ModelActor owns the generated initializer, so the logger cannot be injected;
    // a default live instance is the accepted seam here.
    private let logger: LoggerService = OSLogLoggerService()

    // MARK: - Data Persistence Methods

    /// Saves the current exchange rates to SwiftData.
    ///
    /// - Parameter rates: A dictionary mapping currency codes to their exchange rates
    func saveExchangeRates(_ rates: [String: Double]) async throws {
        guard !rates.isEmpty else { return }

        try modelContext.transaction {
            try modelContext.delete(model: ExchangeRateData.self)

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
                let rateDataPoints = currencyRates.map { currency, rate in
                    HistoricalRateDataPoint(
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
                    logger.warning("Skipping invalid date: \(date) - \(error)", category: .persistence)
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
    /// - Returns: An array of ExchangeRate objects sorted by currency code
    func loadExchangeRates() async throws -> [ExchangeRate] {
        let descriptor = FetchDescriptor<ExchangeRateData>(
            sortBy: [SortDescriptor(\.currencyCode)]
        )

        let swiftDataObjects = try modelContext.fetch(descriptor)
        return try swiftDataObjects.map { try $0.toDomain() }
    }

    /// Loads historical rates containing the given currency within a date range.
    func loadHistoricalRates(currency: String, from startDate: Date, to endDate: Date) async throws -> [HistoricalRateSnapshot] {
        // For large date ranges (> 1 year), process in chunks to prevent UI freezing
        let daysDifference = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0

        if daysDifference > 365 {
            return try loadHistoricalRatesInChunks(
                currency: currency,
                startDate: startDate,
                endDate: endDate
            )
        } else {
            return try loadHistoricalRatesDirectly(
                currency: currency,
                startDate: startDate,
                endDate: endDate
            )
        }
    }

    /// Loads all historical rates (every currency) within a date range.
    func loadHistoricalRates(from startDate: Date, to endDate: Date) async throws -> [HistoricalRateSnapshot] {
        // USD rows carry every currency's rate, so the USD path is the all-currency load.
        try await loadHistoricalRates(currency: CurrencyCode.usd.rawValue, from: startDate, to: endDate)
    }

    /// Direct loading for small date ranges (< 1 year).
    /// Synchronous on the model actor: no suspension may occur while live @Model
    /// objects are held, or a concurrent clearAllData/save could delete them mid-iteration.
    private func loadHistoricalRatesDirectly(
        currency: String,
        startDate: Date,
        endDate: Date
    ) throws -> [HistoricalRateSnapshot] {
        // Special handling for USD - load all data in the date range since USD is the base currency
        let predicate: Predicate<HistoricalRateData>
        if currency == CurrencyCode.usd.rawValue {
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
        return try swiftDataObjects.map { try $0.toDomain() }
    }

    /// Chunked loading for large date ranges (> 1 year).
    /// Each chunk is fetched and snapshotted into value types synchronously, so no
    /// managed objects are held across a suspension point.
    private func loadHistoricalRatesInChunks(
        currency: String,
        startDate: Date,
        endDate: Date
    ) throws -> [HistoricalRateSnapshot] {
        var allResults: [HistoricalRateSnapshot] = []
        let chunkSize = 365 // Process 1 year at a time

        var currentStart = startDate
        while currentStart < endDate {
            try Task.checkCancellation()

            let currentEnd = min(
                Calendar.current.date(byAdding: .day, value: chunkSize, to: currentStart) ?? endDate,
                endDate
            )

            let chunkResults = try loadHistoricalRatesDirectly(
                currency: currency,
                startDate: currentStart,
                endDate: currentEnd
            )

            allResults.append(contentsOf: chunkResults)

            currentStart = Calendar.current.date(byAdding: .day, value: 1, to: currentEnd) ?? endDate
        }

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

    func loadTrendData() async throws -> [Trend] {
        let descriptor = FetchDescriptor<TrendData>()
        let swiftDataObjects = try modelContext.fetch(descriptor)
        return try swiftDataObjects.map { try $0.toDomain() }
    }

    func saveTrendData(_ trends: [Trend]) async throws {
        try modelContext.transaction {
            try modelContext.delete(model: TrendData.self)

            for trend in trends {
                modelContext.insert(TrendData(from: trend))
            }

            try modelContext.save()
        }
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
}
