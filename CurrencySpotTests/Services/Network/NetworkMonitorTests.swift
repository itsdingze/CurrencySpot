import Network
import Testing
@testable import CurrencySpot

@MainActor
@Suite("NetworkMonitor")
struct NetworkMonitorTests {
    @Test("the system connectivity stream reports the current path status", .tags(.integration), .timeLimit(.minutes(1)))
    func systemUpdatesReportPathStatus() async {
        let expected = await Self.currentPathIsSatisfied()

        var firstUpdate: Bool?
        for await isConnected in NetworkMonitor.systemConnectionUpdates() {
            firstUpdate = isConnected
            break
        }

        #expect(firstUpdate == expected)
    }

    @Test("an injected connectivity stream drives the published status", .timeLimit(.minutes(1)))
    func publishesInjectedConnectivityUpdates() async {
        let (updates, connectivity) = AsyncStream.makeStream(of: Bool.self)
        let monitor = NetworkMonitor(connectionUpdates: updates)

        connectivity.yield(false)
        await waitUntil { monitor.isConnected == false }
        connectivity.yield(true)
        await waitUntil { monitor.isConnected }
        connectivity.finish()

        #expect(monitor.isConnected)
    }

    @Test("a pinned monitor reports the connectivity it was given")
    func pinnedMonitorReportsGivenConnectivity() {
        #expect(NetworkMonitor(isConnected: false).isConnected == false)
        #expect(NetworkMonitor(isConnected: true).isConnected)
    }

    private static func currentPathIsSatisfied() async -> Bool {
        for await path in NWPathMonitor() {
            return path.status == .satisfied
        }
        return false
    }
}
