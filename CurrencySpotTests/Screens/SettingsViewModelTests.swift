//
//  SettingsViewModelTests.swift
//  CurrencySpotTests
//

@testable import CurrencySpot
import Foundation
import Testing

@Suite("SettingsViewModel Tests")
struct SettingsViewModelTests {
    private let viewModel: SettingsViewModel

    init() {
        let suiteName = "SettingsViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        viewModel = SettingsViewModel(
            clearAllDataUseCase: ClearAllDataUseCase(repository: MockExchangeRateService()),
            appState: AppState(networkMonitor: NetworkMonitor(monitorsPathUpdates: false)),
            userDefaults: defaults,
            clock: ImmediateClock()
        )
    }

    private func waitUntil(_ condition: () -> Bool) async {
        while condition() == false {
            await Task.yield()
        }
    }

    // MARK: Destination transitions

    @Test("destructive-action taps present the matching alert destination")
    func alertDestinations() {
        #expect(viewModel.destination == nil)
        #expect(viewModel.pendingAlert == nil)

        viewModel.refreshAllDataTapped()
        #expect(viewModel.destination == .alert(.refreshAllData))
        #expect(viewModel.pendingAlert == .refreshAllData)

        viewModel.resetPreferencesTapped()
        #expect(viewModel.destination == .alert(.resetPreferences))
        #expect(viewModel.pendingAlert == .resetPreferences)

        viewModel.destination = nil
        #expect(viewModel.pendingAlert == nil)
    }

    @Test("accentColorTapped presents the color picker destination")
    func accentColorDestination() {
        viewModel.accentColorTapped()
        #expect(viewModel.destination == .accentColorPicker)
    }

    @Test("offline Refresh All Data refuses to wipe and shows no refresh toast")
    func offlineRefreshRefusesToWipe() async {
        final class SpyClearing: DataClearing {
            private(set) var clearCallCount = 0
            func clearAllData() async throws { clearCallCount += 1 }
        }

        let spy = SpyClearing()
        let monitor = NetworkMonitor(monitorsPathUpdates: false)
        monitor.isConnected = false
        let suiteName = "SettingsViewModelTests.offline.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        let offlineViewModel = SettingsViewModel(
            clearAllDataUseCase: ClearAllDataUseCase(repository: spy),
            appState: AppState(networkMonitor: monitor),
            userDefaults: defaults,
            clock: ImmediateClock()
        )

        offlineViewModel.confirmAlert(.refreshAllData)

        // Refresh promises a download; offline it must refuse rather than destroy
        // data it cannot replace. The refusal path is synchronous.
        #expect(spy.clearCallCount == 0)
        #expect(offlineViewModel.toast == nil)
    }

    // MARK: Onboarding

    @Test("onboarding presents only until it has been seen")
    func onboardingPresentation() {
        #expect(viewModel.hasSeenOnboarding == false)

        viewModel.presentOnboardingIfNeeded()
        #expect(viewModel.destination == .onboarding)

        viewModel.dismissOnboarding()
        #expect(viewModel.destination == nil)

        viewModel.completeOnboarding()
        #expect(viewModel.hasSeenOnboarding == true)

        viewModel.presentOnboardingIfNeeded()
        #expect(viewModel.destination == nil)
    }

    // MARK: Toast lifecycle

    @Test("confirming a preferences reset shows a toast and auto-dismisses it via the clock", .timeLimit(.minutes(1)))
    func resetPreferencesShowsAndDismissesToast() async {
        viewModel.accentColor = .pink
        viewModel.resetPreferencesTapped()

        viewModel.confirmAlert(.resetPreferences)

        #expect(viewModel.accentColor == .cyan) // default restored
        #expect(viewModel.toast?.type == .preferencesReset)

        // ImmediateClock makes the 2s dismissal resolve as soon as its task runs.
        await waitUntil { viewModel.toast == nil }
    }

    // MARK: Favorites

    @Test("addToFavorites validates, deduplicates, and appends")
    func addToFavorites() {
        #expect(viewModel.addToFavorites("usd") == false) // invalid (lowercase)
        #expect(viewModel.addToFavorites("USD") == false) // already a default favorite
        #expect(viewModel.addToFavorites("CHF") == true)
        #expect(viewModel.favoriteCurrencies.last == "CHF")
        #expect(viewModel.addToFavorites("CHF") == false) // duplicate
    }

    @Test("moveFavorites preserves List reorder semantics")
    func moveFavorites() {
        let original = viewModel.favoriteCurrencies.elements
        var expected = original
        expected.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)

        viewModel.moveFavorites(from: IndexSet(integer: 0), to: 3)

        #expect(viewModel.favoriteCurrencies.elements == expected)
    }

    @Test("removeFromFavorites removes by code")
    func removeFromFavorites() {
        #expect(viewModel.removeFromFavorites("EUR") == true)
        #expect(viewModel.favoriteCurrencies.contains("EUR") == false)
        #expect(viewModel.removeFromFavorites("EUR") == false)
    }
}
