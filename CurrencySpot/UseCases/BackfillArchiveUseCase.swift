import Foundation
import OSLog

// MARK: - BackfillArchiveUseCase

final class BackfillArchiveUseCase {
    private static let archiveChunkDays = 183
    private static let retryDelay: Duration = .seconds(90)
    private static let retryBudget = 2

    // MARK: - Dependencies

    private let archive: ArchiveRepository
    private let analysis: HistoricalDataAnalysisUseCase
    private let clock: ClockService
    private let logger = Logger(category: .useCase)

    // MARK: - Run State

    private var runTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    private var retriesRemaining = retryBudget
    private var isExhausted = false
    private var generation = 0

    // MARK: - Initialization

    init(archive: ArchiveRepository, analysis: HistoricalDataAnalysisUseCase, clock: ClockService) {
        self.archive = archive
        self.analysis = analysis
        self.clock = clock
    }

    // MARK: - Public Interface

    func backfillArchive() async {
        if let runTask {
            await runTask.value
            return
        }
        guard !isExhausted else { return }

        let generation = generation
        let task = Task { await run(generation: generation) }
        runTask = task
        await task.value
    }

    func reset() {
        generation += 1
        runTask?.cancel()
        runTask = nil
        retryTask?.cancel()
        retryTask = nil
        retriesRemaining = Self.retryBudget
        isExhausted = false
    }

    // MARK: - Run Outcome

    private func run(generation: Int) async {
        let completed = await downloadArchive()
        guard generation == self.generation else { return }

        if completed {
            await pruneDaysBeforeArchiveWindow()
        } else if retriesRemaining > 0 {
            scheduleRetry()
        } else {
            isExhausted = true
            logger.warning("Backfill retry budget exhausted; archive views bridge until the next launch or refresh")
        }

        if generation == self.generation {
            runTask = nil
        }
    }

    private func scheduleRetry() {
        retriesRemaining -= 1
        logger.info("Archive backfill re-run scheduled (\(self.retriesRemaining, privacy: .public) retries remaining)")
        retryTask?.cancel()
        retryTask = Task {
            try? await clock.sleep(for: Self.retryDelay)
            guard !Task.isCancelled else { return }
            await backfillArchive()
        }
    }

    private func pruneDaysBeforeArchiveWindow() async {
        let archiveStart = analysis.calculateDateRange(for: .fiveYears).start
        do {
            try await archive.pruneHistoricalRates(before: archiveStart)
        } catch {
            logger.warning("Pruning days before the archive window failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Download

    private func downloadArchive() async -> Bool {
        let archiveRange = analysis.calculateDateRange(for: .fiveYears)
        do {
            let stored = try await archive.archiveStoredBounds()
            guard let gap = analysis.fetchableGap(for: archiveRange, storedFrom: stored.earliest, storedThrough: stored.latest) else {
                repairCoverageIfUnderClaiming(for: archiveRange, storedFrom: stored.earliest, storedThrough: stored.latest)
                return true
            }

            guard try await fetchInChunks(gap) else { return false }

            guard analysis.isRangeCovered(archiveRange) else {
                logger.warning("Archive backfill fetched but coverage did not land; re-run needed")
                return false
            }
            logger.info("Archive backfill complete: \(CETCalendar.dayString(for: gap.start), privacy: .public) to \(CETCalendar.dayString(for: gap.end), privacy: .public)")
            return true
        } catch {
            logger.warning("Archive backfill did not complete: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func fetchInChunks(_ gap: DateRange) async throws -> Bool {
        let calendar = CETCalendar.calendar
        var chunkEnd = gap.end
        while chunkEnd >= gap.start {
            let chunkStart = Swift.max(
                gap.start,
                calendar.date(byAdding: .day, value: -(Self.archiveChunkDays - 1), to: chunkEnd) ?? gap.start
            )
            let chunk = try DateRange.make(start: chunkStart, end: chunkEnd)
            try await archive.fetchAndPersistHistoricalRates(in: chunk)

            guard analysis.isRangeCovered(chunk) else {
                logger.warning("Archive chunk's save left no coverage; aborting this run")
                return false
            }

            guard let nextEnd = calendar.date(byAdding: .day, value: -1, to: chunkStart) else { break }
            chunkEnd = nextEnd
        }
        return true
    }

    private func repairCoverageIfUnderClaiming(for archiveRange: DateRange, storedFrom earliest: Date?, storedThrough latest: Date?) {
        guard !analysis.isRangeCovered(archiveRange), let earliest, let latest else { return }
        analysis.repairCoverage(from: earliest, through: latest)
        logger.info("Coverage watermark repaired from stored bounds")
    }
}
