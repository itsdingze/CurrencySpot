import CoreGraphics
import CoreMedia
import Foundation

nonisolated struct LiveFrameProcessor {
    struct PendingRead: Sendable {
        let frame: CapturedFrame
        let motionAtFrame: CGPoint
        let epoch: Int
    }

    struct Outcome {
        var motion: LiveCameraMotion?
        var read: PendingRead?
        var clearedForHeat: LiveCameraRead?
    }

    private var estimator = FrameMotionEstimator()
    private var cumulativeMotion = CGPoint.zero
    private var epoch = 0
    private var firstFrameTime = CMTime.negativeInfinity
    private var isReading = false
    private var lastReadStart: ContinuousClock.Instant?
    private var isPausedForHeat = false

    mutating func restart(epoch: Int, takingFramesAfter time: CMTime) {
        self.epoch = epoch
        firstFrameTime = time
        estimator.reset()
        cumulativeMotion = .zero
    }

    mutating func receive(_ frame: CapturedFrame, thermalState: ProcessInfo.ThermalState, now: ContinuousClock.Instant) -> Outcome {
        guard frame.presentationTime > firstFrameTime else { return Outcome() }
        guard thermalState != .critical else {
            return Outcome(clearedForHeat: pauseForHeat(at: frame))
        }
        isPausedForHeat = false
        let motion = registerMotion(of: frame)
        return Outcome(motion: motion, read: startReadIfAllowed(of: frame, thermalState: thermalState, now: now))
    }

    mutating func finish(_ read: PendingRead, items: [RecognizedTextItem]?) -> LiveCameraRead? {
        isReading = false
        guard let items, !isPausedForHeat else { return nil }
        return LiveCameraRead(items: items, frameSize: read.frame.size, motionAtFrame: read.motionAtFrame, epoch: read.epoch)
    }

    private mutating func registerMotion(of frame: CapturedFrame) -> LiveCameraMotion? {
        guard let step = estimator.displacement(to: frame.pixelBuffer) else { return nil }
        cumulativeMotion = CGPoint(x: cumulativeMotion.x + step.x, y: cumulativeMotion.y + step.y)
        return LiveCameraMotion(cumulative: cumulativeMotion, epoch: epoch)
    }

    private mutating func startReadIfAllowed(
        of frame: CapturedFrame,
        thermalState: ProcessInfo.ThermalState,
        now: ContinuousClock.Instant
    ) -> PendingRead? {
        let sinceLastReadStart = lastReadStart.map { $0.duration(to: now) }
        guard !isReading, LiveReadPacing.allowsRead(thermalState: thermalState, sinceLastReadStart: sinceLastReadStart) else {
            return nil
        }
        isReading = true
        lastReadStart = now
        return PendingRead(frame: frame, motionAtFrame: cumulativeMotion, epoch: epoch)
    }

    private mutating func pauseForHeat(at frame: CapturedFrame) -> LiveCameraRead? {
        guard !isPausedForHeat else { return nil }
        isPausedForHeat = true
        estimator.reset()
        return LiveCameraRead(items: [], frameSize: frame.size, motionAtFrame: cumulativeMotion, epoch: epoch)
    }
}
