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
            systemImageName: "arrow.left.arrow.right"
        )
        AppShortcut(
            intent: OpenScannerIntent(),
            phrases: ["Scan prices with \(.applicationName)"],
            shortTitle: "intent.scanPrices.title",
            systemImageName: "camera.viewfinder"
        )
    }
}
