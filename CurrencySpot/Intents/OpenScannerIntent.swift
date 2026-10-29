import AppIntents

struct OpenScannerIntent: AppIntent {
    static let title: LocalizedStringResource = "intent.scanPrices.title"
    static let description = IntentDescription("intent.scanPrices.description")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        AppState.shared.openScanner()
        #endif
        return .result()
    }
}
