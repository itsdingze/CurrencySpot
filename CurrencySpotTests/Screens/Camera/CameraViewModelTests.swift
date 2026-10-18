import Foundation
import Testing
import UIKit
@testable import CurrencySpot

struct CameraViewModelTests {
    private let isolatedDefaults = IsolatedDefaults()

    private static func makeRatesStore(jpyRate: Double = 150) -> ExchangeRatesStore {
        let ratesStore = ExchangeRatesStore()
        ratesStore.update(
            rates: [
                ExchangeRate(currencyCode: "JPY", rate: jpyRate),
                ExchangeRate(currencyCode: "EUR", rate: 0.9),
                ExchangeRate(currencyCode: "USD", rate: 1),
            ],
            lastUpdated: nil,
            isShowingSampleRates: false
        )
        return ratesStore
    }

    private static func makeAppState() -> AppState {
        AppState(networkMonitor: NetworkMonitor(isConnected: true))
    }

    private static func makeViewModel(
        ratesStore: ExchangeRatesStore? = nil,
        appState: AppState? = nil,
        permissionService: CameraPermissionService = StubCameraPermissionService(status: .authorized),
        torchService: TorchService = InMemoryTorchService(),
        stillRecognizer: StillTextRecognitionService = StubStillTextRecognizer(),
        localeCurrencyCode: CurrencyCode? = "JPY",
        fallbackBaseCurrency: CurrencyCode = "USD",
        defaultTargetCurrency: CurrencyCode = "USD"
    ) -> CameraViewModel {
        CameraViewModel(
            ratesStore: ratesStore ?? makeRatesStore(),
            appState: appState ?? makeAppState(),
            permissionService: permissionService,
            torchService: torchService,
            scanConversionUseCase: ScanConversionUseCase(),
            recognizeStillImageTextUseCase: RecognizeStillImageTextUseCase(recognizer: stillRecognizer),
            calculateConversionUseCase: CalculateConversionUseCase(),
            localeCurrencyCode: localeCurrencyCode,
            fallbackBaseCurrency: fallbackBaseCurrency,
            defaultTargetCurrency: defaultTargetCurrency
        )
    }

    private static func pngData() throws -> Data {
        try #require(UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { _ in }.pngData())
    }

    private static let yenPriceResult = StillRecognitionResult(
        items: [
            RecognizedTextItem(
                id: UUID(),
                transcript: "¥1,200",
                bounds: CGRect(x: 10, y: 10, width: 80, height: 20)
            ),
        ],
        imagePixelSize: CGSize(width: 100, height: 100)
    )

    @Test(arguments: [CameraAuthorizationStatus.notDetermined, .authorized, .denied])
    func initialAuthorizationReflectsSystemStatus(status: CameraAuthorizationStatus) {
        let viewModel = Self.makeViewModel(
            ratesStore: ExchangeRatesStore(),
            permissionService: StubCameraPermissionService(status: status),
            defaultTargetCurrency: "EUR"
        )
        #expect(viewModel.authorization == status)
    }

    @Test(arguments: [(true, CameraAuthorizationStatus.authorized), (false, .denied)])
    func requestAccessTransitionsToUsersAnswer(granted: Bool, expected: CameraAuthorizationStatus) async {
        let viewModel = Self.makeViewModel(
            ratesStore: ExchangeRatesStore(),
            permissionService: StubCameraPermissionService(status: .notDetermined, grantsAccess: granted),
            defaultTargetCurrency: "EUR"
        )

        await viewModel.requestCameraAccess()

        #expect(viewModel.authorization == expected)
    }

