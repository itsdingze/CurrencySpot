//
//  CameraViewModel.swift
//  CurrencySpot
//

import Foundation
import IdentifiedCollections
import Observation
import UIKit

@Observable
final class CameraViewModel {
    /// Mutually exclusive presentations over the camera feed.
    nonisolated enum Destination: Identifiable, Hashable {
        case basePicker
        case targetPicker
        /// The item at presentation time. The sheet re-resolves the live item
        /// by ID so fresh rates update an open detail; this snapshot is the
        /// sheet's identity and the fallback if the item leaves the frame.
        case badgeDetail(DetectedItem)

        var id: Self { self }
    }

    // MARK: - UI State

    private(set) var authorization: CameraAuthorizationStatus = .notDetermined
    private(set) var detectedItems: IdentifiedArrayOf<DetectedItem> = []
    private(set) var frozenImage: UIImage?
    private(set) var isScanning = true
    private(set) var isRecognizingStill = false

    /// Whether the current frame yielded any price — drives the status capsule.
    /// Counts the classifier's raw verdict as well as visible badges, so user
    /// overrides in either direction never flip the capsule to "not found".
    var hasPrices: Bool {
        classifierFoundPrices || detectedItems.contains { $0.conversion.isPrice }
    }
    private(set) var isTorchOn = false
    var destination: Destination?

    var baseCurrency: String {
        get { manualBaseCurrency ?? autodetectedBaseCurrency }
        set {
            manualBaseCurrency = newValue
            reconvert()
        }
    }

    var targetCurrency: String {
        didSet { reconvert() }
    }

    // MARK: - Private State

    private var recognizedItems: [RecognizedTextItem] = []
    private var classifierFoundPrices = false
    private var manualBaseCurrency: String?

    /// Identifies the latest freeze request (shutter or import), so a slow
    /// capture that finishes after a newer freeze or a resume can't clobber it.
    private var freezeRequestID = 0

    /// The frozen frame's recognition results in image-pixel coordinates,
    /// kept so viewport size changes can re-map them into view space.
    private var stillRecognition = StillRecognitionResult.empty
    private var stillViewportSize = CGSize.zero

    /// The user's tap-to-convert overrides for numbers the classifier judged non-prices.
    private var manualPriceOverrides: Set<UUID> = []

    /// Auto-detected prices whose badge the user dismissed by tapping the outline.
    private var suppressedPrices: Set<UUID> = []

    // MARK: - Dependencies

    private let appState: AppState
    private let ratesStore: ExchangeRatesStore
    private let permissionService: CameraPermissionService
    private let scanConversionUseCase: ScanConversionUseCase
    private let stillTextRecognizer: StillTextRecognitionService
    private let torchService: TorchService
    private let localeCurrencyCode: String?
    private let fallbackBaseCurrency: String
    private let logger: LoggerService

