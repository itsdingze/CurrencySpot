//
//  CameraViewModelTests.swift
//  CurrencySpotTests
//

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

@MainActor
struct CameraViewModelTests {
    /// VM wired with USD-normalized mock rates and a JPY → USD pair.
    private static func makeScanningViewModel(
        localeCurrencyCode: String? = "JPY",
        torchAvailable: Bool = true
    ) -> CameraViewModel {
        let calculatorViewModel = CalculatorViewModel(service: MockExchangeRateService())
        calculatorViewModel.availableRates = [
            ExchangeRateDataValue(currencyCode: "JPY", rate: 150),
            ExchangeRateDataValue(currencyCode: "EUR", rate: 0.9),
            ExchangeRateDataValue(currencyCode: "USD", rate: 1),
        ]
        return CameraViewModel(
            calculatorViewModel: calculatorViewModel,
            permissionService: MockCameraPermissionService(status: .authorized),
            torchService: MockTorchService(available: torchAvailable),
            localeCurrencyCode: localeCurrencyCode,
            fallbackBaseCurrency: "USD",
            defaultTargetCurrency: "USD"
        )
    }

    @Test(arguments: [CameraAuthorizationStatus.notDetermined, .authorized, .denied])
    func initialAuthorizationReflectsSystemStatus(status: CameraAuthorizationStatus) {
        let viewModel = CameraViewModel(
            calculatorViewModel: CalculatorViewModel(service: MockExchangeRateService()),
            permissionService: MockCameraPermissionService(status: status)
        )
        #expect(viewModel.authorization == status)
    }

    @Test(arguments: [(true, CameraAuthorizationStatus.authorized), (false, .denied)])
    func requestAccessTransitionsToUsersAnswer(granted: Bool, expected: CameraAuthorizationStatus) async {
        let service = MockCameraPermissionService(status: .notDetermined, grantsAccess: granted)
        let viewModel = CameraViewModel(
            calculatorViewModel: CalculatorViewModel(service: MockExchangeRateService()),
            permissionService: service
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

    @Test func changingCurrencyPairReconvertsVisibleItems() {
        let viewModel = Self.makeScanningViewModel()
        viewModel.updateRecognizedItems([
            RecognizedTextItem(id: UUID(), transcript: "¥1,200", bounds: .zero),
        ])

        viewModel.targetCurrency = "EUR"

        #expect(viewModel.detectedItems.first?.conversion.converted == Decimal(string: "7.2"))
    }

    @Test func swappingExchangesBaseAndTarget() {
        let viewModel = Self.makeScanningViewModel()  // base JPY (locale), target USD

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

    @Test func openInConverterPrefillsCalculatorAndSwitchesToConvertTab() {
        let calculator = CalculatorViewModel(service: MockExchangeRateService())
        let viewModel = CameraViewModel(
            calculatorViewModel: calculator,
            permissionService: MockCameraPermissionService(status: .authorized),
            localeCurrencyCode: "JPY",
            fallbackBaseCurrency: "JPY",
            defaultTargetCurrency: "USD"
        )
        AppState.shared.selectedTab = 1
        let item = DetectedItem(
            id: UUID(),
            transcript: "¥1,200",
            bounds: .zero,
            conversion: .init(amount: 1200, converted: 8, isPrice: true)
        )

        viewModel.openInConverter(item)

        #expect(calculator.baseCurrency == "JPY")
        #expect(calculator.targetCurrency == "USD")
        #expect(calculator.inputAmountString == "120000")
        #expect(AppState.shared.selectedTab == 0)
        #expect(viewModel.destination == nil)
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

    /// Freezing stops the capture session, which kills the torch with it —
    /// the UI state must follow.
    @Test func freezingTurnsTheTorchOff() async {
        let viewModel = Self.makeScanningViewModel()
        viewModel.toggleTorch()
        #expect(viewModel.isTorchOn == true)

        await viewModel.freezeFrame(capturing: { UIImage() })

        #expect(viewModel.isTorchOn == false)
    }

    /// The live stream clears itself when scanning stops; that must not wipe
    /// the still-image results while a frozen frame is showing.
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

    @Test func stillRecognitionFinishClearsTheInFlightFlag() async {
        let viewModel = Self.makeScanningViewModel()
        await viewModel.freezeFrame(capturing: { UIImage() })

        viewModel.stillRecognitionDidFinish()

        #expect(viewModel.isRecognizingStill == false)
    }

    /// Resuming can interrupt a still pass mid-flight; the flag must not leak.
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

    /// Dismissing the only badge must not flip the capsule to "No prices found" —
    /// the classifier's raw verdict still counts.
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

    /// A nil capture means no scanner is attached (e.g. simulator) — not a failure.
    @Test func freezeFrameWithoutAScannerStaysLiveAndSilent() async {
        let viewModel = Self.makeScanningViewModel()
        AppState.shared.errorHandler.currentError = nil

        await viewModel.freezeFrame(capturing: { nil })

        #expect(viewModel.isScanning == true)
        #expect(viewModel.frozenImage == nil)
        #expect(AppState.shared.errorHandler.currentError == nil)
    }

    @Test func freezeFrameFailureSurfacesCaptureError() async {
        let viewModel = Self.makeScanningViewModel()
        AppState.shared.errorHandler.currentError = nil

        await viewModel.freezeFrame(capturing: { throw StubError() })

        #expect(viewModel.isScanning == true)
        #expect(viewModel.frozenImage == nil)
        #expect(AppState.shared.errorHandler.currentError == .cameraCaptureFailed)
    }

    @Test func freezeFrameCancellationStaysSilent() async {
        let viewModel = Self.makeScanningViewModel()
        AppState.shared.errorHandler.currentError = nil

        await viewModel.freezeFrame(capturing: { throw CancellationError() })

        #expect(AppState.shared.errorHandler.currentError == nil)
    }

    @Test func importPhotoFreezesOnDecodableImageData() async throws {
        let viewModel = Self.makeScanningViewModel()
        let imageData = try #require(
            UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { _ in }.pngData()
        )

        await viewModel.importPhoto(loading: { imageData })

        #expect(viewModel.isScanning == false)
        #expect(viewModel.frozenImage != nil)
    }

    @Test func importPhotoWithNoDataSurfacesImportError() async {
        let viewModel = Self.makeScanningViewModel()
        AppState.shared.errorHandler.currentError = nil

        await viewModel.importPhoto(loading: { nil })

        #expect(viewModel.frozenImage == nil)
        #expect(AppState.shared.errorHandler.currentError == .photoImportFailed)
    }

    @Test func importPhotoWithUndecodableDataSurfacesImportError() async {
        let viewModel = Self.makeScanningViewModel()
        AppState.shared.errorHandler.currentError = nil

        await viewModel.importPhoto(loading: { Data("not an image".utf8) })

        #expect(viewModel.frozenImage == nil)
        #expect(AppState.shared.errorHandler.currentError == .photoImportFailed)
    }

    @Test func importPhotoLoadFailureSurfacesImportError() async {
        let viewModel = Self.makeScanningViewModel()
        AppState.shared.errorHandler.currentError = nil

        await viewModel.importPhoto(loading: { throw StubError() })

        #expect(viewModel.frozenImage == nil)
        #expect(AppState.shared.errorHandler.currentError == .photoImportFailed)
    }
}
