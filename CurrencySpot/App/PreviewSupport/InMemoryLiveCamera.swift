#if DEBUG

    import CoreGraphics
    import Foundation
    import Synchronization
    import UIKit

    nonisolated final class InMemoryLiveCamera: LiveCameraService {
        private struct State {
            var epoch = 0
            var isRunning = false
            var zoomRatios: [CGFloat] = []
            var holdsCaptures = false
            var pendingCapture: CheckedContinuation<UIImage?, any Error>?
        }

        let reads: AsyncStream<LiveCameraRead>
        let motions: AsyncStream<LiveCameraMotion>
        let preview = LiveCameraPreview.blank
        let maximumZoomRatio: CGFloat

        private let photo: UIImage?
        private let readsContinuation: AsyncStream<LiveCameraRead>.Continuation
        private let motionsContinuation: AsyncStream<LiveCameraMotion>.Continuation
        private let state = Mutex(State())

        init(maximumZoomRatio: CGFloat = 10, photo: UIImage? = nil) {
            self.maximumZoomRatio = maximumZoomRatio
            self.photo = photo
            (reads, readsContinuation) = AsyncStream.makeStream()
            (motions, motionsContinuation) = AsyncStream.makeStream()
        }

        var hasPendingCapture: Bool {
            state.withLock { $0.pendingCapture != nil }
        }

        func holdCaptures() {
            state.withLock { $0.holdsCaptures = true }
        }

        func finishPendingCapture(with result: Result<UIImage?, any Error>) {
            state.withLock { $0.pendingCapture.take() }?.resume(with: result)
        }

        var isRunning: Bool {
            state.withLock { $0.isRunning }
        }

        var epoch: Int {
            state.withLock { $0.epoch }
        }

        var zoomRatios: [CGFloat] {
            state.withLock { $0.zoomRatios }
        }

        func start(epoch: Int) async {
            state.withLock { state in
                state.epoch = epoch
                state.isRunning = true
            }
        }

        func stop() async {
            state.withLock { $0.isRunning = false }
        }

        func setZoom(ratio: CGFloat, epoch: Int) async {
            state.withLock { state in
                state.epoch = epoch
                state.zoomRatios.append(ratio)
            }
        }

        func setLanguages(_ languages: [Locale.Language]) async {}

        func capturePhoto(croppedTo aspectRatio: CGFloat?) async throws -> UIImage? {
            let (isRunning, holdsCaptures) = state.withLock { ($0.isRunning, $0.holdsCaptures) }
            guard isRunning else { return nil }
            guard holdsCaptures else { return photo }
            return try await withCheckedThrowingContinuation { continuation in
                state.withLock { $0.pendingCapture = continuation }
            }
        }

        func emitRead(_ items: [RecognizedTextItem], frameSize: CGSize, motionAtFrame: CGPoint = .zero, epoch: Int? = nil) {
            readsContinuation.yield(
                LiveCameraRead(items: items, frameSize: frameSize, motionAtFrame: motionAtFrame, epoch: epoch ?? self.epoch)
            )
        }

        func emitMotion(_ cumulative: CGPoint) {
            motionsContinuation.yield(LiveCameraMotion(cumulative: cumulative, epoch: epoch))
        }
    }

#endif
