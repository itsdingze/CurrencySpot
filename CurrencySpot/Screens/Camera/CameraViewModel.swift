import Foundation
import IdentifiedCollections
import Observation
import UIKit

@Observable
final class CameraViewModel {
    nonisolated enum Destination: Identifiable, Hashable {
        case basePicker
        case targetPicker
        case badgeDetail(DetectedItem)

        var id: Self { self }
    }

    // MARK: - UI State

    private(set) var authorization: CameraAuthorizationStatus = .notDetermined
    private(set) var detectedItems: IdentifiedArrayOf<DetectedItem> = []
    private(set) var frozenImage: UIImage?
    private(set) var isScanning = true
    private(set) var isRecognizingStill = false

    var hasPrices: Bool {
        classifierFoundPrices || detectedItems.contains { $0.conversion.isPrice }
    }
    private(set) var isTorchOn = false
    var destination: Destination?

    var baseCurrency: CurrencyCode {
        get { manualBaseCurrency ?? autodetectedBaseCurrency }
        set {
            manualBaseCurrency = newValue
            reconvert()
        }
    }

    var targetCurrency: CurrencyCode {
        didSet { reconvert() }
    }

    // MARK: - Private State

    private var recognizedItems: [RecognizedTextItem] = []
    private var classifierFoundPrices = false
    private var manualBaseCurrency: CurrencyCode?
    private var badgeOverrides = BadgePriceOverrides()

    private var freezeRequestID = 0

    private var stillRecognition = StillRecognitionResult.empty
    private var stillViewportSize = CGSize.zero

    // MARK: - Dependencies

    private let appState: AppState
    private let ratesStore: ExchangeRatesStore
    private let permissionService: CameraPermissionService
    private let scanConversionUseCase: ScanConversionUseCase
    private let calculateConversionUseCase: CalculateConversionUseCase
    private let stillTextRecognizer: StillTextRecognitionService
    private let torchService: TorchService
    private let localeCurrencyCode: CurrencyCode?
    private let fallbackBaseCurrency: CurrencyCode
    private let logger: LoggerService

    init(
        ratesStore: ExchangeRatesStore,
        appState: AppState = .shared,
        permissionService: CameraPermissionService,
        scanConversionUseCase: ScanConversionUseCase = ScanConversionUseCase(),
        calculateConversionUseCase: CalculateConversionUseCase = CalculateConversionUseCase(),
        stillTextRecognizer: StillTextRecognitionService = StillImageTextRecognizer(),
        torchService: TorchService = AVTorchService(),
        localeCurrencyCode: CurrencyCode? = Locale.current.currency.flatMap { CurrencyCode($0.identifier) },
        fallbackBaseCurrency: CurrencyCode,
        defaultTargetCurrency: CurrencyCode,
        logger: LoggerService = OSLogLoggerService()
    ) {
        self.ratesStore = ratesStore
        self.appState = appState
        self.permissionService = permissionService
        self.scanConversionUseCase = scanConversionUseCase
        self.calculateConversionUseCase = calculateConversionUseCase
        self.stillTextRecognizer = stillTextRecognizer
        self.torchService = torchService
        self.localeCurrencyCode = localeCurrencyCode
        self.fallbackBaseCurrency = fallbackBaseCurrency
        self.logger = logger
        targetCurrency = defaultTargetCurrency
        authorization = permissionService.currentStatus()
    }

    // MARK: - Permission

    func requestCameraAccess() async {
        authorization = await permissionService.requestAccess() ? .authorized : .denied
    }

    // MARK: - Torch

    func toggleTorch() {
        isTorchOn = torchService.setTorch(enabled: !isTorchOn)
    }

    func turnTorchOff() {
        guard isTorchOn else { return }
        _ = torchService.setTorch(enabled: false)
        isTorchOn = false
    }

    // MARK: - Freeze and Resume

    func freezeFrame(capturing capture: () async throws -> UIImage?) async {
        let request = beginFreezeRequest()
        do {
            guard let image = try await capture() else { return }
            guard request == freezeRequestID else { return }
            freeze(with: image)
        } catch is CancellationError {
        } catch {
            guard request == freezeRequestID else { return }
            logger.error("Frame capture failed: \(error)", category: .viewModel)
            appState.errorHandler.handle(AppError.cameraCaptureFailed)
        }
    }

