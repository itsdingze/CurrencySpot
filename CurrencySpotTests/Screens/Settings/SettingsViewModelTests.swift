@testable import CurrencySpot
import Foundation
import Testing

@Suite("SettingsViewModel Tests")
struct SettingsViewModelTests {
    private let isolatedDefaults = IsolatedDefaults()
    private let preferences = InMemoryPreferencesStore()
    private let viewModel: SettingsViewModel

    init() throws {
        viewModel = SettingsViewModel(
            refreshAllDataUseCase: RefreshAllDataUseCase(repository: PreviewExchangeRateRepository()),
            watchlist: WatchlistStore(userDefaults: try isolatedDefaults.make()),
            preferences: preferences,
            appState: AppState(networkMonitor: NetworkMonitor(monitorsPathUpdates: false)),
            clock: ImmediateClock()
        )
    }

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

    @Test("addFavoriteTapped presents the add-currency sheet and dismissing clears it")
    func addFavoriteDestination() {
        viewModel.addFavoriteTapped()
        #expect(viewModel.destination == .addFavoriteCurrency)

        viewModel.dismissDestination()
        #expect(viewModel.destination == nil)
    }

    private final class GatedClearing: DataClearing {
        private(set) var clearCallCount = 0
        var failure: Error?
        private let gate: AsyncStream<Void>
        private let openGate: AsyncStream<Void>.Continuation

        init() {
            (gate, openGate) = AsyncStream.makeStream(of: Void.self)
        }

        func open() {
            openGate.finish()
        }

        func clearAllData() async throws {
            clearCallCount += 1
            for await _ in gate {}
            if let failure { throw failure }
        }
    }

    private func makeOnlineViewModel(clearing: DataClearing, appState: AppState) throws -> SettingsViewModel {
        SettingsViewModel(
            refreshAllDataUseCase: RefreshAllDataUseCase(repository: clearing),
            watchlist: WatchlistStore(userDefaults: try isolatedDefaults.make()),
            preferences: InMemoryPreferencesStore(),
            appState: appState,
            clock: ImmediateClock()
        )
    }

    @Test("confirming Refresh All Data again while a wipe is running starts no second wipe", .timeLimit(.minutes(1)))
    func secondConfirmDuringRefreshIsIgnored() async throws {
        let clearing = GatedClearing()
        let viewModel = try makeOnlineViewModel(
            clearing: clearing,
            appState: AppState(networkMonitor: NetworkMonitor(monitorsPathUpdates: false))
        )

        viewModel.confirmAlert(.refreshAllData)
        await waitUntil { clearing.clearCallCount == 1 }
        viewModel.confirmAlert(.refreshAllData)
        clearing.open()
        await waitUntil { viewModel.toast != nil }

        #expect(clearing.clearCallCount == 1)
    }

    @Test("a failed online wipe surfaces the error and shows no refresh toast", .timeLimit(.minutes(1)))
    func failedRefreshShowsErrorWithoutToast() async throws {
        let clearing = GatedClearing()
        clearing.failure = AppError.unknownError("disk full")
        let appState = AppState(networkMonitor: NetworkMonitor(monitorsPathUpdates: false))
        let viewModel = try makeOnlineViewModel(clearing: clearing, appState: appState)

        viewModel.confirmAlert(.refreshAllData)
        clearing.open()
        await waitUntil { appState.errorHandler.currentError != nil }

        #expect(viewModel.toast == nil)
    }

    @Test("offline Refresh All Data refuses to wipe and shows no refresh toast")
    func offlineRefreshRefusesToWipe() async throws {
        final class SpyClearing: DataClearing {
            private(set) var clearCallCount = 0
            func clearAllData() async throws { clearCallCount += 1 }
        }

        let spy = SpyClearing()
        let monitor = NetworkMonitor(monitorsPathUpdates: false)
        monitor.isConnected = false
        let offlineViewModel = SettingsViewModel(
            refreshAllDataUseCase: RefreshAllDataUseCase(repository: spy),
            watchlist: WatchlistStore(userDefaults: try isolatedDefaults.make()),
            preferences: InMemoryPreferencesStore(),
            appState: AppState(networkMonitor: monitor),
            clock: ImmediateClock()
        )

        offlineViewModel.confirmAlert(.refreshAllData)

        #expect(spy.clearCallCount == 0)
        #expect(offlineViewModel.toast == nil)
    }

    @Test("onboarding presents only until it has been seen")
    func onboardingPresentation() {
        #expect(preferences.hasSeenOnboarding == false)

        viewModel.presentOnboardingIfNeeded()
        #expect(viewModel.destination == .onboarding)

        viewModel.dismissOnboarding()
        #expect(viewModel.destination == nil)

        viewModel.completeOnboarding()
        #expect(preferences.hasSeenOnboarding == true)

        viewModel.presentOnboardingIfNeeded()
        #expect(viewModel.destination == nil)
    }

    @Test("confirming a preferences reset shows a toast and auto-dismisses it via the clock", .timeLimit(.minutes(1)))
    func resetPreferencesShowsAndDismissesToast() async {
        preferences.accentColor = .pink
        viewModel.resetPreferencesTapped()

        viewModel.confirmAlert(.resetPreferences)

        #expect(preferences.accentColor == .cyan)
        #expect(viewModel.toast?.type == .preferencesReset)

        await waitUntil { viewModel.toast == nil }
    }

    @Test("confirming a preferences reset re-seeds the History watchlist from the default favorites")
    func resetPreferencesReseedsWatchlist() throws {
        let defaults = try isolatedDefaults.make()
        let watchlist = WatchlistStore(userDefaults: defaults, seed: ["CHF", "NZD"])
        let viewModel = SettingsViewModel(
            refreshAllDataUseCase: RefreshAllDataUseCase(repository: PreviewExchangeRateRepository()),
            watchlist: watchlist,
            preferences: InMemoryPreferencesStore(),
            appState: AppState(networkMonitor: NetworkMonitor(monitorsPathUpdates: false)),
            clock: ImmediateClock()
        )

        viewModel.confirmAlert(.resetPreferences)

        #expect(watchlist.codes.elements == CurrencyDefaults.favoriteCurrencies)
        #expect(defaults.stringArray(forKey: UserDefaultsKeys.historyWatchlist) == CurrencyDefaults.favoriteCurrencies.map(\.rawValue))
    }
}
