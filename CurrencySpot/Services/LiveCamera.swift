import AVFoundation
import CoreGraphics
import Foundation
import OSLog
import UIKit

actor LiveCamera: LiveCameraService {
    nonisolated let reads: AsyncStream<LiveCameraRead>
    nonisolated let motions: AsyncStream<LiveCameraMotion>
    nonisolated let preview: LiveCameraPreview

    private nonisolated let queue = DispatchSerialQueue(label: "com.dingze.CurrencySpot.live-camera")
    private let readsContinuation: AsyncStream<LiveCameraRead>.Continuation
    private let motionsContinuation: AsyncStream<LiveCameraMotion>.Continuation
    private let session: AVCaptureSession
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private let reader = LiveFrameTextReader()
    private let logger = Logger(category: .ui)
    #if DEBUG
    private let fakeFrame: FakeCameraFrame?
    private var fakeFrameTask: Task<Void, Never>?
    #endif

    private var frameDelegate: FrameDelegate?
    private var photoDelegate: PhotoCaptureDelegate?
    private var runtimeErrorTask: Task<Void, Never>?
    private var device: AVCaptureDevice?
    private var isConfigured = false
    private var isRunning = false
    private var languages: [Locale.Language] = []
    private var frames = LiveFrameProcessor()
    private var videoAspectRatio: CGFloat?

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        queue.asUnownedSerialExecutor()
    }

    init() {
        (reads, readsContinuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
        (motions, motionsContinuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
        let session = AVCaptureSession()
        self.session = session
        #if DEBUG
        let fakeFrame = FakeCameraFrame.fromLaunchArguments()
        self.fakeFrame = fakeFrame
        preview = fakeFrame.map { .still($0.image) } ?? .session(CaptureSessionHandle(session: session))
        #else
        preview = .session(CaptureSessionHandle(session: session))
        #endif
    }

    var maximumZoomRatio: CGFloat {
        guard let device else { return 1 }
        return CameraZoomFactors.maximumRatio(
            switchOverFactors: Self.switchOverFactors(of: device),
            maximumFactor: device.maxAvailableVideoZoomFactor
        )
    }

    func start(epoch: Int) {
        frames.restart(epoch: epoch, takingFramesAfter: .negativeInfinity)
        guard !isRunning else { return }
        isRunning = true
        #if DEBUG
        if let fakeFrame {
            videoAspectRatio = Self.aspectRatio(of: fakeFrame.frame.size)
            feed(fakeFrame)
            return
        }
        #endif
        guard let device = configureIfNeeded() else { return }
        applyZoom(ratio: 1, to: device)
        observeRuntimeErrors()
        session.startRunning()
    }

    func stop() {
        isRunning = false
        runtimeErrorTask?.cancel()
        runtimeErrorTask = nil
        #if DEBUG
        fakeFrameTask?.cancel()
        fakeFrameTask = nil
        #endif
        if session.isRunning {
            session.stopRunning()
        }
    }

    func setZoom(ratio: CGFloat, epoch: Int) {
        if let device {
            applyZoom(ratio: ratio, to: device)
        }
        frames.restart(epoch: epoch, takingFramesAfter: captureClockTime)
    }

    func setLanguages(_ languages: [Locale.Language]) {
        self.languages = languages
    }

    func capturePhoto(croppedTo previewAspectRatio: CGFloat?) async throws -> UIImage? {
        #if DEBUG
        if let fakeFrame {
            return await crop(fakeFrame.image, toPreviewAspectRatio: previewAspectRatio)
        }
        #endif
        guard isRunning, session.isRunning else { return nil }
        let settings = AVCapturePhotoSettings()
        settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
        defer { photoDelegate = nil }
        let data = try await withCheckedThrowingContinuation { continuation in
            let delegate = PhotoCaptureDelegate(continuation: continuation)
            photoDelegate = delegate
            photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
        guard let photo = UIImage(data: data) else { return nil }
        return await crop(photo, toPreviewAspectRatio: previewAspectRatio)
    }

    fileprivate func process(_ frame: CapturedFrame) {
        guard isRunning else { return }
        videoAspectRatio = Self.aspectRatio(of: frame.size) ?? videoAspectRatio
        let outcome = frames.receive(frame, thermalState: ProcessInfo.processInfo.thermalState, now: .now)
        if let motion = outcome.motion {
            motionsContinuation.yield(motion)
        }
        if let cleared = outcome.clearedForHeat {
            readsContinuation.yield(cleared)
        }
        if let pending = outcome.read {
            read(pending)
        }
    }

    private func read(_ pending: LiveFrameProcessor.PendingRead) {
        let reader = reader
        let languages = languages
        Task {
            let items = try? await reader.read(pending.frame, languages: languages)
            if let read = frames.finish(pending, items: items) {
                readsContinuation.yield(read)
            }
        }
    }

    private var captureClockTime: CMTime {
        CMClockGetTime(session.synchronizationClock ?? CMClockGetHostTimeClock())
    }

    private func crop(_ photo: UIImage, toPreviewAspectRatio previewAspectRatio: CGFloat?) async -> UIImage {
        let visible = PreviewCrop.visibleRect(
            in: photo.size,
            videoAspectRatio: videoAspectRatio,
            previewAspectRatio: previewAspectRatio
        )
        return await Self.crop(photo, to: visible)
    }

    @concurrent
    private static func crop(_ photo: UIImage, to rect: CGRect) async -> UIImage {
        photo.cropped(to: rect)
    }

    #if DEBUG
    private func feed(_ fakeFrame: FakeCameraFrame) {
        fakeFrameTask = Task {
            while !Task.isCancelled {
                process(CapturedFrame(pixelBuffer: fakeFrame.frame.pixelBuffer, presentationTime: captureClockTime))
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
    }
    #endif

    private func observeRuntimeErrors() {
        let errors = NotificationCenter.default.notifications(named: AVCaptureSession.runtimeErrorNotification)
        runtimeErrorTask = Task { [weak self] in
            for await _ in errors {
                await self?.restartAfterRuntimeError()
            }
        }
    }

    private func restartAfterRuntimeError() {
        guard isRunning else { return }
        logger.error("Live camera restarts after a capture session error")
        session.startRunning()
    }

    private func configureIfNeeded() -> AVCaptureDevice? {
        guard !isConfigured else { return device }
        isConfigured = true
        guard let device = BackCameraChoice.device(), let input = try? AVCaptureDeviceInput(device: device) else {
            logger.error("Live camera found no back camera")
            return nil
        }
        session.beginConfiguration()
        session.sessionPreset = .hd1920x1080
        let isComplete = add(input)
        session.commitConfiguration()
        guard isComplete else {
            logger.error("Live camera could not set up its capture session")
            return nil
        }
        rotateOutputsToPortrait()
        let videoDimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
        videoAspectRatio = Self.aspectRatio(of: CGSize(width: CGFloat(videoDimensions.height), height: CGFloat(videoDimensions.width)))
        photoOutput.maxPhotoDimensions = Self.largestPhotoDimensions(of: device) ?? photoOutput.maxPhotoDimensions
        configureFocusAndExposure(of: device)
        let photoSize = photoOutput.maxPhotoDimensions
        logger.info("Live camera uses \(device.localizedName, privacy: .public), photos \(photoSize.width)x\(photoSize.height)")
        self.device = device
        return device
    }

    private func add(_ input: AVCaptureDeviceInput) -> Bool {
        guard session.canAddInput(input) else { return false }
        session.addInput(input)
        let delegate = FrameDelegate(camera: self)
        frameDelegate = delegate
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        videoOutput.setSampleBufferDelegate(delegate, queue: queue)
        guard session.canAddOutput(videoOutput) else { return false }
        session.addOutput(videoOutput)
        guard session.canAddOutput(photoOutput) else { return false }
        session.addOutput(photoOutput)
        return true
    }

    private func rotateOutputsToPortrait() {
        let connections = [videoOutput.connection(with: .video), photoOutput.connection(with: .video)].compactMap { $0 }
        for connection in connections where connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
    }

    private func configureFocusAndExposure(of device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
        } catch {
            logger.error("Live camera focus setup failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func applyZoom(ratio: CGFloat, to device: AVCaptureDevice) {
        let factor = CameraZoomFactors.zoomFactor(
            forRatio: ratio,
            switchOverFactors: Self.switchOverFactors(of: device),
            minimum: device.minAvailableVideoZoomFactor,
            maximum: device.maxAvailableVideoZoomFactor
        )
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            device.videoZoomFactor = factor
        } catch {
            logger.error("Live camera zoom failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func aspectRatio(of size: CGSize) -> CGFloat? {
        size.width > 0 && size.height > 0 ? size.width / size.height : nil
    }

    private static func switchOverFactors(of device: AVCaptureDevice) -> [CGFloat] {
        device.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat(truncating: $0) }
    }

    private static func largestPhotoDimensions(of device: AVCaptureDevice) -> CMVideoDimensions? {
        device.activeFormat.supportedMaxPhotoDimensions.max { Int($0.width) * Int($0.height) < Int($1.width) * Int($1.height) }
    }
}

private nonisolated final class FrameDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, Sendable {
    private let camera: LiveCamera

    init(camera: LiveCamera) {
        self.camera = camera
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
        let frame = CapturedFrame(pixelBuffer: pixelBuffer, presentationTime: sampleBuffer.presentationTimeStamp)
        camera.assumeIsolated { $0.process(frame) }
    }
}