    func importPhoto(loading load: () async throws -> Data?) async {
        let request = beginFreezeRequest()
        do {
            guard let data = try await load(), let image = UIImage(data: data) else {
                throw AppError.photoImportFailed
            }
            guard request == freezeRequestID else { return }
            freeze(with: image)
        } catch is CancellationError {
        } catch {
            guard request == freezeRequestID else { return }
            logger.error("Photo import failed: \(error)", category: .viewModel)
            appState.errorHandler.handle(AppError.photoImportFailed)
        }
    }

    func resumeLiveScanning() {
        freezeRequestID += 1
        frozenImage = nil
        isScanning = true
        isRecognizingStill = false
        stillRecognition = .empty
        updateRecognizedItems([])
    }

    // MARK: - Recognition

    func updateLiveRecognizedItems(_ items: [RecognizedTextItem]) {
        guard frozenImage == nil else { return }
        updateRecognizedItems(items)
    }

    func recognizeStill(in image: UIImage) async {
        do {
            let result = try await stillTextRecognizer.recognize(image)
            guard !Task.isCancelled, frozenImage === image else { return }
            stillRecognition = result
            pushStillItems()
            isRecognizingStill = false
        } catch is CancellationError {
        } catch {
            guard frozenImage === image else { return }
            logger.error("Still-image text recognition failed: \(error)", category: .viewModel)
            appState.errorHandler.handle(AppError.textRecognitionFailed)
            isRecognizingStill = false
        }
    }

    func stillViewportChanged(_ size: CGSize) {
        stillViewportSize = size
        pushStillItems()
    }

    func updateRecognizedItems(_ items: [RecognizedTextItem]) {
        recognizedItems = items
        let result = scanConversionUseCase.detect(
            in: items,
            baseCurrency: baseCurrency,
            targetCurrency: targetCurrency,
            exchangeRates: ratesStore.rates
        )
        detectedItems = IdentifiedArray(uniqueElements: result.items.map(applyingOverride))
        classifierFoundPrices = result.foundPrices
    }

    private func applyingOverride(_ item: DetectedItem) -> DetectedItem {
        DetectedItem(
            id: item.id,
            transcript: item.transcript,
            bounds: item.bounds,
            conversion: badgeOverrides.effective(item.conversion, for: item.id)
        )
    }

    func refreshConversions() {
        reconvert()
    }

    // MARK: - Currency Pair

    func swapCurrencies() {
        (baseCurrency, targetCurrency) = (targetCurrency, baseCurrency)
    }

    // MARK: - Badges

    func toggleConversion(for id: UUID) {
        guard let item = detectedItems[id: id] else { return }
        badgeOverrides.toggle(id: id, isPrice: item.conversion.isPrice)
        reconvert()
    }

    func hideConversion(for id: UUID) {
        guard let item = detectedItems[id: id], item.conversion.isPrice else { return }
        badgeOverrides.hide(id: id)
        destination = nil
        reconvert()
    }

    func showBadgeDetail(for id: UUID) {
        guard let item = detectedItems[id: id], item.conversion.isPrice else { return }
        destination = .badgeDetail(item)
    }

    func detectedItem(for id: UUID) -> DetectedItem? {
        detectedItems[id: id]
    }

    // MARK: - Shared Rates for the Overlay UI

    var availableRates: [ExchangeRate] { ratesStore.rates }

    func openInConverter(_ item: DetectedItem) {
        appState.pendingConversion = PendingConversion(
            baseCurrency: baseCurrency,
            targetCurrency: targetCurrency,
            amountInput: calculateConversionUseCase.impliedCentsDigits(for: item.conversion.amount)
        )
        destination = nil
        appState.selectedTab = .convert
    }

    // MARK: - Private Helpers

    private func beginFreezeRequest() -> Int {
        freezeRequestID += 1
        return freezeRequestID
    }

    private func freeze(with image: UIImage) {
        turnTorchOff()
        frozenImage = image
        isScanning = false
        isRecognizingStill = true
        stillRecognition = .empty
        updateRecognizedItems([])
    }

    private func pushStillItems() {
        guard frozenImage != nil else { return }
        let mapping = AspectFitMapping(imageSize: stillRecognition.imagePixelSize, viewSize: stillViewportSize)
        updateRecognizedItems(stillRecognition.items.map { item in
            RecognizedTextItem(id: item.id, transcript: item.transcript, bounds: mapping.viewRect(for: item.bounds))
        })
    }

    private func reconvert() {
        updateRecognizedItems(recognizedItems)
    }

    private var autodetectedBaseCurrency: CurrencyCode {
        guard let localeCurrencyCode,
              ratesStore.rates.contains(where: { $0.currencyCode == localeCurrencyCode })
        else { return fallbackBaseCurrency }
        return localeCurrencyCode
    }
}
