@testable import CurrencySpot
import CoreGraphics
import Foundation
import Testing
import UIKit

@Suite("Live Camera Controller Tests")
struct LiveCameraControllerTests {
    private static let frameSize = CGSize(width: 1000, height: 2000)
    private static let previewSize = CGSize(width: 400, height: 1000)

    private let clock = ManualClock()
    private let camera = InMemoryLiveCamera(maximumZoomRatio: 10, photo: UIImage())
    private let appState = AppState(networkMonitor: NetworkMonitor(isConnected: true))
    private let viewModel: CameraViewModel
    private let controller: LiveCameraController

    init() {
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
        viewModel = CameraViewModel(
            ratesStore: ratesStore,
            appState: appState,
            permissionService: StubCameraPermissionService(status: .authorized),
            torchService: InMemoryTorchService(),
            scanConversionUseCase: ScanConversionUseCase(),
            recognizeStillImageTextUseCase: RecognizeStillImageTextUseCase(recognizer: StubStillTextRecognizer()),
            calculateConversionUseCase: CalculateConversionUseCase(),
            localeCurrencyCode: "JPY",
            fallbackBaseCurrency: "USD",
            defaultTargetCurrency: "USD",
            clock: clock
        )
        controller = LiveCameraController(camera: camera, viewModel: viewModel)
        controller.previewSizeChanged(Self.previewSize)
    }

    private func startCamera() async {
        controller.start()
        await waitUntil { camera.isRunning }
    }

    private func price(framed frameRect: CGRect, _ transcript: String = "¥1,200") -> RecognizedTextItem {
        RecognizedTextItem(id: UUID(), transcript: transcript, bounds: frameRect)
    }

    @Test("a read's labels land where its text shows in the preview")
    func readLandsInPreviewPoints() async {
        await startCamera()

        camera.emitRead(
            [
                price(framed: CGRect(x: 500, y: 1000, width: 200, height: 40)),
                price(framed: CGRect(x: 0, y: 1000, width: 60, height: 40), "¥980"),
            ],
            frameSize: Self.frameSize
        )

        await waitUntil { !viewModel.detectedItems.isEmpty }
        #expect(viewModel.detectedItems.map(\.bounds) == [CGRect(x: 200, y: 500, width: 100, height: 20)])
    }

    @Test("labels follow the camera between reads, then stay half a second after a missed read", .timeLimit(.minutes(1)))
    func labelsFollowMotionThenLinger() async {
        await startCamera()
        camera.emitRead([price(framed: CGRect(x: 500, y: 1000, width: 200, height: 40))], frameSize: Self.frameSize)
        await waitUntil { !viewModel.detectedItems.isEmpty }

        camera.emitMotion(CGPoint(x: 40, y: -20))
        await waitUntil { controller.motionOffset == CGSize(width: 20, height: -10) }

        camera.emitRead([], frameSize: Self.frameSize, motionAtFrame: CGPoint(x: 40, y: -20))
        await waitUntil { controller.motionOffset == .zero }
        #expect(viewModel.detectedItems.map(\.bounds) == [CGRect(x: 220, y: 490, width: 100, height: 20)])

        await waitUntil { clock.pendingSleepCount == 1 }
        clock.advance(by: .milliseconds(500))
        await waitUntil { viewModel.detectedItems.isEmpty }
    }

    @Test("pinching scales the labels about the preview center until a read after the zoom replaces them", .timeLimit(.minutes(1)))
    func pinchScalesLabelsUntilTheNextRead() async {
        await startCamera()
        await waitUntil { controller.zoom.maximumRatio == 10 }
        camera.emitRead([price(framed: CGRect(x: 300, y: 600, width: 200, height: 40))], frameSize: Self.frameSize)
        await waitUntil { viewModel.detectedItems.map(\.bounds) == [CGRect(x: 100, y: 300, width: 100, height: 20)] }
        let epochBeforeZoom = camera.epoch

        controller.pinch(by: 2)

        #expect(viewModel.detectedItems.map(\.bounds) == [CGRect(x: 0, y: 100, width: 200, height: 40)])
        await waitUntil { camera.zoomRatios == [2] }
        camera.emitRead(
            [price(framed: CGRect(x: 700, y: 1600, width: 100, height: 40), "¥980")],
            frameSize: Self.frameSize,
            epoch: epochBeforeZoom
        )
        camera.emitRead([price(framed: CGRect(x: 108, y: 204, width: 400, height: 80))], frameSize: Self.frameSize)
        await waitUntil { viewModel.detectedItems.map(\.bounds) == [CGRect(x: 4, y: 102, width: 200, height: 40)] }
    }

