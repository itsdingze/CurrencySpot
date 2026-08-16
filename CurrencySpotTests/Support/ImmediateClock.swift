@testable import CurrencySpot
import Foundation

nonisolated struct ImmediateClock: ClockService {
    func sleep(for _: Duration) async throws {}
}
