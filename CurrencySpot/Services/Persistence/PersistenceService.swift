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

/// SwiftData persistence behind a dedicated serial dispatch queue.
///
/// Deliberately NOT `@ModelActor`: its `DefaultSerialModelExecutor` runs jobs on the
/// main thread regardless of where the actor is created (verified by
/// `PersistenceThreadingTests`), which froze the UI for seconds while the launch
/// warm-up saved a year of rates. Using a `DispatchSerialQueue` as the actor's
/// executor pins every save and fetch to a background queue; the `ModelContext` is
/// created lazily on that queue and confined to it ever after.
actor SwiftDataPersistenceService: PersistenceService {
    private nonisolated let queue = DispatchSerialQueue(label: "CurrencySpot.SwiftDataPersistence", qos: .userInitiated)

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        queue.asUnownedSerialExecutor()
    }

    private let modelContainer: ModelContainer

    private var _modelContext: ModelContext?
    private var modelContext: ModelContext {
        if let _modelContext { return _modelContext }
        let context = ModelContext(modelContainer)
        _modelContext = context
        return context
    }

    private let logger: LoggerService = OSLogLoggerService()

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    #if DEBUG
        /// Test probe: which thread this actor's executor actually runs on.
        func isExecutingOnMainThread() -> Bool {
            Thread.isMainThread
        }
    #endif

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

    /// Saves historical exchange rates to SwiftData as one blob row per date.
    /// This version properly handles incremental saves without deleting existing data.
    ///
    /// - Parameter rates: A dictionary mapping Date strings to currency rates
    func saveHistoricalExchangeRates(_ rates: [String: [String: Double]]) async throws {
        guard !rates.isEmpty else { return }

        try modelContext.transaction {
            // Dedupe against existing rows, scoped to the incoming window rather than
            // the whole table (which grows with every year of accumulated history).
            let incomingDates = rates.keys.compactMap(TimeZoneManager.parseAPIDate)
            guard let windowStart = incomingDates.min(), let windowEnd = incomingDates.max() else { return }
            let descriptor = FetchDescriptor<HistoricalRateData>(
                predicate: #Predicate { $0.date >= windowStart && $0.date <= windowEnd }
            )
            let existingDates = Set(try modelContext.fetch(descriptor).map { TimeZoneManager.formatForAPI($0.date) })

            for (date, currencyRates) in rates where !existingDates.contains(date) {
                guard !currencyRates.isEmpty else { continue }

                do {
                    modelContext.insert(try HistoricalRateData(dateString: date, rates: currencyRates))
                } catch {
                    // Skip invalid dates - log but don't fail the entire operation
                    logger.warning("Skipping invalid date: \(date) - \(error)", category: .persistence)
                    continue
                }
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

    /// Loads all historical rates (every currency) within a date range.
    /// One blob row per date makes even a five-year window a few thousand small
    /// fetch+decode operations, so no chunking or per-currency filtering is needed.
    func loadHistoricalRates(from startDate: Date, to endDate: Date) async throws -> [HistoricalRateSnapshot] {
        let descriptor = FetchDescriptor<HistoricalRateData>(
            predicate: #Predicate { $0.date >= startDate && $0.date <= endDate },
            sortBy: [SortDescriptor(\.date)]
        )

        let swiftDataObjects = try modelContext.fetch(descriptor)
        do {
            return try swiftDataObjects.map { try $0.toDomain() }
        } catch {
            // Purge undecodable rows before rethrowing: the date-keyed save dedupe
            // would otherwise skip those dates forever, leaving the fallback fetch
            // to refetch the window on every open without ever repairing it.
            let broken = swiftDataObjects.filter { (try? $0.toDomain()) == nil }
            broken.forEach { modelContext.delete($0) }
            try? modelContext.save()
            logger.warning("Purged \(broken.count) undecodable historical rows", category: .persistence)
            throw error
        }
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
