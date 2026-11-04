import AppIntents

struct CurrencySpotShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ConvertCurrencyIntent(),
            phrases: [
                "Convert currency with \(.applicationName)",
                "Convert currency to \(\.$to) with \(.applicationName)",
            ],
            shortTitle: "intent.convert.title",
            systemImageName: "arrow.left.arrow.right",
            parameterPresentation: ParameterPresentation(
                for: \.$to,
                summary: Summary("\(\.$to)"),
                optionsCollections: {
                    OptionsCollection(FavoriteCurrencyOptions(), title: "settings.favorites.title", systemImageName: "star")
                }
            )
        )
        AppShortcut(
            intent: OpenScannerIntent(),
            phrases: ["Scan prices with \(.applicationName)"],
            shortTitle: "intent.scanPrices.title",
            systemImageName: "camera.viewfinder"
        )
    }
}
