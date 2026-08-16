import Network
import Testing
@testable import CurrencySpot

@MainActor
@Suite("NetworkMonitor")
struct NetworkMonitorTests {
    @Test("a monitoring instance publishes the system path status", .timeLimit(.minutes(1)))
    func publishesSystemPathStatus() async {
        let expected = await Self.currentPathIsSatisfied()

        let monitor = NetworkMonitor()
        monitor.isConnected = !expected

        await waitUntil { monitor.isConnected == expected }
        #expect(monitor.isConnected == expected)
    }

    @Test("a non-monitoring instance never overwrites a pinned value")
    func pinnedInstanceIgnoresSystemPath() async {
        let monitor = NetworkMonitor(monitorsPathUpdates: false)
        monitor.isConnected = false

        await Task.yield()

        #expect(monitor.isConnected == false)
    }

    private static func currentPathIsSatisfied() async -> Bool {
        for await path in NWPathMonitor() {
            return path.status == .satisfied
        }
        return false
    }
}
