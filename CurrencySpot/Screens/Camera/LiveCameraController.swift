import CoreGraphics
import Foundation
import Observation
import UIKit

@Observable
final class LiveCameraController {
    private(set) var motionOffset = CGSize.zero
    private(set) var zoom = CameraZoom(deviceMaximumRatio: 1)

    @ObservationIgnored private let camera: any LiveCameraService
    @ObservationIgnored private let viewModel: CameraViewModel
    @ObservationIgnored private var identities = LiveItemIdentities()
    @ObservationIgnored private var viewSize = CGSize.zero
    @ObservationIgnored private var frameSize = CGSize.zero
    @ObservationIgnored private var isRunning = false
    @ObservationIgnored private var run = 0
    @ObservationIgnored private var epoch = 0
    @ObservationIgnored private var motionAtShownRead: CGPoint?
    @ObservationIgnored private var latestMotion = CGPoint.zero
    @ObservationIgnored private var consumers: [Task<Void, Never>] = []
    @ObservationIgnored private var lastCommand: Task<Void, Never>?

    init(camera: any LiveCameraService, viewModel: CameraViewModel) {
        self.camera = camera
        self.viewModel = viewModel
    }

    var preview: LiveCameraPreview {
        camera.preview
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        consumeEventsIfNeeded()
        run += 1
        beginEpoch(motionAtShownRead: nil)
        identities = LiveItemIdentities()
        viewModel.clearLiveItems()
        zoom.reset(deviceMaximumRatio: 1)
        let epoch = epoch
        send { [weak self] camera in
            await camera.start(epoch: epoch)
            let maximumRatio = await camera.maximumZoomRatio
            guard let self, isRunning, self.epoch == epoch else { return }
            zoom.reset(deviceMaximumRatio: maximumRatio)
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        beginEpoch(motionAtShownRead: nil)
        viewModel.updateLiveRecognizedItems([])
        send { await $0.stop() }
    }

    func previewSizeChanged(_ size: CGSize) {
        viewSize = size
    }

    func setLanguages(_ languages: [Locale.Language]) {
        send { await $0.setLanguages(languages) }
    }

    func capturePhoto() async throws -> UIImage? {
        await lastCommand?.value
        guard isRunning else { return nil }
        let capturingRun = run
        let aspectRatio = viewSize.height > 0 ? viewSize.width / viewSize.height : nil
        do {
            return try await camera.capturePhoto(croppedTo: aspectRatio)
        } catch {
            guard isRunning, run == capturingRun else { throw CancellationError() }
            throw error
        }
    }

    func pinch(by magnification: CGFloat) {
        changeZoom { $0.pinch(by: magnification) }
    }

    func endPinch() {
        zoom.endPinch()
    }

    func zoomIn() {
        changeZoom { $0.zoomIn() }
    }

    func zoomOut() {
        changeZoom { $0.zoomOut() }
    }

    private func changeZoom(_ change: (inout CameraZoom) -> Void) {
        guard isRunning else { return }
        let previousRatio = zoom.ratio
        change(&zoom)
        guard zoom.ratio != previousRatio else { return }
        let center = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        let scale = zoom.ratio / previousRatio
        move(by: CGAffineTransform(translationX: motionOffset.width - center.x, y: motionOffset.height - center.y)
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: center.x, y: center.y)))
        beginEpoch(motionAtShownRead: motionAtShownRead == nil ? nil : .zero)
        let (ratio, epoch) = (zoom.ratio, epoch)
        send { await $0.setZoom(ratio: ratio, epoch: epoch) }
    }

    private func show(_ read: LiveCameraRead) {
        guard isRunning, read.epoch == epoch, viewSize.width > 0, viewSize.height > 0 else { return }
        frameSize = read.frameSize
        let mapping = AspectFillMapping(imageSize: read.frameSize, viewSize: viewSize)
        if let motionAtShownRead {
            let shift = mapping.viewDistance(read.motionAtFrame - motionAtShownRead)
            move(by: CGAffineTransform(translationX: shift.x, y: shift.y))
        }
        motionAtShownRead = read.motionAtFrame
        let preview = CGRect(origin: .zero, size: viewSize)
        let items = read.items
            .map { $0.mapped(mapping.viewPoint) }
            .filter { preview.contains($0.quad.center) }
        viewModel.updateLiveRecognizedItems(identities.identify(items))
        updateMotionOffset()
    }

    private func follow(_ motion: LiveCameraMotion) {
        guard isRunning, motion.epoch == epoch else { return }
        latestMotion = motion.cumulative
        updateMotionOffset()
    }

    private func updateMotionOffset() {
        var offset = CGSize.zero
        if let motionAtShownRead {
            let distance = AspectFillMapping(imageSize: frameSize, viewSize: viewSize).viewDistance(latestMotion - motionAtShownRead)
            offset = CGSize(width: distance.x, height: distance.y)
        }
        if motionOffset != offset {
            motionOffset = offset
        }
    }

    private func move(by transform: CGAffineTransform) {
        guard !transform.isIdentity else { return }
        identities.transform(by: transform)
        viewModel.moveLiveItems(by: transform)
    }

    private func beginEpoch(motionAtShownRead anchor: CGPoint?) {
        epoch += 1
        motionAtShownRead = anchor
        latestMotion = .zero
        updateMotionOffset()
    }

    private func consumeEventsIfNeeded() {
        guard consumers.isEmpty else { return }
        let reads = camera.reads
        let motions = camera.motions
        consumers = [
            Task { [weak self] in
                for await read in reads {
                    self?.show(read)
                }
            },
            Task { [weak self] in
                for await motion in motions {
                    self?.follow(motion)
                }
            },
        ]
    }

    private func send(_ command: @escaping @MainActor (any LiveCameraService) async -> Void) {
        let previous = lastCommand
        lastCommand = Task { [camera] in
            await previous?.value
            await command(camera)
        }
    }
}
