import Foundation
import IdentifiedCollections
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
        viewModel.stillViewportEvent(.appeared(CGSize(width: 100, height: 100)), from: UUID())
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

    private static let dollarMenu = FreshlyIdentifiedStillRecognizer(
        lines: [
            ("Ramen $12.50", CGRect(x: 10, y: 10, width: 80, height: 10)),
            ("Gyoza $8.50", CGRect(x: 10, y: 40, width: 80, height: 10)),
            ("Table 12", CGRect(x: 10, y: 70, width: 60, height: 10)),
        ],
        imagePixelSize: CGSize(width: 100, height: 100)
    )

    private static func frozenMenu(readIn currency: CurrencyCode) async -> (CameraViewModel, UIImage) {
        let viewModel = makeViewModel(stillRecognizer: dollarMenu)
        viewModel.baseCurrency = currency
        let image = UIImage()
        await viewModel.freezeFrame(capturing: { image })
        viewModel.stillViewportEvent(.appeared(CGSize(width: 100, height: 100)), from: UUID())
        await viewModel.recognizeStill(in: image)
        return (viewModel, image)
    }

    private static func item(_ transcript: String, in viewModel: CameraViewModel) throws -> DetectedItem {
        try #require(viewModel.detectedItems.first { $0.transcript == transcript })
    }

    @Test func badgeEditsSurviveReadingTheFrozenStillInAnotherMenuLanguage() async throws {
        let (viewModel, image) = await Self.frozenMenu(readIn: "EUR")
        viewModel.hideConversion(for: try Self.item("Ramen $12.50", in: viewModel).id)
        viewModel.toggleConversion(for: try Self.item("Table 12", in: viewModel).id)
        let editedIDs = viewModel.detectedItems.ids

        viewModel.baseCurrency = "JPY"
        await viewModel.recognizeStill(in: image)

        #expect(try Self.item("Ramen $12.50", in: viewModel).conversion.isPrice == false)
        #expect(try Self.item("Gyoza $8.50", in: viewModel).conversion.isPrice == true)
        #expect(try Self.item("Table 12", in: viewModel).conversion.isPrice == true)
        #expect(viewModel.detectedItems.ids == editedIDs)
    }

    @Test func aNewPhotoOfTheSameLayoutStartsWithoutTheLastPhotosEdits() async throws {
        let (viewModel, _) = await Self.frozenMenu(readIn: "EUR")
        viewModel.hideConversion(for: try Self.item("Ramen $12.50", in: viewModel).id)

        let nextPhoto = UIImage()
        await viewModel.freezeFrame(capturing: { nextPhoto })
        await viewModel.recognizeStill(in: nextPhoto)

        #expect(try Self.item("Ramen $12.50", in: viewModel).conversion.isPrice == true)
    }

    @Test func importedPhotoLargerThanTheCapFreezesAtTheCappedSize() async throws {
        let viewModel = Self.makeViewModel(stillRecognizer: StubStillTextRecognizer())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let wideStrip = UIGraphicsImageRenderer(size: CGSize(width: 5000, height: 200), format: format).image { context in
            UIColor.gray.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 5000, height: 200))
        }
        let photo = try #require(wideStrip.jpegData(compressionQuality: 0.8))

        await viewModel.importPhoto(loading: { photo })

        let frozen = try #require(viewModel.frozenImage?.cgImage)
        #expect(frozen.width == 4096)
    }
}
