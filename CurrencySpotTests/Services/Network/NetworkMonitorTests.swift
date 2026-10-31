import Network
import Testing
@testable import CurrencySpot

@MainActor
@Suite("NetworkMonitor")
struct NetworkMonitorTests {
    @Test("the system path stream reports the current path status and Low Data Mode", .tags(.integration), .timeLimit(.minutes(1)))
    func systemUpdatesReportPathStatus() async {
        let expected = await Self.currentPath()

        var firstUpdate: NetworkMonitor.Path?
        for await path in NetworkMonitor.systemPathUpdates() {
            firstUpdate = path
            break
        }

        #expect(firstUpdate == expected)
    }

    @Test("an injected path stream drives the published connectivity and Low Data Mode", .timeLimit(.minutes(1)))
    func publishesInjectedPathUpdates() async {
        let (updates, paths) = AsyncStream.makeStream(of: NetworkMonitor.Path.self)
        let monitor = NetworkMonitor(pathUpdates: updates)

        paths.yield(NetworkMonitor.Path(isConnected: false, isConstrained: false))
        await waitUntil { monitor.isConnected == false }
        paths.yield(NetworkMonitor.Path(isConnected: true, isConstrained: true))
        await waitUntil { monitor.isConnected && monitor.isConstrained }
        paths.finish()

        #expect(monitor.isConnected)
        #expect(monitor.isConstrained)
    }

    @Test("a pinned monitor reports the connectivity and Low Data Mode it was given")
    func pinnedMonitorReportsGivenConnectivity() {
        #expect(NetworkMonitor(isConnected: false).isConnected == false)
        #expect(NetworkMonitor(isConnected: true).isConnected)
        #expect(NetworkMonitor(isConnected: true).isConstrained == false)
        #expect(NetworkMonitor(isConnected: true, isConstrained: true).isConstrained)
    }

    private static func currentPath() async -> NetworkMonitor.Path? {
        for await path in NWPathMonitor() {
            return NetworkMonitor.Path(isConnected: path.status == .satisfied, isConstrained: path.isConstrained)
        }
        return nil
    }
}
