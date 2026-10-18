import Foundation
import OSLog

// MARK: - LoadHistoricalRatesUseCase

final class LoadHistoricalRatesUseCase {
    private static let residentWindowDays = 370
    private static let storedArchiveSlackDays = 7

    // MARK: - Dependencies

    private let repository: HistoricalRateRepository
    private let archive: ArchiveRepository
    private let backfill: BackfillArchiveUseCase
    private let analysis: HistoricalDataAnalysisUseCase
    private let logger = Logger(category: .useCase)

    // MARK: - Initialization

    init(
        repository: HistoricalRateRepository,
        archive: ArchiveRepository,
        backfill: BackfillArchiveUseCase,
        analysis: HistoricalDataAnalysisUseCase
    ) {
        self.repository = repository
        self.archive = archive
        self.backfill = backfill
        self.analysis = analysis
    }

    // MARK: - Public Interface

    func dateRange(for timeRange: TimeRange) -> DateRange {
        analysis.calculateDateRange(for: timeRange)
    }

    func loadHistoricalData(
        for currency: CurrencyCode,
        base: CurrencyCode,
        dateRange: DateRange
    ) async throws -> HistoricalLoadResult {
        if Self.isArchiveRange(dateRange) {
            return try await loadArchiveData(for: currency, base: base, dateRange: dateRange)
        }
        return try await loadResidentData(for: currency, dateRange: dateRange)
    }

