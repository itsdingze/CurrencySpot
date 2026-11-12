import Foundation
import IdentifiedCollections
import Observation
import OSLog
import UIKit

@Observable
final class CameraViewModel {
    nonisolated enum Destination: Identifiable, Hashable {
        case basePicker
        case targetPicker
        case badgeDetail(DetectedItem)

        var id: Self { self }
    }

    nonisolated enum RatesNotice {
        case missingRates
        case missingPairRate
        case sampleRates
    }

    private nonisolated enum Finding: Comparable {
        case nothing
        case numbers
        case prices
    }

    // MARK: - UI State

    private(set) var authorization: CameraAuthorizationStatus = .notDetermined
    private(set) var detectedItems: IdentifiedArrayOf<DetectedItem> = []
    private(set) var frozenImage: UIImage?
    private(set) var isScanning = true
    private(set) var isRecognizingStill = false
    private(set) var isCapturing = false

    var hasPrices: Bool {
        classifierFoundPrices || detectedItems.contains { $0.conversion.isPrice }
    }

    var hasSettledPrices: Bool { settledFinding == .prices }
    var hasSettledNumbers: Bool { settledFinding == .numbers }

    var canConvertPrices: Bool {
        RateTable(ratesStore.rates).canConvert(from: baseCurrency, to: targetCurrency)
    }

    var ratesNotice: RatesNotice? {
        if !canConvertPrices { return ratesStore.rates.isEmpty ? .missingRates : .missingPairRate }
        return isShowingSampleRates ? .sampleRates : nil
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

    @ObservationIgnored private var liveStabilizer = LiveDetectionStabilizer()
    private var liveFinding = Finding.nothing
    @ObservationIgnored private var findingDropTask: Task<Void, Never>?
    private let lingerDuration = Duration.milliseconds(500)
    private let absenceGracePeriod = Duration.milliseconds(1200)

    private var freezeRequestID = 0

    private var stillRecognition = StillRecognitionResult.empty
    @ObservationIgnored private var stillItemIdentities = LiveItemIdentities()
    private var stillViewportSize = CGSize.zero
    @ObservationIgnored private var stillViewports = ViewportStack()

    // MARK: - Dependencies

    private let appState: AppState
    private let ratesStore: ExchangeRatesStore
    private let permissionService: CameraPermissionService
    private let torchService: TorchService
    private let scanConversionUseCase: ScanConversionUseCase
    private let recognizeStillImageTextUseCase: RecognizeStillImageTextUseCase
    private let calculateConversionUseCase: CalculateConversionUseCase
    private let localeCurrencyCode: CurrencyCode?
    private let fallbackBaseCurrency: CurrencyCode
    private let clock: ClockService
    private let logger = Logger(category: .viewModel)

    init(
        ratesStore: ExchangeRatesStore,
        appState: AppState,
        permissionService: CameraPermissionService,
        torchService: TorchService,
        scanConversionUseCase: ScanConversionUseCase,
        recognizeStillImageTextUseCase: RecognizeStillImageTextUseCase,
        calculateConversionUseCase: CalculateConversionUseCase,
        localeCurrencyCode: CurrencyCode?,
        fallbackBaseCurrency: CurrencyCode,
        defaultTargetCurrency: CurrencyCode,
        clock: ClockService
    ) {
        self.ratesStore = ratesStore
        self.appState = appState
        self.permissionService = permissionService
        self.torchService = torchService
        self.scanConversionUseCase = scanConversionUseCase
        self.recognizeStillImageTextUseCase = recognizeStillImageTextUseCase
        self.calculateConversionUseCase = calculateConversionUseCase
        self.localeCurrencyCode = localeCurrencyCode
        self.fallbackBaseCurrency = fallbackBaseCurrency
        self.clock = clock
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
        guard !isCapturing else { return }
        isCapturing = true
        defer { isCapturing = false }
        let request = beginFreezeRequest()
        do {
            guard let image = try await capture() else { return }
            guard request == freezeRequestID else { return }
            freeze(with: image)
        } catch is CancellationError {
        } catch {
            guard request == freezeRequestID else { return }
            logger.error("Frame capture failed: \(error.localizedDescription, privacy: .public)")
            appState.errorHandler.handle(AppError.cameraCaptureFailed)
        }
    }

    func importPhoto(loading load: () async throws -> Data?) async {
        let request = beginFreezeRequest()
        do {
            guard let data = try await load(), let image = await StillImageDecoder().decode(data) else {
                throw AppError.photoImportFailed
            }
            guard request == freezeRequestID else { return }
            freeze(with: image)
        } catch is CancellationError {
        } catch {
            guard request == freezeRequestID else { return }
            logger.error("Photo import failed: \(error.localizedDescription, privacy: .public)")
            appState.errorHandler.handle(AppError.photoImportFailed)
        }
    }

    func resumeLiveScanning() {
        freezeRequestID += 1
        frozenImage = nil
        isScanning = true
        isRecognizingStill = false
        stillRecognition = .empty
        badgeOverrides = BadgePriceOverrides()
        resetLiveSmoothing()
        updateRecognizedItems([])
    }

    // MARK: - Recognition

    func updateLiveRecognizedItems(_ items: [RecognizedTextItem]) {
        guard frozenImage == nil else { return }
        recognizedItems = items
        recordLiveFrame()
    }

    func moveLiveItems(by transform: CGAffineTransform) {
        guard frozenImage == nil else { return }
        recognizedItems = recognizedItems.map { $0.mapped { $0.applying(transform) } }
        liveStabilizer.transform(by: transform)
        publishLiveItems()
    }

    func clearLiveItems() {
        guard frozenImage == nil else { return }
        resetLiveSmoothing()
        updateRecognizedItems([])
    }

    var stillRecognitionLanguages: [Locale.Language] {
        recognizeStillImageTextUseCase.recognitionLanguages(forMenuPricedIn: baseCurrency)
    }

    func recognizeStill(in image: UIImage) async {
        if frozenImage === image { isRecognizingStill = true }
        do {
            let result = try await recognizeStillImageTextUseCase.recognizeText(in: image, menuCurrency: baseCurrency)
            guard !Task.isCancelled, frozenImage === image else { return }
            stillRecognition = StillRecognitionResult(
                items: stillItemIdentities.identify(result.items),
                imagePixelSize: result.imagePixelSize
            )
            pushStillItems()
            isRecognizingStill = false
        } catch is CancellationError {
        } catch {
            guard !Task.isCancelled, frozenImage === image else { return }
            logger.error("Still-image text recognition failed: \(error.localizedDescription, privacy: .public)")
            appState.errorHandler.handle(AppError.textRecognitionFailed)
            isRecognizingStill = false
        }
    }

    func stillViewportEvent(_ event: ViewportEvent, from viewport: UUID) {
        stillViewports.record(event, from: viewport)
        guard let size = stillViewports.frontSize, size != stillViewportSize else { return }
        stillViewportSize = size
        pushStillItems()
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
        republish()
    }

    func hideConversion(for id: UUID) {
        badgeOverrides.hide(id: id)
        destination = nil
        republish()
    }

    func showBadgeDetail(for id: UUID) {
        guard let item = detectedItems[id: id], item.conversion.isPrice else { return }
        destination = .badgeDetail(item)
    }

    // MARK: - Shared Rates for the Overlay UI

    var availableRates: [ExchangeRate] { ratesStore.rates }
    var isShowingSampleRates: Bool { ratesStore.isShowingSampleRates }

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
        stillItemIdentities = LiveItemIdentities()
        resetLiveSmoothing()
        updateRecognizedItems([])
    }