    @Test("a currency change after a pinch keeps the labels where the zoom put them")
    func currencyChangeAfterPinchKeepsZoomedLabels() async {
        await startCamera()
        await waitUntil { controller.zoom.maximumRatio == 10 }
        camera.emitRead([price(framed: CGRect(x: 300, y: 600, width: 200, height: 40))], frameSize: Self.frameSize)
        await waitUntil { !viewModel.detectedItems.isEmpty }
        controller.pinch(by: 2)

        viewModel.targetCurrency = "EUR"

        #expect(viewModel.detectedItems.map(\.bounds) == [CGRect(x: 0, y: 100, width: 200, height: 40)])
    }

    @Test("coming back to the camera within half a second shows each label once")
    func quickReturnShowsEachLabelOnce() async throws {
        await startCamera()
        let shelf = CGRect(x: 500, y: 1000, width: 200, height: 40)
        camera.emitRead([price(framed: shelf)], frameSize: Self.frameSize)
        await waitUntil { viewModel.detectedItems.count == 1 }
        let firstID = try #require(viewModel.detectedItems.first?.id)
        controller.stop()
        await waitUntil { !camera.isRunning }

        await startCamera()
        camera.emitRead([price(framed: shelf)], frameSize: Self.frameSize)

        await waitUntil { viewModel.detectedItems.contains { $0.id != firstID } }
        #expect(viewModel.detectedItems.count == 1)
    }

    @Test("a shutter tap right after the camera starts still freezes the frame")
    func earlyShutterTapFreezes() async {
        controller.start()

        await viewModel.freezeFrame(capturing: controller.capturePhoto)

        #expect(viewModel.frozenImage != nil)
    }

    @Test("a capture that fails after leaving the camera shows no error")
    func captureFailingAfterStopIsQuiet() async {
        await startCamera()
        camera.holdCaptures()
        let freeze = Task { await viewModel.freezeFrame(capturing: controller.capturePhoto) }
        await waitUntil { camera.hasPendingCapture }

        controller.stop()
        camera.finishPendingCapture(with: .failure(AppError.cameraCaptureFailed))
        await freeze.value

        #expect(appState.errorHandler.currentError == nil)
    }

    @Test("a capture that fails while the camera runs reports the failure")
    func captureFailingWhileRunningIsReported() async {
        await startCamera()
        camera.holdCaptures()
        let freeze = Task { await viewModel.freezeFrame(capturing: controller.capturePhoto) }
        await waitUntil { camera.hasPendingCapture }

        camera.finishPendingCapture(with: .failure(AppError.cameraCaptureFailed))
        await freeze.value

        #expect(appState.errorHandler.currentError != nil)
    }

    @Test("a pinch after the camera moved scales the labels from where they show")
    func pinchAfterMotionScalesFromTheShownPlace() async {
        await startCamera()
        await waitUntil { controller.zoom.maximumRatio == 10 }
        camera.emitRead([price(framed: CGRect(x: 300, y: 600, width: 200, height: 40))], frameSize: Self.frameSize)
        await waitUntil { !viewModel.detectedItems.isEmpty }
        camera.emitMotion(CGPoint(x: 40, y: -20))
        await waitUntil { controller.motionOffset == CGSize(width: 20, height: -10) }

        controller.pinch(by: 2)

        #expect(controller.motionOffset == .zero)
        #expect(viewModel.detectedItems.map(\.bounds) == [CGRect(x: 40, y: 80, width: 200, height: 40)])
    }

    @Test("stopping the camera lets its labels go", .timeLimit(.minutes(1)))
    func stoppingLetsLabelsGo() async {
        await startCamera()
        camera.emitRead([price(framed: CGRect(x: 500, y: 1000, width: 200, height: 40))], frameSize: Self.frameSize)
        await waitUntil { !viewModel.detectedItems.isEmpty }

        controller.stop()

        await waitUntil { clock.pendingSleepCount == 1 }
        clock.advance(by: .milliseconds(500))
        await waitUntil { viewModel.detectedItems.isEmpty }
    }

    @Test("restarting the camera returns the zoom to 1x")
    func restartReturnsZoomToOneX() async {
        await startCamera()
        await waitUntil { controller.zoom.maximumRatio == 10 }
        controller.pinch(by: 3)
        controller.endPinch()
        #expect(controller.zoom.ratio == 3)

        controller.stop()
        await waitUntil { !camera.isRunning }
        await startCamera()

        #expect(controller.zoom.ratio == 1)
    }
}