    @Test func recognizedItemsBecomeDetectedItemsWithConversions() {
        let viewModel = Self.makeViewModel()
        let priceID = UUID()
        let bounds = CGRect(x: 10, y: 20, width: 100, height: 30)

        viewModel.updateLiveRecognizedItems([
            RecognizedTextItem(id: priceID, transcript: "¥1,200", bounds: bounds),
            RecognizedTextItem(id: UUID(), transcript: "MENU", bounds: .zero),
        ])

        #expect(viewModel.detectedItems == [
            DetectedItem(
                id: priceID,
                transcript: "¥1,200",
                bounds: bounds,
                conversion: .init(amount: 1200, converted: 8, isPrice: true)
            ),
        ])
    }

    @Test func aNumberBesideAStandaloneMarkerBecomesAPrice() {
        let viewModel = Self.makeViewModel()
        let priceID = UUID()
        viewModel.updateLiveRecognizedItems([
            RecognizedTextItem(id: priceID, transcript: "680", bounds: CGRect(x: 0, y: 0, width: 40, height: 20)),
            RecognizedTextItem(id: UUID(), transcript: "円", bounds: CGRect(x: 44, y: 0, width: 18, height: 20)),
        ])
        #expect(viewModel.detectedItems[id: priceID]?.conversion.isPrice == true)
    }

    @Test func aBareNumberWithoutAMarkerStaysAnOutline() {
        let viewModel = Self.makeViewModel()
        let id = UUID()
        viewModel.updateLiveRecognizedItems([
            RecognizedTextItem(id: id, transcript: "680", bounds: CGRect(x: 0, y: 0, width: 40, height: 20)),
        ])
        #expect(viewModel.detectedItems[id: id]?.conversion.isPrice == false)
    }

    @Test func aMarkerPromotedPriceCountsAsFoundEvenAfterDismissal() {
        let viewModel = Self.makeViewModel()
        let priceID = UUID()
        let items = [
            RecognizedTextItem(id: priceID, transcript: "680", bounds: CGRect(x: 0, y: 0, width: 40, height: 20)),
            RecognizedTextItem(id: UUID(), transcript: "円", bounds: CGRect(x: 44, y: 0, width: 18, height: 20)),
        ]
        viewModel.updateLiveRecognizedItems(items)
        #expect(viewModel.hasPrices == true)

        viewModel.toggleConversion(for: priceID)

        #expect(viewModel.detectedItems[id: priceID]?.conversion.isPrice == false)
        #expect(viewModel.hasPrices == true)
    }

    @Test func dismissingAMarkerPromotedPriceSurvivesTheNextFrame() {
        let viewModel = Self.makeViewModel()
        let priceID = UUID()
        let items = [
            RecognizedTextItem(id: priceID, transcript: "680", bounds: CGRect(x: 0, y: 0, width: 40, height: 20)),
            RecognizedTextItem(id: UUID(), transcript: "円", bounds: CGRect(x: 44, y: 0, width: 18, height: 20)),
        ]
        viewModel.updateLiveRecognizedItems(items)
        viewModel.toggleConversion(for: priceID)

        viewModel.updateLiveRecognizedItems(items)

        #expect(viewModel.detectedItems[id: priceID]?.conversion.isPrice == false)
    }

    @Test func changingCurrencyPairReconvertsVisibleItems() {
        let viewModel = Self.makeViewModel()
        viewModel.updateLiveRecognizedItems([
            RecognizedTextItem(id: UUID(), transcript: "¥1,200", bounds: .zero),
        ])

        viewModel.targetCurrency = "EUR"

        #expect(viewModel.detectedItems.first?.conversion.converted == Decimal(string: "7.2"))
    }

    @Test func refreshingConversionsAppliesNewRatesToVisibleItems() {
        let ratesStore = Self.makeRatesStore(jpyRate: 150)
        let viewModel = Self.makeViewModel(ratesStore: ratesStore)
        viewModel.updateLiveRecognizedItems([
            RecognizedTextItem(id: UUID(), transcript: "¥1,200", bounds: .zero),
        ])
        #expect(viewModel.detectedItems.first?.conversion.converted == 8)
        ratesStore.update(
            rates: Self.makeRatesStore(jpyRate: 120).rates,
            lastUpdated: nil,
            isShowingSampleRates: false
        )

        viewModel.refreshConversions()

        #expect(viewModel.detectedItems.first?.conversion.converted == 10)
    }

    @Test func swappingExchangesBaseAndTarget() {
        let viewModel = Self.makeViewModel()

        viewModel.swapCurrencies()

        #expect(viewModel.baseCurrency == "USD")
        #expect(viewModel.targetCurrency == "JPY")
    }

    @Test func baseAutodetectsFromLocaleWhenRatesExist() {
        #expect(Self.makeViewModel(localeCurrencyCode: "EUR").baseCurrency == "EUR")
    }

    @Test func baseFallsBackWhenLocaleCurrencyUnsupported() {
        #expect(Self.makeViewModel(localeCurrencyCode: "XXX").baseCurrency == "USD")
    }

    @Test func manualBaseChoiceWinsOverAutodetection() {
        let viewModel = Self.makeViewModel(localeCurrencyCode: "JPY")
        viewModel.baseCurrency = "EUR"
        #expect(viewModel.baseCurrency == "EUR")
    }

    @Test func togglingANonPricePinsAndUnpinsItsBadge() {
        let viewModel = Self.makeViewModel()
        let id = UUID()
        viewModel.updateLiveRecognizedItems([
            RecognizedTextItem(id: id, transcript: "1200", bounds: .zero),
        ])
        #expect(viewModel.detectedItems.first?.conversion.isPrice == false)

        viewModel.toggleConversion(for: id)
        #expect(viewModel.detectedItems.first?.conversion.isPrice == true)
        #expect(viewModel.detectedItems.first?.conversion.converted == 8)

        viewModel.toggleConversion(for: id)
        #expect(viewModel.detectedItems.first?.conversion.isPrice == false)
    }

    @Test func togglingADetectedPriceHidesAndRestoresItsBadge() {
        let viewModel = Self.makeViewModel()
        let id = UUID()
        viewModel.updateLiveRecognizedItems([
            RecognizedTextItem(id: id, transcript: "¥1,200", bounds: .zero),
        ])
        #expect(viewModel.detectedItems.first?.conversion.isPrice == true)

        viewModel.toggleConversion(for: id)
        #expect(viewModel.detectedItems.first?.conversion.isPrice == false)

        viewModel.toggleConversion(for: id)
        #expect(viewModel.detectedItems.first?.conversion.isPrice == true)
    }

    @Test func tappingABadgeOpensItsDetail() {
        let viewModel = Self.makeViewModel()
        let id = UUID()
        viewModel.updateLiveRecognizedItems([
            RecognizedTextItem(id: id, transcript: "¥1,200", bounds: .zero),
        ])

        viewModel.showBadgeDetail(for: id)

        guard case let .badgeDetail(item) = viewModel.destination else {
            Issue.record("expected badgeDetail destination, got \(String(describing: viewModel.destination))")
            return
        }
        #expect(item.id == id)
    }

    @Test func hidingFromDetailSuppressesTheBadgeAndClosesTheSheet() {
        let viewModel = Self.makeViewModel()
        let id = UUID()
        viewModel.updateLiveRecognizedItems([
            RecognizedTextItem(id: id, transcript: "¥1,200", bounds: .zero),
        ])
        viewModel.showBadgeDetail(for: id)

        viewModel.hideConversion(for: id)

        #expect(viewModel.detectedItems.first?.conversion.isPrice == false)
        #expect(viewModel.destination == nil)
    }

    @Test func hidingAPinnedNonPriceUnpinsIt() {
        let viewModel = Self.makeViewModel()
        let id = UUID()
        viewModel.updateLiveRecognizedItems([
            RecognizedTextItem(id: id, transcript: "1200", bounds: .zero),
        ])
        viewModel.toggleConversion(for: id)
        #expect(viewModel.detectedItems.first?.conversion.isPrice == true)

        viewModel.hideConversion(for: id)

        #expect(viewModel.detectedItems.first?.conversion.isPrice == false)
    }

    @Test func openInConverterPrefillsCalculatorAndSwitchesToConvertTab() throws {
        let appState = Self.makeAppState()
        let calculator = makeIsolatedCalculatorViewModel(defaults: try isolatedDefaults.make(), appState: appState)
        let viewModel = Self.makeViewModel(
            ratesStore: ExchangeRatesStore(),
            appState: appState,
            localeCurrencyCode: "JPY",
            fallbackBaseCurrency: "JPY",
            defaultTargetCurrency: "USD"
        )
        appState.selectedTab = .camera
        let item = DetectedItem(
            id: UUID(),
            transcript: "¥1,200",
            bounds: .zero,
            conversion: .init(amount: 1200, converted: 8, isPrice: true)
        )

        viewModel.openInConverter(item)

        #expect(appState.pendingConversion == PendingConversion(
            baseCurrency: "JPY",
            targetCurrency: "USD",
            amountInput: "120000"
        ))
        #expect(appState.selectedTab == .convert)
        #expect(viewModel.destination == nil)

        calculator.consumePendingConversion()

        #expect(calculator.baseCurrency == "JPY")
        #expect(calculator.targetCurrency == "USD")
        #expect(calculator.inputAmountString == "120000")
        #expect(appState.pendingConversion == nil)
    }

    // MARK: - Torch

    @Test func togglingTorchTracksTheDevicesActualState() {
        let viewModel = Self.makeViewModel()
        #expect(viewModel.isTorchOn == false)

        viewModel.toggleTorch()
        #expect(viewModel.isTorchOn == true)

        viewModel.toggleTorch()
        #expect(viewModel.isTorchOn == false)
    }

    @Test func torchStaysOffWhenTheDeviceHasNone() {
        let viewModel = Self.makeViewModel(torchService: InMemoryTorchService(hasTorch: false))

        viewModel.toggleTorch()

        #expect(viewModel.isTorchOn == false)
    }

    @Test func turningTheTorchOffSwitchesTheDeviceOff() {
        let torch = InMemoryTorchService()
        let viewModel = Self.makeViewModel(torchService: torch)
        viewModel.toggleTorch()

        viewModel.turnTorchOff()

        #expect(viewModel.isTorchOn == false)
        #expect(torch.requestedStates == [true, false])
    }

    @Test func turningAnUnlitTorchOffLeavesTheDeviceAlone() {
        let torch = InMemoryTorchService()
        let viewModel = Self.makeViewModel(torchService: torch)

        viewModel.turnTorchOff()

        #expect(viewModel.isTorchOn == false)
        #expect(torch.requestedStates.isEmpty)
    }

    @Test func freezingTurnsTheTorchOff() async {
        let viewModel = Self.makeViewModel()
        viewModel.toggleTorch()
        #expect(viewModel.isTorchOn == true)

        await viewModel.freezeFrame(capturing: { UIImage() })

        #expect(viewModel.isTorchOn == false)
    }

    // MARK: - Freeze and Resume

    @Test func liveUpdatesAreIgnoredWhileFrozen() async {
        let viewModel = Self.makeViewModel(stillRecognizer: StubStillTextRecognizer(result: Self.yenPriceResult))
        let image = UIImage()
        await viewModel.freezeFrame(capturing: { image })
        viewModel.stillViewportChanged(CGSize(width: 100, height: 100))
        await viewModel.recognizeStill(in: image)
        #expect(viewModel.detectedItems.count == 1)

        viewModel.updateLiveRecognizedItems([])

        #expect(viewModel.detectedItems.count == 1)
    }

    @Test func freezingPausesScanningAndResumingClearsTheStill() async {
        let viewModel = Self.makeViewModel()
        viewModel.updateLiveRecognizedItems([
            RecognizedTextItem(id: UUID(), transcript: "¥1,200", bounds: .zero),
        ])
        let image = UIImage()

        await viewModel.freezeFrame(capturing: { image })

        #expect(viewModel.isScanning == false)
        #expect(viewModel.frozenImage === image)
        #expect(viewModel.detectedItems.isEmpty)

        viewModel.resumeLiveScanning()

        #expect(viewModel.isScanning == true)
        #expect(viewModel.frozenImage == nil)
        #expect(viewModel.detectedItems.isEmpty)
    }

    // MARK: - Still Recognition Status

    @Test func freezingMarksStillRecognitionInFlight() async {
        let viewModel = Self.makeViewModel()
        #expect(viewModel.isRecognizingStill == false)

        await viewModel.freezeFrame(capturing: { UIImage() })

        #expect(viewModel.isRecognizingStill == true)
    }

    @Test func recognizingTheStillPopulatesItemsAndClearsTheInFlightFlag() async {
        let viewModel = Self.makeViewModel(stillRecognizer: StubStillTextRecognizer(result: Self.yenPriceResult))
        let image = UIImage()
        await viewModel.freezeFrame(capturing: { image })
        viewModel.stillViewportChanged(CGSize(width: 100, height: 100))

        await viewModel.recognizeStill(in: image)

        #expect(viewModel.detectedItems.count == 1)
        #expect(viewModel.detectedItems.first?.conversion.isPrice == true)
        #expect(viewModel.isRecognizingStill == false)
    }

    @Test func stillItemsFollowViewportChanges() async {
        let viewModel = Self.makeViewModel(stillRecognizer: StubStillTextRecognizer(result: Self.yenPriceResult))
        let image = UIImage()
        await viewModel.freezeFrame(capturing: { image })
        viewModel.stillViewportChanged(CGSize(width: 100, height: 100))
        await viewModel.recognizeStill(in: image)

        viewModel.stillViewportChanged(CGSize(width: 200, height: 100))

        #expect(viewModel.detectedItems.first?.bounds == CGRect(x: 60, y: 10, width: 80, height: 20))
    }

    @Test func stillRecognitionFailureSurfacesScanError() async {
        struct RecognitionError: Error {}
        let appState = Self.makeAppState()
        let viewModel = Self.makeViewModel(
            appState: appState,
            stillRecognizer: StubStillTextRecognizer(failure: RecognitionError())
        )
        let image = UIImage()
        await viewModel.freezeFrame(capturing: { image })

        await viewModel.recognizeStill(in: image)

        #expect(appState.errorHandler.currentError == .textRecognitionFailed)
        #expect(viewModel.isRecognizingStill == false)
    }

    @Test func stillResultsForAReplacedFrameAreIgnored() async {
        let viewModel = Self.makeViewModel(stillRecognizer: StubStillTextRecognizer(result: Self.yenPriceResult))
        await viewModel.freezeFrame(capturing: { UIImage() })

        await viewModel.recognizeStill(in: UIImage())

        #expect(viewModel.detectedItems.isEmpty)
        #expect(viewModel.isRecognizingStill == true)
    }

    @Test func stillResultsAfterResumeAreIgnored() async {
        let viewModel = Self.makeViewModel(stillRecognizer: StubStillTextRecognizer(result: Self.yenPriceResult))
        let image = UIImage()
        await viewModel.freezeFrame(capturing: { image })
        viewModel.resumeLiveScanning()

        await viewModel.recognizeStill(in: image)

        #expect(viewModel.detectedItems.isEmpty)
        #expect(viewModel.frozenImage == nil)
    }

    @Test func resumingLiveScanningClearsTheInFlightFlag() async {
        let viewModel = Self.makeViewModel()
        await viewModel.freezeFrame(capturing: { UIImage() })

        viewModel.resumeLiveScanning()

        #expect(viewModel.isRecognizingStill == false)
    }

    @Test func hasPricesReflectsDetectedPrices() {
        let viewModel = Self.makeViewModel()
        #expect(viewModel.hasPrices == false)

        viewModel.updateLiveRecognizedItems([
            RecognizedTextItem(id: UUID(), transcript: "MENU", bounds: .zero),
        ])
        #expect(viewModel.hasPrices == false)

        viewModel.updateLiveRecognizedItems([
            RecognizedTextItem(id: UUID(), transcript: "¥1,200", bounds: .zero),
        ])
        #expect(viewModel.hasPrices == true)
    }

    @Test func suppressingTheOnlyPriceStillCountsAsFound() {
        let viewModel = Self.makeViewModel()
        let id = UUID()
        viewModel.updateLiveRecognizedItems([
            RecognizedTextItem(id: id, transcript: "¥1,200", bounds: .zero),
        ])

        viewModel.toggleConversion(for: id)

        #expect(viewModel.detectedItems.first?.conversion.isPrice == false)
        #expect(viewModel.hasPrices == true)
    }

    // MARK: - Capture and Import Failures

    private struct StubError: Error {}

    @Test func freezeFrameWithoutAScannerStaysLiveAndSilent() async {
        let appState = Self.makeAppState()
        let viewModel = Self.makeViewModel(appState: appState)

        await viewModel.freezeFrame(capturing: { nil })

        #expect(viewModel.isScanning == true)
        #expect(viewModel.frozenImage == nil)
        #expect(appState.errorHandler.currentError == nil)
    }

    @Test func freezeFrameFailureSurfacesCaptureError() async {
        let appState = Self.makeAppState()
        let viewModel = Self.makeViewModel(appState: appState)

        await viewModel.freezeFrame(capturing: { throw StubError() })

        #expect(viewModel.isScanning == true)
        #expect(viewModel.frozenImage == nil)
        #expect(appState.errorHandler.currentError == .cameraCaptureFailed)
    }

    @Test func freezeFrameCancellationStaysSilent() async {
        let appState = Self.makeAppState()
        let viewModel = Self.makeViewModel(appState: appState)

        await viewModel.freezeFrame(capturing: { throw CancellationError() })

        #expect(appState.errorHandler.currentError == nil)
    }

    @Test func importPhotoFreezesOnDecodableImageData() async throws {
        let viewModel = Self.makeViewModel()
        let imageData = try Self.pngData()

        await viewModel.importPhoto(loading: { imageData })

        #expect(viewModel.isScanning == false)
        #expect(viewModel.frozenImage != nil)
    }

    @Test func importedEXIFRotatedPhotoFreezesUpright() async throws {
        let viewModel = Self.makeViewModel()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let landscapePixels = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 60), format: format).image { context in
            UIColor.gray.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 120, height: 60))
        }
        let cgImage = try #require(landscapePixels.cgImage)
        let portraitPhoto = try #require(UIImage(cgImage: cgImage, scale: 1, orientation: .right).jpegData(compressionQuality: 1))

        await viewModel.importPhoto(loading: { portraitPhoto })

        let frozen = try #require(viewModel.frozenImage)
        #expect(frozen.size.width < frozen.size.height)
    }

    @Test func importPhotoWithNoDataSurfacesImportError() async {
        let appState = Self.makeAppState()
        let viewModel = Self.makeViewModel(appState: appState)

        await viewModel.importPhoto(loading: { nil })

        #expect(viewModel.frozenImage == nil)
        #expect(appState.errorHandler.currentError == .photoImportFailed)
    }

    @Test func importPhotoWithUndecodableDataSurfacesImportError() async {
        let appState = Self.makeAppState()
        let viewModel = Self.makeViewModel(appState: appState)

        await viewModel.importPhoto(loading: { Data("not an image".utf8) })

        #expect(viewModel.frozenImage == nil)
        #expect(appState.errorHandler.currentError == .photoImportFailed)
    }

    @Test func importPhotoLoadFailureSurfacesImportError() async {
        let appState = Self.makeAppState()
        let viewModel = Self.makeViewModel(appState: appState)

        await viewModel.importPhoto(loading: { throw StubError() })

        #expect(viewModel.frozenImage == nil)
        #expect(appState.errorHandler.currentError == .photoImportFailed)
    }

    // MARK: - Stale Freeze Requests

    @Test func staleCaptureCannotReplaceANewerFreeze() async throws {
        let viewModel = Self.makeViewModel()
        let imported = try Self.pngData()
        let staleCapture = UIImage()

        await viewModel.freezeFrame(capturing: {
            await viewModel.importPhoto(loading: { imported })
            return staleCapture
        })

        #expect(viewModel.frozenImage != nil)
        #expect(viewModel.frozenImage !== staleCapture)
    }

    @Test func staleCaptureCannotRefreezeAfterResume() async throws {
        let viewModel = Self.makeViewModel()
        let imported = try Self.pngData()

        await viewModel.freezeFrame(capturing: {
            await viewModel.importPhoto(loading: { imported })
            viewModel.resumeLiveScanning()
            return UIImage()
        })

        #expect(viewModel.frozenImage == nil)
        #expect(viewModel.isScanning == true)
    }

    @Test func staleCaptureFailureStaysSilent() async throws {
        let appState = Self.makeAppState()
        let viewModel = Self.makeViewModel(appState: appState)
        let imported = try Self.pngData()

        await viewModel.freezeFrame(capturing: {
            await viewModel.importPhoto(loading: { imported })
            throw StubError()
        })

        #expect(appState.errorHandler.currentError == nil)
        #expect(viewModel.frozenImage != nil)
    }
}
