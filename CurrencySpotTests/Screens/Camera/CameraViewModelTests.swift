import Foundation
import Testing
import UIKit
@testable import CurrencySpot

private final class MockCameraPermissionService: CameraPermissionService {
    let status: CameraAuthorizationStatus
    let grantsAccess: Bool

    init(status: CameraAuthorizationStatus, grantsAccess: Bool = false) {
        self.status = status
        self.grantsAccess = grantsAccess
    }

    func currentStatus() -> CameraAuthorizationStatus { status }
    func requestAccess() async -> Bool { grantsAccess }
}

private struct MockTorchService: TorchService {
    let available: Bool

    func setTorch(enabled: Bool) -> Bool { available && enabled }
}

private struct MockStillTextRecognitionService: StillTextRecognitionService {
    let handler: @Sendable (UIImage) async throws -> StillRecognitionResult

    func recognize(_ image: UIImage) async throws -> StillRecognitionResult {
        try await handler(image)
    }
}

struct CameraViewModelTests {
    private static func makeScanningViewModel(
        appState: AppState? = nil,
        stillRecognizer: StillTextRecognitionService = MockStillTextRecognitionService(handler: { _ in .empty }),
        localeCurrencyCode: CurrencyCode? = "JPY",
        torchAvailable: Bool = true
    ) -> CameraViewModel {
        let appState = appState ?? AppState()
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
            permissionService: MockCameraPermissionService(status: .authorized),
            stillTextRecognizer: stillRecognizer,
            torchService: MockTorchService(available: torchAvailable),
            localeCurrencyCode: localeCurrencyCode,
            fallbackBaseCurrency: "USD",
            defaultTargetCurrency: "USD"
        )
    }

    private static func pngData() throws -> Data {
        try #require(UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { _ in }.pngData())
    }

    @Test(arguments: [CameraAuthorizationStatus.notDetermined, .authorized, .denied])
    func initialAuthorizationReflectsSystemStatus(status: CameraAuthorizationStatus) {
        let viewModel = CameraViewModel(
            ratesStore: ExchangeRatesStore(),
            appState: AppState(networkMonitor: NetworkMonitor(monitorsPathUpdates: false)),
            permissionService: MockCameraPermissionService(status: status),
            fallbackBaseCurrency: "USD",
            defaultTargetCurrency: "EUR"
        )
        #expect(viewModel.authorization == status)
    }

    @Test(arguments: [(true, CameraAuthorizationStatus.authorized), (false, .denied)])
    func requestAccessTransitionsToUsersAnswer(granted: Bool, expected: CameraAuthorizationStatus) async {
        let service = MockCameraPermissionService(status: .notDetermined, grantsAccess: granted)
        let viewModel = CameraViewModel(
            ratesStore: ExchangeRatesStore(),
            appState: AppState(networkMonitor: NetworkMonitor(monitorsPathUpdates: false)),
            permissionService: service,
            fallbackBaseCurrency: "USD",
            defaultTargetCurrency: "EUR"
        )

        await viewModel.requestCameraAccess()

        #expect(viewModel.authorization == expected)
    }

    @Test func recognizedItemsBecomeDetectedItemsWithConversions() {
        let viewModel = Self.makeScanningViewModel()
        let priceID = UUID()
        let bounds = CGRect(x: 10, y: 20, width: 100, height: 30)

        viewModel.updateRecognizedItems([
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
        let viewModel = Self.makeScanningViewModel()
        let priceID = UUID()
        viewModel.updateRecognizedItems([
            RecognizedTextItem(id: priceID, transcript: "680", bounds: CGRect(x: 0, y: 0, width: 40, height: 20)),
            RecognizedTextItem(id: UUID(), transcript: "円", bounds: CGRect(x: 44, y: 0, width: 18, height: 20)),
        ])
        #expect(viewModel.detectedItems[id: priceID]?.conversion.isPrice == true)
    }

    @Test func aBareNumberWithoutAMarkerStaysAnOutline() {
        let viewModel = Self.makeScanningViewModel()
        let id = UUID()
        viewModel.updateRecognizedItems([
            RecognizedTextItem(id: id, transcript: "680", bounds: CGRect(x: 0, y: 0, width: 40, height: 20)),
        ])
        #expect(viewModel.detectedItems[id: id]?.conversion.isPrice == false)
    }

    @Test func aMarkerPromotedPriceCountsAsFoundEvenAfterDismissal() {
        let viewModel = Self.makeScanningViewModel()
        let priceID = UUID()
        let items = [
            RecognizedTextItem(id: priceID, transcript: "680", bounds: CGRect(x: 0, y: 0, width: 40, height: 20)),
            RecognizedTextItem(id: UUID(), transcript: "円", bounds: CGRect(x: 44, y: 0, width: 18, height: 20)),
        ]
        viewModel.updateRecognizedItems(items)
        #expect(viewModel.hasPrices == true)

        viewModel.toggleConversion(for: priceID)

        #expect(viewModel.detectedItems[id: priceID]?.conversion.isPrice == false)
        #expect(viewModel.hasPrices == true)
    }

    @Test func dismissingAMarkerPromotedPriceSurvivesTheNextFrame() {
        let viewModel = Self.makeScanningViewModel()
        let priceID = UUID()
        let items = [
            RecognizedTextItem(id: priceID, transcript: "680", bounds: CGRect(x: 0, y: 0, width: 40, height: 20)),
            RecognizedTextItem(id: UUID(), transcript: "円", bounds: CGRect(x: 44, y: 0, width: 18, height: 20)),
        ]
        viewModel.updateRecognizedItems(items)
        viewModel.toggleConversion(for: priceID)

        viewModel.updateRecognizedItems(items)

        #expect(viewModel.detectedItems[id: priceID]?.conversion.isPrice == false)
    }

    @Test func changingCurrencyPairReconvertsVisibleItems() {
        let viewModel = Self.makeScanningViewModel()
        viewModel.updateRecognizedItems([
            RecognizedTextItem(id: UUID(), transcript: "¥1,200", bounds: .zero),
        ])

        viewModel.targetCurrency = "EUR"

        #expect(viewModel.detectedItems.first?.conversion.converted == Decimal(string: "7.2"))
    }

    @Test func swappingExchangesBaseAndTarget() {
        let viewModel = Self.makeScanningViewModel()

        viewModel.swapCurrencies()

        #expect(viewModel.baseCurrency == "USD")
        #expect(viewModel.targetCurrency == "JPY")
    }

    @Test func baseAutodetectsFromLocaleWhenRatesExist() {
        #expect(Self.makeScanningViewModel(localeCurrencyCode: "EUR").baseCurrency == "EUR")
    }

    @Test func baseFallsBackWhenLocaleCurrencyUnsupported() {
        #expect(Self.makeScanningViewModel(localeCurrencyCode: "XXX").baseCurrency == "USD")
    }

    @Test func manualBaseChoiceWinsOverAutodetection() {
        let viewModel = Self.makeScanningViewModel(localeCurrencyCode: "JPY")
        viewModel.baseCurrency = "EUR"
        #expect(viewModel.baseCurrency == "EUR")
    }

    @Test func togglingANonPricePinsAndUnpinsItsBadge() {
        let viewModel = Self.makeScanningViewModel()
        let id = UUID()
        viewModel.updateRecognizedItems([
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
        let viewModel = Self.makeScanningViewModel()
        let id = UUID()
        viewModel.updateRecognizedItems([
            RecognizedTextItem(id: id, transcript: "¥1,200", bounds: .zero),
        ])
        #expect(viewModel.detectedItems.first?.conversion.isPrice == true)

        viewModel.toggleConversion(for: id)
        #expect(viewModel.detectedItems.first?.conversion.isPrice == false)

        viewModel.toggleConversion(for: id)
        #expect(viewModel.detectedItems.first?.conversion.isPrice == true)
    }

    @Test func tappingABadgeOpensItsDetail() {
        let viewModel = Self.makeScanningViewModel()
        let id = UUID()
        viewModel.updateRecognizedItems([
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
        let viewModel = Self.makeScanningViewModel()
        let id = UUID()
        viewModel.updateRecognizedItems([
            RecognizedTextItem(id: id, transcript: "¥1,200", bounds: .zero),
        ])
        viewModel.showBadgeDetail(for: id)

        viewModel.hideConversion(for: id)

        #expect(viewModel.detectedItems.first?.conversion.isPrice == false)
        #expect(viewModel.destination == nil)
    }

    @Test func hidingAPinnedNonPriceUnpinsIt() {
        let viewModel = Self.makeScanningViewModel()
        let id = UUID()
        viewModel.updateRecognizedItems([
            RecognizedTextItem(id: id, transcript: "1200", bounds: .zero),
        ])
        viewModel.toggleConversion(for: id)
        #expect(viewModel.detectedItems.first?.conversion.isPrice == true)

        viewModel.hideConversion(for: id)

        #expect(viewModel.detectedItems.first?.conversion.isPrice == false)
    }

    @Test func openInConverterPrefillsCalculatorAndSwitchesToConvertTab() {
        let appState = AppState()
        let calculator = makeIsolatedCalculatorViewModel(appState: appState)
        let viewModel = CameraViewModel(
            ratesStore: ExchangeRatesStore(),
            appState: appState,
            permissionService: MockCameraPermissionService(status: .authorized),
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

    @Test func togglingTorchTracksTheDevicesActualState() {
        let viewModel = Self.makeScanningViewModel()
        #expect(viewModel.isTorchOn == false)

        viewModel.toggleTorch()
        #expect(viewModel.isTorchOn == true)

        viewModel.toggleTorch()
        #expect(viewModel.isTorchOn == false)
    }

    @Test func torchStaysOffWhenTheDeviceHasNone() {
        let viewModel = Self.makeScanningViewModel(torchAvailable: false)

        viewModel.toggleTorch()

        #expect(viewModel.isTorchOn == false)
    }

    @Test func freezingTurnsTheTorchOff() async {
        let viewModel = Self.makeScanningViewModel()
        viewModel.toggleTorch()
        #expect(viewModel.isTorchOn == true)

        await viewModel.freezeFrame(capturing: { UIImage() })

        #expect(viewModel.isTorchOn == false)
    }

    @Test func liveUpdatesAreIgnoredWhileFrozen() async {
        let viewModel = Self.makeScanningViewModel()
        await viewModel.freezeFrame(capturing: { UIImage() })
        viewModel.updateRecognizedItems([
            RecognizedTextItem(id: UUID(), transcript: "¥1,200", bounds: .zero),
        ])
        #expect(viewModel.detectedItems.count == 1)

        viewModel.updateLiveRecognizedItems([])

        #expect(viewModel.detectedItems.count == 1)
    }

    @Test func freezingPausesScanningAndResumingClearsTheStill() async {
        let viewModel = Self.makeScanningViewModel()
        viewModel.updateRecognizedItems([
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
        let viewModel = Self.makeScanningViewModel()
        #expect(viewModel.isRecognizingStill == false)

        await viewModel.freezeFrame(capturing: { UIImage() })

        #expect(viewModel.isRecognizingStill == true)
    }

    @Test func recognizingTheStillPopulatesItemsAndClearsTheInFlightFlag() async {
        let result = StillRecognitionResult(
            items: [
                RecognizedTextItem(
                    id: UUID(),
                    transcript: "¥1,200",
                    bounds: CGRect(x: 10, y: 10, width: 80, height: 20)
                ),
            ],
            imagePixelSize: CGSize(width: 100, height: 100)
        )
        let viewModel = Self.makeScanningViewModel(
            stillRecognizer: MockStillTextRecognitionService(handler: { _ in result })
        )
        let image = UIImage()
        await viewModel.freezeFrame(capturing: { image })
        viewModel.stillViewportChanged(CGSize(width: 100, height: 100))

        await viewModel.recognizeStill(in: image)

        #expect(viewModel.detectedItems.count == 1)
        #expect(viewModel.detectedItems.first?.conversion.isPrice == true)
        #expect(viewModel.isRecognizingStill == false)
    }

    @Test func stillRecognitionFailureSurfacesScanError() async {
        struct RecognitionError: Error {}
        let appState = AppState()
        let viewModel = Self.makeScanningViewModel(
            appState: appState,
            stillRecognizer: MockStillTextRecognitionService(handler: { _ in throw RecognitionError() })
        )
        let image = UIImage()
        await viewModel.freezeFrame(capturing: { image })

        await viewModel.recognizeStill(in: image)

        #expect(appState.errorHandler.currentError == .textRecognitionFailed)
        #expect(viewModel.isRecognizingStill == false)
    }

    @Test func stillResultsForAReplacedFrameAreIgnored() async {
        let result = StillRecognitionResult(
            items: [RecognizedTextItem(id: UUID(), transcript: "¥1,200", bounds: .zero)],
            imagePixelSize: CGSize(width: 100, height: 100)
        )
        let viewModel = Self.makeScanningViewModel(
            stillRecognizer: MockStillTextRecognitionService(handler: { _ in result })
        )
        await viewModel.freezeFrame(capturing: { UIImage() })

        await viewModel.recognizeStill(in: UIImage())

        #expect(viewModel.detectedItems.isEmpty)
        #expect(viewModel.isRecognizingStill == true)
    }

    @Test func stillResultsAfterResumeAreIgnored() async {
        let result = StillRecognitionResult(
            items: [RecognizedTextItem(id: UUID(), transcript: "¥1,200", bounds: .zero)],
            imagePixelSize: CGSize(width: 100, height: 100)
        )
        let viewModel = Self.makeScanningViewModel(
            stillRecognizer: MockStillTextRecognitionService(handler: { _ in result })
        )
        let image = UIImage()
        await viewModel.freezeFrame(capturing: { image })
        viewModel.resumeLiveScanning()

        await viewModel.recognizeStill(in: image)

        #expect(viewModel.detectedItems.isEmpty)
        #expect(viewModel.frozenImage == nil)
    }

    @Test func resumingLiveScanningClearsTheInFlightFlag() async {
        let viewModel = Self.makeScanningViewModel()
        await viewModel.freezeFrame(capturing: { UIImage() })

        viewModel.resumeLiveScanning()

        #expect(viewModel.isRecognizingStill == false)
    }

    @Test func hasPricesReflectsDetectedPrices() {
        let viewModel = Self.makeScanningViewModel()
        #expect(viewModel.hasPrices == false)

        viewModel.updateRecognizedItems([
            RecognizedTextItem(id: UUID(), transcript: "MENU", bounds: .zero),
        ])
        #expect(viewModel.hasPrices == false)

        viewModel.updateRecognizedItems([
            RecognizedTextItem(id: UUID(), transcript: "¥1,200", bounds: .zero),
        ])
        #expect(viewModel.hasPrices == true)
    }

    @Test func suppressingTheOnlyPriceStillCountsAsFound() {
        let viewModel = Self.makeScanningViewModel()
        let id = UUID()
        viewModel.updateRecognizedItems([
            RecognizedTextItem(id: id, transcript: "¥1,200", bounds: .zero),
        ])

        viewModel.toggleConversion(for: id)

        #expect(viewModel.detectedItems.first?.conversion.isPrice == false)
        #expect(viewModel.hasPrices == true)
    }

    // MARK: - Capture and Import Failures

    private struct StubError: Error {}

    @Test func freezeFrameWithoutAScannerStaysLiveAndSilent() async {
        let appState = AppState()
        let viewModel = Self.makeScanningViewModel(appState: appState)

        await viewModel.freezeFrame(capturing: { nil })

        #expect(viewModel.isScanning == true)
        #expect(viewModel.frozenImage == nil)
        #expect(appState.errorHandler.currentError == nil)
    }

    @Test func freezeFrameFailureSurfacesCaptureError() async {
        let appState = AppState()
        let viewModel = Self.makeScanningViewModel(appState: appState)

        await viewModel.freezeFrame(capturing: { throw StubError() })

        #expect(viewModel.isScanning == true)
        #expect(viewModel.frozenImage == nil)
        #expect(appState.errorHandler.currentError == .cameraCaptureFailed)
    }

    @Test func freezeFrameCancellationStaysSilent() async {
        let appState = AppState()
        let viewModel = Self.makeScanningViewModel(appState: appState)

        await viewModel.freezeFrame(capturing: { throw CancellationError() })

        #expect(appState.errorHandler.currentError == nil)
    }

    @Test func importPhotoFreezesOnDecodableImageData() async throws {
        let viewModel = Self.makeScanningViewModel()
        let imageData = try Self.pngData()

        await viewModel.importPhoto(loading: { imageData })

        #expect(viewModel.isScanning == false)
        #expect(viewModel.frozenImage != nil)
    }

    @Test func importedEXIFRotatedPhotoFreezesUpright() async throws {
        let viewModel = Self.makeScanningViewModel()
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
        let appState = AppState()
        let viewModel = Self.makeScanningViewModel(appState: appState)

        await viewModel.importPhoto(loading: { nil })

        #expect(viewModel.frozenImage == nil)
        #expect(appState.errorHandler.currentError == .photoImportFailed)
    }

    @Test func importPhotoWithUndecodableDataSurfacesImportError() async {
        let appState = AppState()
        let viewModel = Self.makeScanningViewModel(appState: appState)

        await viewModel.importPhoto(loading: { Data("not an image".utf8) })

        #expect(viewModel.frozenImage == nil)
        #expect(appState.errorHandler.currentError == .photoImportFailed)
    }

    @Test func importPhotoLoadFailureSurfacesImportError() async {
        let appState = AppState()
        let viewModel = Self.makeScanningViewModel(appState: appState)

        await viewModel.importPhoto(loading: { throw StubError() })

        #expect(viewModel.frozenImage == nil)
        #expect(appState.errorHandler.currentError == .photoImportFailed)
    }

    // MARK: - Stale Freeze Requests

    @Test func staleCaptureCannotReplaceANewerFreeze() async throws {
        let viewModel = Self.makeScanningViewModel()
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
        let viewModel = Self.makeScanningViewModel()
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
        let appState = AppState()
        let viewModel = Self.makeScanningViewModel(appState: appState)
        let imported = try Self.pngData()

        await viewModel.freezeFrame(capturing: {
            await viewModel.importPhoto(loading: { imported })
            throw StubError()
        })

        #expect(appState.errorHandler.currentError == nil)
        #expect(viewModel.frozenImage != nil)
    }
}