    func prefetchResidentYear() async {
        do {
            _ = try await loadHistoricalData(for: .usd, base: .usd, dateRange: dateRange(for: .oneYear))
        } catch {
            logger.debug("Historical prefetch did not complete: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func isArchiveRange(_ range: DateRange) -> Bool {
        let days = CETCalendar.calendar.dateComponents([.day], from: range.start, to: range.end).day ?? 0
        return days > residentWindowDays
    }

    // MARK: - Resident Ranges

    private func loadResidentData(for currency: CurrencyCode, dateRange: DateRange) async throws -> HistoricalLoadResult {
        let cachedData = await repository.cachedHistoricalRates()

        let missingRanges: [DateRange]
        do {
            missingRanges = try await analysis.calculateMissingDateRanges(
                requiredRange: dateRange,
                cache: cachedData.isEmpty ? nil : CurrencyCache(data: cachedData)
            )
        } catch {
            logger.warning("Error calculating missing ranges: \(error.localizedDescription, privacy: .public)")
            return .cached(cachedData)
        }

        guard !missingRanges.isEmpty else {
            logger.info("Shared series covers the range for \(currency.rawValue, privacy: .private)")
            return .cached(cachedData)
        }

        var fetchedRanges: [DateRange] = []
        var failure: (any Error)?
        for missingRange in missingRanges {
            let filled = try await fill(missingRange)
            if let fetchedGap = filled.fetchedGap {
                fetchedRanges.append(fetchedGap)
            }
            failure = filled.failure ?? failure
        }

        let series = await repository.cachedHistoricalRates()
        if let failure, !series.contains(where: { (dateRange.start ... dateRange.end).contains($0.date) }) {
            throw failure
        }
        logger.info("Shared series updated for \(currency.rawValue, privacy: .private) with \(fetchedRanges.count, privacy: .public) fetched ranges")
        return HistoricalLoadResult(snapshots: series, newDataFetched: !fetchedRanges.isEmpty, fetchedRanges: fetchedRanges)
    }

    private struct Fill {
        var fetchedGap: DateRange?
        var failure: (any Error)?
    }

    private func fill(_ missingRange: DateRange) async throws -> Fill {
        let gap: DateRange?
        do {
            let earliestStored = try await repository.earliestStoredDate()
            let latestStored = try await repository.latestStoredDate()
            gap = analysis.fetchableGap(for: missingRange, storedFrom: earliestStored, storedThrough: latestStored)
        } catch {
            logger.warning("Error reading stored bounds: \(error.localizedDescription, privacy: .public)")
            return Fill(failure: error)
        }

        guard let gap else {
            return Fill(failure: try await loadAndMergeStored(missingRange))
        }
        if let fetchFailure = try await fetchAndMerge(gap) {
            _ = try await loadAndMergeStored(missingRange)
            return Fill(failure: fetchFailure)
        }
        guard !Self.range(gap, covers: missingRange) else {
            return Fill(fetchedGap: gap)
        }
        return Fill(fetchedGap: gap, failure: try await loadAndMergeStored(missingRange))
    }

    private func fetchAndMerge(_ range: DateRange) async throws -> (any Error)? {
        do {
            _ = try await repository.fetchAndMergeHistoricalRates(in: range)
            logger.info("Fetched \(CETCalendar.dayString(for: range.start), privacy: .public) to \(CETCalendar.dayString(for: range.end), privacy: .public)")
            return nil
        } catch let error as CancellationError where Task.isCancelled {
            throw error
        } catch {
            logger.warning("Failed to fetch from API: \(error.localizedDescription, privacy: .public)")
            return error
        }
    }

    private func loadAndMergeStored(_ range: DateRange) async throws -> (any Error)? {
        do {
            _ = try await repository.loadAndMergeStoredHistoricalRates(in: range)
            return nil
        } catch let error as CancellationError where Task.isCancelled {
            throw error
        } catch {
            logger.warning("Stored read failed; fetching instead: \(error.localizedDescription, privacy: .public)")
            return try await fetchAndMerge(range)
        }
    }

    private static func range(_ outer: DateRange, covers inner: DateRange) -> Bool {
        outer.start <= inner.start && outer.end >= inner.end
    }

    // MARK: - Archive Ranges

    private func loadArchiveData(
        for currency: CurrencyCode,
        base: CurrencyCode,
        dateRange: DateRange
    ) async throws -> HistoricalLoadResult {
        if let rows = try await coveredArchiveRows(in: dateRange) {
            logger.info("Archive range served from the store for \(currency.rawValue, privacy: .private)")
            return .cached(rows)
        }

        Task { await backfill.backfillArchive() }

        let pair = Array(Set([currency, base]).subtracting([CurrencyCode.usd]))
        guard !pair.isEmpty else {
            return .cached(Self.emptyDayGrid(for: dateRange))
        }

        do {
            let snapshots = try await archive.fetchTransientHistoricalRates(for: pair, in: dateRange)
            logger.info("Archive range bridged with a transient pair fetch for \(currency.rawValue, privacy: .private)")
            return .cached(snapshots)
        } catch {
            guard let rows = await completeStoredArchive(in: dateRange) else { throw error }
            logger.info("Archive bridge failed; serving the stored archive instead: \(error.localizedDescription, privacy: .public)")
            return .cached(rows)
        }
    }

    private func coveredArchiveRows(in dateRange: DateRange) async throws -> [HistoricalRateSnapshot]? {
        let calendar = CETCalendar.calendar
        let coverageEnd = calendar.date(byAdding: .day, value: -1, to: dateRange.end) ?? dateRange.end
        guard analysis.isRangeCovered(try DateRange.make(start: dateRange.start, end: coverageEnd)) else { return nil }

        do {
            let rows = try await archive.loadStoredHistoricalRates(in: dateRange)
            return rows.isEmpty ? nil : rows
        } catch {
            logger.warning("Archive store read failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func completeStoredArchive(in dateRange: DateRange) async -> [HistoricalRateSnapshot]? {
        let calendar = CETCalendar.calendar
        guard let earliest = try? await archive.earliestStoredDate(),
              let coverageFloor = calendar.date(
                  byAdding: .day,
                  value: Self.storedArchiveSlackDays,
                  to: calendar.startOfDay(for: dateRange.start)
              ),
              calendar.startOfDay(for: earliest) <= coverageFloor,
              let rows = try? await archive.loadStoredHistoricalRates(in: dateRange),
              !rows.isEmpty
        else { return nil }
        return rows
    }

    private static func emptyDayGrid(for range: DateRange) -> [HistoricalRateSnapshot] {
        let calendar = CETCalendar.calendar
        var snapshots: [HistoricalRateSnapshot] = []
        var date = calendar.startOfDay(for: range.start)
        let end = calendar.startOfDay(for: range.end)
        while date <= end {
            snapshots.append(HistoricalRateSnapshot(date: date, rates: []))
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return snapshots
    }
}