    private func pushStillItems() {
        guard frozenImage != nil else { return }
        updateRecognizedItems(
            recognizeStillImageTextUseCase.textItems(in: stillRecognition, fittedTo: stillViewportSize)
        )
    }

    private func updateRecognizedItems(_ items: [RecognizedTextItem]) {
        recognizedItems = items
        let result = detect(in: items)
        publish(result.items, foundPrices: result.foundPrices)
    }

    private func recordLiveFrame() {
        let result = detect(in: recognizedItems)
        if let emission = liveStabilizer.record(result.items) {
            expireLingeringItems(through: emission)
        }
        publishLiveItems()
    }

    private func publishLiveItems() {
        let items = liveStabilizer.items
        publish(items, foundPrices: items.contains { $0.conversion.isPrice })
        settleLiveFinding()
    }

    private func expireLingeringItems(through emission: Int) {
        Task { [weak self, clock, lingerDuration] in
            try? await clock.sleep(for: lingerDuration)
            guard let self, !Task.isCancelled, frozenImage == nil else { return }
            liveStabilizer.expireLingering(through: emission)
            publishLiveItems()
        }
    }

    private func detect(in items: [RecognizedTextItem]) -> ScanConversionUseCase.DetectionResult {
        scanConversionUseCase.detect(
            in: items,
            baseCurrency: baseCurrency,
            targetCurrency: targetCurrency,
            exchangeRates: ratesStore.rates
        )
    }

    private func publish(_ items: [DetectedItem], foundPrices: Bool) {
        guard canConvertPrices else {
            detectedItems = []
            classifierFoundPrices = false
            return
        }
        detectedItems = IdentifiedArray(uniqueElements: items.map(applyingOverride))
        classifierFoundPrices = foundPrices
    }

    private func applyingOverride(_ item: DetectedItem) -> DetectedItem {
        item.replacing(conversion: badgeOverrides.effective(item.conversion, for: item.id))
    }

    private func reconvert() {
        if frozenImage == nil {
            liveStabilizer.reset()
            recordLiveFrame()
        } else {
            updateRecognizedItems(recognizedItems)
        }
    }

    private func republish() {
        if frozenImage == nil {
            publishLiveItems()
        } else {
            updateRecognizedItems(recognizedItems)
        }
    }

    // MARK: - Settled Found State

    private var currentFinding: Finding {
        if hasPrices { return .prices }
        return detectedItems.isEmpty ? .nothing : .numbers
    }

    private var settledFinding: Finding {
        frozenImage == nil ? liveFinding : currentFinding
    }

    private func settleLiveFinding() {
        let finding = currentFinding
        if finding >= liveFinding {
            findingDropTask?.cancel()
            findingDropTask = nil
            if finding != liveFinding { liveFinding = finding }
        } else if findingDropTask == nil {
            findingDropTask = Task { [weak self, clock, absenceGracePeriod] in
                try? await clock.sleep(for: absenceGracePeriod)
                guard let self, !Task.isCancelled else { return }
                findingDropTask = nil
                liveFinding = currentFinding
            }
        }
    }

    private func resetLiveSmoothing() {
        liveStabilizer.reset()
        findingDropTask?.cancel()
        findingDropTask = nil
        liveFinding = .nothing
    }

    private var autodetectedBaseCurrency: CurrencyCode {
        guard let localeCurrencyCode,
              ratesStore.rates.contains(where: { $0.currencyCode == localeCurrencyCode })
        else { return fallbackBaseCurrency }
        return localeCurrencyCode
    }
}