    init(
        ratesStore: ExchangeRatesStore,
        appState: AppState = .shared,
        permissionService: CameraPermissionService = AVCameraPermissionService(),
        scanConversionUseCase: ScanConversionUseCase = ScanConversionUseCase(),
        stillTextRecognizer: StillTextRecognitionService = StillImageTextRecognizer(),
        torchService: TorchService = AVTorchService(),
        localeCurrencyCode: String? = Locale.current.currency?.identifier,
        fallbackBaseCurrency: String = UserDefaults.standard.string(forKey: UserDefaultsKeys.defaultBaseCurrency) ?? "USD",
        defaultTargetCurrency: String = UserDefaults.standard.string(forKey: UserDefaultsKeys.defaultTargetCurrency) ?? "EUR",
        logger: LoggerService = OSLogLoggerService()
    ) {
        self.ratesStore = ratesStore
        self.appState = appState
        self.permissionService = permissionService
        self.scanConversionUseCase = scanConversionUseCase
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

    /// Stopping the capture session kills the torch; keep UI state in sync.
    func turnTorchOff() {
        guard isTorchOn else { return }
        _ = torchService.setTorch(enabled: false)
        isTorchOn = false
    }

    // MARK: - Freeze and Resume

    /// Shutter tap: captures a still from the live feed and freezes on it.
    /// A nil capture means no scanner is attached (e.g. simulator) — not a failure.
    func freezeFrame(capturing capture: () async throws -> UIImage?) async {
        let request = beginFreezeRequest()
        do {
            guard let image = try await capture() else { return }
            guard request == freezeRequestID else { return }
            freeze(with: image)
        } catch is CancellationError {
            // Normal lifecycle (tab switch, backgrounding) — nothing to report.
        } catch {
            guard request == freezeRequestID else { return }
            logger.error("Frame capture failed: \(error)", category: .viewModel)
            appState.errorHandler.handle(AppError.cameraCaptureFailed)
        }
    }

    /// Photo import: loads the picked photo's data and freezes on it.
    func importPhoto(loading load: () async throws -> Data?) async {
        let request = beginFreezeRequest()
        do {
            guard let data = try await load(), let image = UIImage(data: data) else {
                throw AppError.photoImportFailed
            }
            guard request == freezeRequestID else { return }
            freeze(with: image)
        } catch is CancellationError {
            // Normal lifecycle — nothing to report.
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

    /// Entry point for the live scanner's stream. Ignored while a frozen frame
    /// is showing so end-of-session clears can't wipe still-image results.
    func updateLiveRecognizedItems(_ items: [RecognizedTextItem]) {
        guard frozenImage == nil else { return }
        updateRecognizedItems(items)
    }

    /// Runs text recognition on the frozen frame and maps the results into
    /// the still view's coordinate space.
    func recognizeStill(in image: UIImage) async {
        do {
            let result = try await stillTextRecognizer.recognize(image)
            // A cancelled or superseded pass (user resumed live scanning or
            // froze a newer image) must not push stale results.
            guard !Task.isCancelled, frozenImage === image else { return }
            stillRecognition = result
            pushStillItems()
            isRecognizingStill = false
        } catch is CancellationError {
            // Normal lifecycle — nothing to report.
        } catch {
            guard frozenImage === image else { return }
            logger.error("Still-image text recognition failed: \(error)", category: .viewModel)
            appState.errorHandler.handle(AppError.textRecognitionFailed)
            isRecognizingStill = false
        }
    }

    /// The still view reports its size here so recognized bounds can be
    /// re-mapped whenever layout changes.
    func stillViewportChanged(_ size: CGSize) {
        stillViewportSize = size
        pushStillItems()
    }

    func updateRecognizedItems(_ items: [RecognizedTextItem]) {
        recognizedItems = items
        var foundRawPrice = false
        detectedItems = IdentifiedArray(uniqueElements: items.compactMap { item in
            scanConversionUseCase.evaluate(
                transcript: item.transcript,
                baseCurrency: baseCurrency,
                targetCurrency: targetCurrency,
                exchangeRates: ratesStore.rates
            ).map { conversion in
                foundRawPrice = foundRawPrice || conversion.isPrice
                return DetectedItem(
                    id: item.id,
                    transcript: item.transcript,
                    bounds: item.bounds,
                    conversion: effectiveConversion(conversion, for: item.id)
                )
            }
        })
        classifierFoundPrices = foundRawPrice
    }

    /// Re-runs conversion for visible items, for when fresh rates arrive
    /// while a frozen frame or sparse live feed is showing.
    func refreshConversions() {
        reconvert()
    }

    // MARK: - Currency Pair

    func swapCurrencies() {
        (baseCurrency, targetCurrency) = (targetCurrency, baseCurrency)
    }

    // MARK: - Badges

    /// Tapping an outline toggles its converted badge: pin it for numbers the
    /// classifier skipped, or dismiss it for ones it (or the user) pinned.
    func toggleConversion(for id: UUID) {
        guard let item = detectedItems[id: id] else { return }
        if item.conversion.isPrice {
            if manualPriceOverrides.contains(id) {
                manualPriceOverrides.remove(id)
            } else {
                suppressedPrices.insert(id)
            }
        } else {
            if suppressedPrices.contains(id) {
                suppressedPrices.remove(id)
            } else {
                manualPriceOverrides.insert(id)
            }
        }
        reconvert()
    }

    /// The detail sheet's escape hatch for misread or misclassified plates:
    /// uncovers the original text and dismisses the sheet.
    func hideConversion(for id: UUID) {
        guard let item = detectedItems[id: id], item.conversion.isPrice else { return }
        if manualPriceOverrides.contains(id) {
            manualPriceOverrides.remove(id)
        } else {
            suppressedPrices.insert(id)
        }
        destination = nil
        reconvert()
    }

    func showBadgeDetail(for id: UUID) {
        guard let item = detectedItems[id: id], item.conversion.isPrice else { return }
        destination = .badgeDetail(item)
    }

    /// Resolves the live item for an open badge-detail sheet.
    func detectedItem(for id: UUID) -> DetectedItem? {
        detectedItems[id: id]
    }

    // MARK: - Shared Rates for the Overlay UI

    var availableRates: [ExchangeRate] { ratesStore.rates }

    var rateFreshness: String { ratesStore.formattedLastUpdated }

    var rateUsed: Decimal {
        scanConversionUseCase.rate(from: baseCurrency, to: targetCurrency, in: ratesStore.rates)
    }

    /// The badge-detail shortcut: posts a typed pending-conversion request on
    /// AppState and jumps to the Convert tab; the calculator consumes it on appear.
    func openInConverter(_ item: DetectedItem) {
        appState.pendingConversion = PendingConversion(
            baseCurrency: baseCurrency,
            targetCurrency: targetCurrency,
            amountInput: Self.calculatorInput(for: item.conversion.amount)
        )
        destination = nil
        appState.selectedTab = .convert
    }

    // MARK: - Private Helpers

    /// Marks the start of a freeze request and returns its identity, so the
    /// completion can detect being superseded by a newer request or a resume.
    private func beginFreezeRequest() -> Int {
        freezeRequestID += 1
        return freezeRequestID
    }

    /// Holds a still frame (shutter or photo import). Items are cleared until
    /// the still-image recognition pass repopulates them.
    private func freeze(with image: UIImage) {
        turnTorchOff()
        frozenImage = image
        isScanning = false
        isRecognizingStill = true
        stillRecognition = .empty
        updateRecognizedItems([])
    }

    /// Maps the frozen frame's recognition results into the current viewport.
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

    private func effectiveConversion(
        _ conversion: ScanConversionUseCase.ScannedConversion,
        for id: UUID
    ) -> ScanConversionUseCase.ScannedConversion {
        if manualPriceOverrides.contains(id) { return conversion.asPrice }
        if suppressedPrices.contains(id) { return conversion.asNonPrice }
        return conversion
    }

    /// The plan: locale autodetection, unless the user picked manually or
    /// the locale's currency has no rate data.
    private var autodetectedBaseCurrency: String {
        guard let localeCurrencyCode,
              ratesStore.rates.contains(where: { $0.currencyCode.rawValue == localeCurrencyCode })
        else { return fallbackBaseCurrency }
        return localeCurrencyCode
    }

    /// The calculator keeps its input as an implied-cents digit string ("120000" → 1200.00).
    private static func calculatorInput(for amount: Decimal) -> String {
        let cents = NSDecimalNumber(decimal: amount * 100).intValue
        return String(cents)
    }
}
