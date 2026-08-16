import Foundation
import SwiftData

// MARK: - PersistenceService Protocol

nonisolated protocol PersistenceService: Sendable {
    func saveExchangeRates(_ rates: [String: Double]) async throws

    func saveHistoricalExchangeRates(_ rates: [String: [String: Double]]) async throws

    func loadExchangeRates() async throws -> [ExchangeRate]

    func loadHistoricalRates(from startDate: Date, to endDate: Date) async throws -> [HistoricalRateSnapshot]

    func getEarliestStoredDate() async throws -> Date?

    func getLatestStoredDate() async throws -> Date?

    func loadTrendData() async throws -> [Trend]

    func saveTrendData(_ trends: [Trend]) async throws

    func clearAllData() async throws
}

// MARK: - SwiftDataPersistenceService

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

    private let logger: LoggerService

    init(modelContainer: ModelContainer, logger: LoggerService = OSLogLoggerService()) {
        self.modelContainer = modelContainer
        self.logger = logger
    }

    #if DEBUG
        func isExecutingOnMainThread() -> Bool {
            Thread.isMainThread
        }
    #endif

    // MARK: - Data Persistence Methods

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

    func saveHistoricalExchangeRates(_ rates: [String: [String: Double]]) async throws {
        guard !rates.isEmpty else { return }

        try modelContext.transaction {
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
                    logger.warning("Skipping invalid date: \(date) - \(error)", category: .persistence)
                    continue
                }
            }

            try modelContext.save()
        }
    }

    // MARK: - Data Loading Methods

    func loadExchangeRates() async throws -> [ExchangeRate] {
        let descriptor = FetchDescriptor<ExchangeRateData>(
            sortBy: [SortDescriptor(\.currencyCode)]
        )

        let swiftDataObjects = try modelContext.fetch(descriptor)
        return try swiftDataObjects.map { try $0.toDomain() }
    }

    func loadHistoricalRates(from startDate: Date, to endDate: Date) async throws -> [HistoricalRateSnapshot] {
        let descriptor = FetchDescriptor<HistoricalRateData>(
            predicate: #Predicate { $0.date >= startDate && $0.date <= endDate },
            sortBy: [SortDescriptor(\.date)]
        )

        let swiftDataObjects = try modelContext.fetch(descriptor)
        do {
            return try swiftDataObjects.map { try $0.toDomain() }
        } catch {
            let broken = swiftDataObjects.filter { (try? $0.toDomain()) == nil }
            broken.forEach { modelContext.delete($0) }
            try? modelContext.save()
            logger.warning("Purged \(broken.count) undecodable historical rows", category: .persistence)
            throw error
        }
    }

    // MARK: - Date Management Methods

    func getEarliestStoredDate() async throws -> Date? {
        var descriptor = FetchDescriptor<HistoricalRateData>(
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        descriptor.fetchLimit = 1

        guard let earliestRecord = try modelContext.fetch(descriptor).first else {
            return nil
        }

        return earliestRecord.date
    }

    func getLatestStoredDate() async throws -> Date? {
        var descriptor = FetchDescriptor<HistoricalRateData>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        guard let latestRecord = try modelContext.fetch(descriptor).first else {
            return nil
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
