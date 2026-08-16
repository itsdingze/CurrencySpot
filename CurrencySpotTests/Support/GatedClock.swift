@testable import CurrencySpot
import Foundation

nonisolated struct GatedClock: ClockService {
    private let continuation: AsyncStream<Void>.Continuation
    private let gate: Task<Void, Never>

    init() {
        let (stream, continuation) = AsyncStream.makeStream(of: Void.self)
        self.continuation = continuation
        gate = Task { for await _ in stream {} }
    }

    func sleep(for _: Duration) async {
        await gate.value
    }

    func release() {
        continuation.finish()
    }
}
