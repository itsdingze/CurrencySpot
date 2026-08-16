import Foundation

nonisolated protocol ClockService: Sendable {
    func sleep(for duration: Duration) async throws
}

nonisolated struct ContinuousClockService: ClockService {
    func sleep(for duration: Duration) async throws {
        try await ContinuousClock().sleep(for: duration)
    }
}
