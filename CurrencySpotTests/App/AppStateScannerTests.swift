@testable import CurrencySpot
import Testing

@Suite("AppState scanner shortcut")
struct AppStateScannerTests {
    private let appState = AppState(networkMonitor: NetworkMonitor(isConnected: true))

    @Test("opening the scanner selects the camera tab on devices that can scan")
    func opensCameraWhenSupported() {
        appState.openScanner(isScanningSupported: true)

        #expect(appState.selectedTab == .camera)
    }

    @Test("opening the scanner falls back to Convert on devices that can't scan")
    func opensConvertWhenUnsupported() {
        appState.selectedTab = .settings

        appState.openScanner(isScanningSupported: false)

        #expect(appState.selectedTab == .convert)
    }
}
