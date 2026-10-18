@testable import CurrencySpot
import Foundation
import Testing

@Suite("RefreshAllDataUseCase Tests")
struct RefreshAllDataUseCaseTests {
    @Test("a successful refresh clears the stored data, then resets the archive backfill")
    func clearsThenResetsBackfill() async throws {
        let log = EventLog()
        let useCase = RefreshAllDataUseCase(
            repository: RecordingDataClearing(log: log),
            backfill: RecordingBackfillReset(log: log)
        )

        try await useCase.execute()

        #expect(log.events == [.cleared, .backfillReset])
    }

    @Test("a failed clear propagates its error and leaves the backfill untouched")
    func failedClearPropagatesWithoutReset() async {
        let log = EventLog()
        let useCase = RefreshAllDataUseCase(
            repository: RecordingDataClearing(log: log, failure: AppError.unknownError("disk full")),
            backfill: RecordingBackfillReset(log: log)
        )

        await #expect(throws: AppError.unknownError("disk full")) {
            try await useCase.execute()
        }
        #expect(log.events.isEmpty)
    }
}

private final class EventLog {
    enum Event: Equatable {
        case cleared
        case backfillReset
    }

    private(set) var events: [Event] = []

    func record(_ event: Event) {
        events.append(event)
    }
}

private final class RecordingDataClearing: DataClearing {
    private let log: EventLog
    private let failure: AppError?

    init(log: EventLog, failure: AppError? = nil) {
        self.log = log
        self.failure = failure
    }

    func clearAllData() async throws {
        if let failure { throw failure }
        log.record(.cleared)
    }
}

private final class RecordingBackfillReset: ArchiveBackfillResetting {
    private let log: EventLog

    init(log: EventLog) {
        self.log = log
    }

    func reset() {
        log.record(.backfillReset)
    }
}
