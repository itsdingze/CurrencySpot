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
    private let historyBase: HistoryBaseCurrencyStore
    private let language = InMemoryAppLanguageStore(systemIdentifier: "en")
    private let appState = AppState(networkMonitor: NetworkMonitor(isConnected: true))
    private let appIcons = InMemoryAppIconService()
    private let viewModel: SettingsViewModel

    init() throws {
        let defaults = try isolatedDefaults.make()
        favorites = CurrencyCodeListStore(
            defaults: defaults,
            key: UserDefaultsKeys.favoriteCurrencies,
            seed: ["USD", "EUR", "GBP", "JPY"]
        )
        watchlist = CurrencyCodeListStore(defaults: defaults, key: UserDefaultsKeys.historyWatchlist, seed: ["CHF", "NZD"])
        historyBase = HistoryBaseCurrencyStore(defaults: defaults)
        viewModel = Self.makeViewModel(
            refresh: GatedRefresh(),
            preferences: preferences,
            favorites: favorites,
            watchlist: watchlist,
            historyBase: historyBase,
            language: language,
            appIcons: appIcons,
            appState: appState,
            clock: ImmediateClock()
        )
    }

    private static func makeViewModel(
        refresh: AllDataRefreshing,
        preferences: PreferencesStore,
        favorites: CurrencyCodeListStore,
        watchlist: CurrencyCodeListStore,
        historyBase: HistoryBaseCurrencyStore,
        language: AppLanguageStore,
        appIcons: AppIconService,
        appState: AppState,
        clock: ClockService
    ) -> SettingsViewModel {
        SettingsViewModel(
            refreshAllDataUseCase: refresh,
            resetPreferencesUseCase: ResetPreferencesUseCase(
                preferences: preferences,
                favorites: favorites,
                watchlist: watchlist,
                historyBase: historyBase,
                language: language
            ),
            manageFavoritesUseCase: ManageFavoritesUseCase(favorites: favorites),
            preferences: preferences,
            languageStore: language,
            appIconService: appIcons,
            appState: appState,
            clock: clock
        )
    }

    private func makeViewModel(refresh: AllDataRefreshing, appState: AppState, toastClock: ClockService) -> SettingsViewModel {
        makeViewModel(refresh: refresh, appIcons: appIcons, appState: appState, toastClock: toastClock)
    }

    private func makeViewModel(appIcons: AppIconService) -> SettingsViewModel {
        makeViewModel(refresh: GatedRefresh(), appIcons: appIcons, appState: appState, toastClock: ImmediateClock())
    }

    private func makeViewModel(
        refresh: AllDataRefreshing,
        appIcons: AppIconService,
        appState: AppState,
        toastClock: ClockService
    ) -> SettingsViewModel {
        Self.makeViewModel(
            refresh: refresh,
            preferences: preferences,
            favorites: favorites,
            watchlist: watchlist,
            historyBase: historyBase,
            language: language,
            appIcons: appIcons,
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

    @Test("appIconTapped presents the app icon picker destination")
    func appIconDestination() {
        viewModel.appIconTapped()
        #expect(viewModel.destination == .appIconPicker)
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

    @Test("swiping a toast away hides it at once and stops its pending auto-dismiss", .timeLimit(.minutes(1)))
    func dismissingToastHidesItAndStopsTheTimer() async {
        let toastClock = GatedClock()
        let viewModel = makeViewModel(refresh: GatedRefresh(), appState: appState, toastClock: toastClock)
        viewModel.confirmAlert(.resetPreferences)
        await waitUntil { toastClock.sleepRequestCount == 1 }

        viewModel.toastDismissed()

        #expect(viewModel.toast == nil)
        await waitUntil { toastClock.cancelledSleepCount == 1 }
    }

    @Test("a held toast stays up after its auto-dismiss time passes", .timeLimit(.minutes(1)))
    func heldToastOutlastsItsTimer() async {
        let toastClock = GatedClock()
        let viewModel = makeViewModel(refresh: GatedRefresh(), appState: appState, toastClock: toastClock)
        viewModel.confirmAlert(.resetPreferences)
        await waitUntil { toastClock.sleepRequestCount == 1 }

        viewModel.toastHeld()
        await waitUntil { toastClock.cancelledSleepCount == 1 }
        toastClock.release()

        #expect(viewModel.toast?.type == .preferencesReset)
    }

    @Test("letting go of a held toast hides it after a fresh countdown", .timeLimit(.minutes(1)))
    func releasedToastHidesAfterNewCountdown() async {
        let toastClock = GatedClock()
        let viewModel = makeViewModel(refresh: GatedRefresh(), appState: appState, toastClock: toastClock)
        viewModel.confirmAlert(.resetPreferences)
        await waitUntil { toastClock.sleepRequestCount == 1 }
        viewModel.toastHeld()

        viewModel.toastReleased()
        await waitUntil { toastClock.sleepRequestCount == 2 }
        toastClock.release()

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

    @Test("the language row starts on System when no language is saved")
    func languageStartsOnSystem() {
        #expect(viewModel.language == nil)
    }

    @Test("the language row starts on the saved language")
    func languageStartsOnSavedLanguage() {
        language.selectedLanguage = AppLanguage(identifier: "ja")

        #expect(makeViewModel(appIcons: appIcons).language == AppLanguage(identifier: "ja"))
    }

    @Test("choosing System over a saved language removes it and names the system language for the next launch")
    func choosingSystemRemovesSavedLanguage() {
        viewModel.language = AppLanguage(identifier: "zh-Hans")
        viewModel.dismissDestination()

        viewModel.language = nil

        #expect(language.followsSystemLanguage)
        #expect(viewModel.destination == .languageChangeNotice)
        #expect(viewModel.nextLaunchLanguage == AppLanguage(identifier: "en"))
    }

    @Test("choosing System while already following the system shows no notice")
    func choosingSystemAgainIsSilent() {
        viewModel.language = nil

        #expect(viewModel.destination == nil)
    }

    @Test("choosing the language the system already uses saves it without a notice, since the next launch looks the same")
    func choosingTheSystemsOwnLanguageIsSilent() {
        viewModel.language = AppLanguage(identifier: "en")

        #expect(language.followsSystemLanguage == false)
        #expect(viewModel.language == AppLanguage(identifier: "en"))
        #expect(viewModel.destination == nil)
    }

    @Test("a reset over a saved language equal to the system language shows no language notice", .timeLimit(.minutes(1)))
    func resetOverTheSystemsOwnLanguageShowsNoNotice() async {
        viewModel.language = AppLanguage(identifier: "en")

        viewModel.confirmAlert(.resetPreferences)

        await waitUntil { viewModel.toast == nil }
        #expect(viewModel.language == nil)
        #expect(viewModel.destination == nil)
    }

    @Test("choosing another language saves it and tells the user it applies on the next launch")
    func choosingLanguageSavesAndNotifies() {
        viewModel.language = AppLanguage(identifier: "zh-Hans")

        #expect(language.selectedLanguage == AppLanguage(identifier: "zh-Hans"))
        #expect(viewModel.destination == .languageChangeNotice)
        #expect(viewModel.nextLaunchLanguage == AppLanguage(identifier: "zh-Hans"))
    }

    @Test("picking the language already selected shows no notice")
    func pickingSameLanguageIsSilent() {
        viewModel.language = AppLanguage(identifier: "ko")
        viewModel.dismissDestination()

        viewModel.language = AppLanguage(identifier: "ko")

        #expect(viewModel.destination == nil)
    }

    @Test("resetting preferences moves the language row back to System")
    func resetMovesLanguageBackToSystem() {
        viewModel.language = AppLanguage(identifier: "zh-Hans")
        viewModel.dismissDestination()

        viewModel.confirmAlert(.resetPreferences)

        #expect(viewModel.language == nil)
    }

    @Test("a reset over a saved language says the language changes on the next launch", .timeLimit(.minutes(1)))
    func resetOverSavedLanguageShowsNotice() async {
        viewModel.language = AppLanguage(identifier: "zh-Hans")
        viewModel.dismissDestination()

        viewModel.confirmAlert(.resetPreferences)

        await waitUntil { viewModel.destination == .languageChangeNotice }
        #expect(viewModel.nextLaunchLanguage == AppLanguage(identifier: "en"))
    }

    @Test("a reset while the language follows the system shows no language notice", .timeLimit(.minutes(1)))
    func resetOnSystemLanguageShowsNoNotice() async {
        viewModel.confirmAlert(.resetPreferences)

        await waitUntil { viewModel.toast == nil }
        #expect(viewModel.destination == nil)
    }

    @Test("a reset puts the default Dollar icon back on the Home Screen", .timeLimit(.minutes(1)))
    func resetRestoresDefaultIcon() async {
        let appIcons = InMemoryAppIconService(alternateIconName: "AppIconCoins")
        let viewModel = makeViewModel(appIcons: appIcons)

        viewModel.confirmAlert(.resetPreferences)

        await waitUntil { viewModel.appIcon == .dollar }
        #expect(appIcons.requestedNames == [nil])
    }

    @Test("a reset over a saved language restores the icon once the language notice is dismissed", .timeLimit(.minutes(1)))
    func resetRestoresIconAfterLanguageNotice() async {
        let appIcons = InMemoryAppIconService(alternateIconName: "AppIconCoins")
        let viewModel = makeViewModel(appIcons: appIcons)
        viewModel.language = AppLanguage(identifier: "de")
        viewModel.dismissDestination()

        viewModel.confirmAlert(.resetPreferences)
        await waitUntil { viewModel.toast == nil }
        #expect(appIcons.requestedNames.isEmpty)

        viewModel.languageNoticeDismissed()

        await waitUntil { viewModel.appIcon == .dollar }
        #expect(appIcons.requestedNames == [nil])
    }

    @Test("a reset on the default icon leaves iOS alone", .timeLimit(.minutes(1)))
    func resetOnDefaultIconIsSilent() async {
        viewModel.confirmAlert(.resetPreferences)

        await waitUntil { viewModel.toast == nil }
        #expect(appIcons.requestedNames.isEmpty)
    }

    @Test("when iOS refuses to restore the icon during a reset, a toast says it didn't change", .timeLimit(.minutes(1)))
    func resetWithRefusedIconShowsToast() async {
        let appIcons = InMemoryAppIconService(alternateIconName: "AppIconCoins")
        appIcons.failure = CocoaError(.featureUnsupported)
        let viewModel = makeViewModel(appIcons: appIcons)

        viewModel.confirmAlert(.resetPreferences)

        await waitUntil { viewModel.toast?.type == .appIconUnchanged }
        #expect(viewModel.appIcon == .coins)
    }

    @Test("the App Icon row starts on the icon the Home Screen shows")
    func appIconStartsOnHomeScreenIcon() {
        let viewModel = makeViewModel(appIcons: InMemoryAppIconService(alternateIconName: "AppIconCoins"))

        #expect(viewModel.appIcon == .coins)
    }

    @Test("choosing Coins puts the Coins icon on the Home Screen")
    func choosingCoinsSwitchesHomeScreenIcon() async {
        await viewModel.selectAppIcon(.coins)

        #expect(appIcons.requestedNames == ["AppIconCoins"])
        #expect(viewModel.appIcon == .coins)
    }

    @Test("choosing Dollar from Coins puts the default icon back on the Home Screen")
    func choosingDollarRestoresDefaultIcon() async {
        let appIcons = InMemoryAppIconService(alternateIconName: "AppIconCoins")
        let viewModel = makeViewModel(appIcons: appIcons)

        await viewModel.selectAppIcon(.dollar)

        #expect(appIcons.requestedNames == [nil])
        #expect(viewModel.appIcon == .dollar)
    }

    @Test("when iOS refuses the change, the row keeps the current icon and a toast says it didn't change")
    func refusedIconChangeKeepsCurrentIcon() async {
        appIcons.failure = CocoaError(.featureUnsupported)

        await viewModel.selectAppIcon(.coins)

        #expect(viewModel.appIcon == .dollar)
        #expect(viewModel.toast?.type == .appIconUnchanged)
    }

    @Test("choosing the icon already on the Home Screen leaves iOS alone")
    func choosingCurrentIconIsSilent() async {
        await viewModel.selectAppIcon(.dollar)

        #expect(appIcons.requestedNames.isEmpty)
    }
}
