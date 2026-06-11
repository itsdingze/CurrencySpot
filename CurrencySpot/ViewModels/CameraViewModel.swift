//
//  CameraViewModel.swift
//  CurrencySpot
//

import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class CameraViewModel {
    /// Mutually exclusive presentations over the camera feed.
    enum Destination: Identifiable, Hashable {
        case basePicker
        case targetPicker
        case badgeDetail(DetectedItem)

        var id: Self { self }
    }

    // MARK: - UI State

    private(set) var authorization: CameraAuthorizationStatus = .notDetermined
    private(set) var detectedItems: [DetectedItem] = []
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

    /// The user's tap-to-convert overrides for numbers the classifier judged non-prices.
    private var manualPriceOverrides: Set<UUID> = []

    /// Auto-detected prices whose badge the user dismissed by tapping the outline.
    private var suppressedPrices: Set<UUID> = []

    // MARK: - Dependencies

    private let appState = AppState.shared
    private let calculatorViewModel: CalculatorViewModel
    private let permissionService: CameraPermissionService
    private let scanConversionUseCase: ScanConversionUseCase
    private let torchService: TorchService
    private let localeCurrencyCode: String?
    private let fallbackBaseCurrency: String

    init(
        calculatorViewModel: CalculatorViewModel,
        permissionService: CameraPermissionService = AVCameraPermissionService(),
        scanConversionUseCase: ScanConversionUseCase = ScanConversionUseCase(),
        torchService: TorchService = AVTorchService(),
        localeCurrencyCode: String? = Locale.current.currency?.identifier,
        fallbackBaseCurrency: String = UserDefaults.standard.string(forKey: UserDefaultsKeys.defaultBaseCurrency) ?? "USD",
        defaultTargetCurrency: String = UserDefaults.standard.string(forKey: UserDefaultsKeys.defaultTargetCurrency) ?? "EUR"
    ) {
        self.calculatorViewModel = calculatorViewModel
        self.permissionService = permissionService
        self.scanConversionUseCase = scanConversionUseCase
        self.torchService = torchService
        self.localeCurrencyCode = localeCurrencyCode
        self.fallbackBaseCurrency = fallbackBaseCurrency
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
        do {
            guard let image = try await capture() else { return }
            freeze(with: image)
        } catch is CancellationError {
            // Normal lifecycle (tab switch, backgrounding) — nothing to report.
        } catch {
            AppLogger.error("Frame capture failed: \(error)", category: .viewModel)
            appState.errorHandler.handle(AppError.cameraCaptureFailed)
        }
    }

    /// Photo import: loads the picked photo's data and freezes on it.
    func importPhoto(loading load: () async throws -> Data?) async {
        do {
            guard let data = try await load(), let image = UIImage(data: data) else {
                throw AppError.photoImportFailed
            }
            freeze(with: image)
        } catch is CancellationError {
            // Normal lifecycle — nothing to report.
        } catch {
            AppLogger.error("Photo import failed: \(error)", category: .viewModel)
            appState.errorHandler.handle(AppError.photoImportFailed)
        }
    }

    /// Called by the still-frame view once its recognition pass has pushed
    /// results, whatever they were — gates the "No prices found" message.
    func stillRecognitionDidFinish() {
        isRecognizingStill = false
    }

    func resumeLiveScanning() {
        frozenImage = nil
        isScanning = true
        isRecognizingStill = false
        updateRecognizedItems([])
    }

    // MARK: - Recognition

    /// Entry point for the live scanner's stream. Ignored while a frozen frame
    /// is showing so end-of-session clears can't wipe still-image results.
    func updateLiveRecognizedItems(_ items: [RecognizedTextItem]) {
        guard frozenImage == nil else { return }
        updateRecognizedItems(items)
    }

    func updateRecognizedItems(_ items: [RecognizedTextItem]) {
        recognizedItems = items
        var foundRawPrice = false
        detectedItems = items.compactMap { item in
            scanConversionUseCase.evaluate(
                transcript: item.transcript,
                baseCurrency: baseCurrency,
                targetCurrency: targetCurrency,
                exchangeRates: calculatorViewModel.availableRates
            ).map { conversion in
                foundRawPrice = foundRawPrice || conversion.isPrice
                return DetectedItem(
                    id: item.id,
                    transcript: item.transcript,
                    bounds: item.bounds,
                    conversion: effectiveConversion(conversion, for: item.id)
                )
            }
        }
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
        guard let item = detectedItems.first(where: { $0.id == id }) else { return }
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
        guard let item = detectedItems.first(where: { $0.id == id }), item.conversion.isPrice else { return }
        if manualPriceOverrides.contains(id) {
            manualPriceOverrides.remove(id)
        } else {
            suppressedPrices.insert(id)
        }
        destination = nil
        reconvert()
    }

    func showBadgeDetail(for id: UUID) {
        guard let item = detectedItems.first(where: { $0.id == id }), item.conversion.isPrice else { return }
        destination = .badgeDetail(item)
    }

    // MARK: - Calculator Passthroughs for the Overlay UI

    var availableRates: [ExchangeRateDataValue] { calculatorViewModel.availableRates }

    var rateFreshness: String { calculatorViewModel.formattedLastUpdated }

    var rateUsed: Decimal {
        scanConversionUseCase.rate(from: baseCurrency, to: targetCurrency, in: calculatorViewModel.availableRates)
    }

    /// The badge-detail shortcut: prefill the calculator with this conversion
    /// and jump to the Convert tab.
    func openInConverter(_ item: DetectedItem) {
        calculatorViewModel.baseCurrency = baseCurrency
        calculatorViewModel.targetCurrency = targetCurrency
        calculatorViewModel.inputAmountString = Self.calculatorInput(for: item.conversion.amount)
        destination = nil
        appState.selectedTab = 0
    }

    // MARK: - Private Helpers

    /// Holds a still frame (shutter or photo import). Items are cleared until
    /// the still-image recognition pass repopulates them.
    private func freeze(with image: UIImage) {
        turnTorchOff()
        frozenImage = image
        isScanning = false
        isRecognizingStill = true
        updateRecognizedItems([])
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
              calculatorViewModel.availableRates.contains(where: { $0.currencyCode == localeCurrencyCode })
        else { return fallbackBaseCurrency }
        return localeCurrencyCode
    }

    /// The calculator keeps its input as an implied-cents digit string ("120000" → 1200.00).
    private static func calculatorInput(for amount: Decimal) -> String {
        let cents = NSDecimalNumber(decimal: amount * 100).intValue
        return String(cents)
    }
}
