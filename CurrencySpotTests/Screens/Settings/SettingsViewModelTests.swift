@testable import CurrencySpot
import Foundation
import IdentifiedCollections
import Testing

@Suite("SettingsViewModel Tests")
struct SettingsViewModelTests {
    private let isolatedDefaults = IsolatedDefaults()
    private let preferences = InMemoryPreferencesStore()
    private let favorites: CurrencyCodeListStore
    private let watchlist: CurrencyCodeListStore
    private let appState = AppState(networkMonitor: NetworkMonitor(isConnected: true))
    private let viewModel: SettingsViewModel

    init() throws {
        let defaults = try isolatedDefaults.make()
        favorites = CurrencyCodeListStore(
            defaults: defaults,
            key: UserDefaultsKeys.favoriteCurrencies,
            seed: ["USD", "EUR", "GBP", "JPY"]
        )
        watchlist = CurrencyCodeListStore(defaults: defaults, key: UserDefaultsKeys.historyWatchlist, seed: ["CHF", "NZD"])
        viewModel = Self.makeViewModel(
            refresh: GatedRefresh(),
            preferences: preferences,
            favorites: favorites,
            watchlist: watchlist,
            appState: appState,
            clock: ImmediateClock()
        )
    }

    private static func makeViewModel(
        refresh: AllDataRefreshing,
        preferences: PreferencesStore,
        favorites: CurrencyCodeListStore,
        watchlist: CurrencyCodeListStore,
        appState: AppState,
        clock: ClockService
    ) -> SettingsViewModel {
        SettingsViewModel(
            refreshAllDataUseCase: refresh,
            resetPreferencesUseCase: ResetPreferencesUseCase(
                preferences: preferences,
                favorites: favorites,
                watchlist: watchlist
            ),
            manageFavoritesUseCase: ManageFavoritesUseCase(favorites: favorites),
            preferences: preferences,
            appState: appState,
            clock: clock
        )
    }

    private func makeViewModel(refresh: AllDataRefreshing, appState: AppState, toastClock: ClockService) -> SettingsViewModel {
        Self.makeViewModel(
            refresh: refresh,
            preferences: preferences,
            favorites: favorites,
            watchlist: watchlist,
            appState: appState,
            clock: toastClock
        )
    }

    private final class GatedRefresh: AllDataRefreshing {
        private(set) var executeCallCount = 0
        var failure: Error?
        private let gate: AsyncStream<Void>
        private let openGate: AsyncStream<Void>.Continuation

        init() {
            (gate, openGate) = AsyncStream.makeStream(of: Void.self)
        }

        func open() {
            openGate.finish()
        }

        func execute() async throws {
            executeCallCount += 1
            for await _ in gate {}
            if let failure { throw failure }
        }
    }

    @Test("destructive-action taps present the matching alert destination")
    func alertDestinations() {
        #expect(viewModel.destination == nil)

        viewModel.refreshAllDataTapped()
        #expect(viewModel.destination == .alert(.refreshAllData))

        viewModel.resetPreferencesTapped()
        #expect(viewModel.destination == .alert(.resetPreferences))
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

    @Test("confirming Refresh All Data again while a wipe is running starts no second wipe", .timeLimit(.minutes(1)))
    func secondConfirmDuringRefreshIsIgnored() async throws {
        let refresh = GatedRefresh()
        let toastClock = GatedClock()
        let viewModel = makeViewModel(refresh: refresh, appState: appState, toastClock: toastClock)

        viewModel.confirmAlert(.refreshAllData)
        await waitUntil { refresh.executeCallCount == 1 }
        viewModel.confirmAlert(.refreshAllData)
        refresh.open()
        await waitUntil { viewModel.toast != nil }

        #expect(refresh.executeCallCount == 1)
        toastClock.release()
    }

    @Test("a successful online wipe signals the data reset once and shows the refresh toast", .timeLimit(.minutes(1)))
    func successfulRefreshSignalsDataReset() async throws {
        let refresh = GatedRefresh()
        let toastClock = GatedClock()
        let viewModel = makeViewModel(refresh: refresh, appState: appState, toastClock: toastClock)

        viewModel.confirmAlert(.refreshAllData)
        #expect(appState.dataResetCount == 0)
        refresh.open()
        await waitUntil { viewModel.toast != nil }

        #expect(viewModel.toast?.type == .dataRefreshing)
        #expect(appState.dataResetCount == 1)
        toastClock.release()
    }

    @Test("a failed online wipe surfaces the error, signals no reset, and shows no refresh toast", .timeLimit(.minutes(1)))
    func failedRefreshShowsErrorWithoutToast() async throws {
        let refresh = GatedRefresh()
        refresh.failure = AppError.unknownError("disk full")
        let toastClock = GatedClock()
        let viewModel = makeViewModel(refresh: refresh, appState: appState, toastClock: toastClock)

        viewModel.confirmAlert(.refreshAllData)
        refresh.open()
        await waitUntil { appState.errorHandler.currentError != nil }

        #expect(appState.errorHandler.currentError == .unknownError("disk full"))
        #expect(appState.dataResetCount == 0)
        #expect(viewModel.toast == nil)
        toastClock.release()
    }

    @Test("offline Refresh All Data refuses to wipe, reports no connection, and shows no refresh toast")
    func offlineRefreshRefusesToWipe() async throws {
        let refresh = GatedRefresh()
        let offlineAppState = AppState(networkMonitor: NetworkMonitor(isConnected: false))
        let offlineViewModel = makeViewModel(refresh: refresh, appState: offlineAppState, toastClock: ImmediateClock())

        offlineViewModel.confirmAlert(.refreshAllData)

        #expect(offlineAppState.errorHandler.currentError == .noInternetConnection)
        #expect(refresh.executeCallCount == 0)
        #expect(offlineAppState.dataResetCount == 0)
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

    @Test("confirming a preferences reset restores the default favorites and re-seeds the History watchlist from them")
    func resetPreferencesReseedsWatchlist() {
        viewModel.confirmAlert(.resetPreferences)

        #expect(viewModel.favoriteCurrencies == CurrencyDefaults.favoriteCurrencies)
        #expect(watchlist.codes.elements == CurrencyDefaults.favoriteCurrencies)
    }

    @Test("deleting favorite rows removes the currencies shown in those rows")
    func removeFavoritesAtDisplayedOffsets() {
        viewModel.removeFavorites(atOffsets: IndexSet([1, 3]))

        #expect(viewModel.favoriteCurrencies == ["USD", "GBP"])
    }

    @Test("the add-currency list offers only currencies that are not favorites")
    func addableCurrenciesExcludeFavorites() {
        let rates = [
            ExchangeRate(currencyCode: "USD", rate: 1),
            ExchangeRate(currencyCode: "CHF", rate: 0.9),
        ]

        #expect(viewModel.addableCurrencies(from: rates, matching: "").map(\.currencyCode) == ["CHF"])
    }
}
