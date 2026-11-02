import Foundation
import Testing
import UIKit
@testable import CurrencySpot

struct CameraViewModelStillRecognitionTests {
    private static let yenPriceResult = StillRecognitionResult(
        items: [RecognizedTextItem(id: UUID(), transcript: "¥1,200", bounds: CGRect(x: 10, y: 10, width: 80, height: 20))],
        imagePixelSize: CGSize(width: 100, height: 100)
    )

    private static func makeViewModel(
        appState: AppState = AppState(networkMonitor: NetworkMonitor(isConnected: true)),
        stillRecognizer: StillTextRecognitionService
    ) -> CameraViewModel {
        let ratesStore = ExchangeRatesStore()
        ratesStore.update(
            rates: [
                ExchangeRate(currencyCode: "JPY", rate: 150),
                ExchangeRate(currencyCode: "EUR", rate: 0.9),
                ExchangeRate(currencyCode: "USD", rate: 1),
            ],
            lastUpdated: nil,
            isShowingSampleRates: false
        )
        return CameraViewModel(
            ratesStore: ratesStore,
            appState: appState,
            permissionService: StubCameraPermissionService(status: .authorized),
            torchService: InMemoryTorchService(),
            scanConversionUseCase: ScanConversionUseCase(),
            recognizeStillImageTextUseCase: RecognizeStillImageTextUseCase(recognizer: stillRecognizer),
            calculateConversionUseCase: CalculateConversionUseCase(),
            localeCurrencyCode: "JPY",
            fallbackBaseCurrency: "USD",
            defaultTargetCurrency: "USD",
            clock: ManualClock()
        )
    }

    @Test func frozenStillIsReadAsAMenuPricedInTheBaseCurrency() async {
        let recognizer = MenuCurrencyRecordingRecognizer()
        let viewModel = Self.makeViewModel(stillRecognizer: recognizer)
        viewModel.baseCurrency = "EUR"
        let image = UIImage()
        await viewModel.freezeFrame(capturing: { image })

        await viewModel.recognizeStill(in: image)

        #expect(recognizer.recordedCurrencies == ["EUR"])
    }

    @Test func cancelledStillRecognitionStaysSilentAndKeepsTheStillLoading() async {
        let appState = AppState(networkMonitor: NetworkMonitor(isConnected: true))
        let recognizer = StallingStillTextRecognizer(stallingOn: "JPY")
        let viewModel = Self.makeViewModel(appState: appState, stillRecognizer: recognizer)
        let image = UIImage()
        await viewModel.freezeFrame(capturing: { image })
        let recognition = Task { await viewModel.recognizeStill(in: image) }
        for await _ in recognizer.stalledCurrencies { break }

        recognition.cancel()
        await recognition.value

        #expect(appState.errorHandler.currentError == nil)
        #expect(viewModel.isRecognizingStill == true)
    }

    @Test func reReadingAFrozenStillInAnotherCurrencyPublishesOnlyTheNewRead() async {
        let appState = AppState(networkMonitor: NetworkMonitor(isConnected: true))
        let recognizer = StallingStillTextRecognizer(stallingOn: "USD", otherwise: Self.yenPriceResult)
        let viewModel = Self.makeViewModel(appState: appState, stillRecognizer: recognizer)
        viewModel.baseCurrency = "USD"
        let image = UIImage()
        await viewModel.freezeFrame(capturing: { image })
        viewModel.stillViewportChanged(CGSize(width: 100, height: 100))
        let dollarRead = Task { await viewModel.recognizeStill(in: image) }
        for await _ in recognizer.stalledCurrencies { break }

        viewModel.baseCurrency = "JPY"
        dollarRead.cancel()
        await viewModel.recognizeStill(in: image)
        await dollarRead.value

        #expect(viewModel.detectedItems.map(\.transcript) == ["¥1,200"])
        #expect(appState.errorHandler.currentError == nil)
        #expect(viewModel.isRecognizingStill == false)
    }

    @Test func stillReadingLanguagesChangeOnlyWhenTheMenuLanguageDoes() {
        let recognizer = StillImageTextRecognizer(languagePolicy: RecognitionLanguagePolicy(preferredLanguageIdentifiers: []))
        let viewModel = Self.makeViewModel(stillRecognizer: recognizer)

        viewModel.baseCurrency = "USD"
        let dollarLanguages = viewModel.stillRecognitionLanguages
        viewModel.baseCurrency = "EUR"
        let euroLanguages = viewModel.stillRecognitionLanguages
        viewModel.baseCurrency = "JPY"
        let yenLanguages = viewModel.stillRecognitionLanguages

        #expect(euroLanguages == dollarLanguages)
        #expect(yenLanguages != dollarLanguages)
    }

    @Test func reReadingAFrozenStillMarksItLoadingUntilTheNewReadArrives() async throws {
        let recognizer = StallingStillTextRecognizer(stallingOn: "JPY", otherwise: Self.yenPriceResult)
        let viewModel = Self.makeViewModel(stillRecognizer: recognizer)
        viewModel.baseCurrency = "USD"
        let image = UIImage()
        await viewModel.freezeFrame(capturing: { image })
        await viewModel.recognizeStill(in: image)
        try #require(viewModel.isRecognizingStill == false)

        viewModel.baseCurrency = "JPY"
        let yenRead = Task { await viewModel.recognizeStill(in: image) }
        for await _ in recognizer.stalledCurrencies { break }

        #expect(viewModel.isRecognizingStill == true)
        yenRead.cancel()
        await yenRead.value
    }

}
