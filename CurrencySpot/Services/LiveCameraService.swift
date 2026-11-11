import AVFoundation
import CoreGraphics
import UIKit

nonisolated struct LiveCameraRead: Sendable {
    let items: [RecognizedTextItem]
    let frameSize: CGSize
    let motionAtFrame: CGPoint
    let epoch: Int
}

nonisolated struct LiveCameraMotion: Sendable {
    let cumulative: CGPoint
    let epoch: Int
}

nonisolated struct CaptureSessionHandle: @unchecked Sendable {
    let session: AVCaptureSession
}

nonisolated enum LiveCameraPreview: Sendable {
    case session(CaptureSessionHandle)
    case still(UIImage)
    case blank
}

nonisolated protocol LiveCameraService: Sendable {
    var reads: AsyncStream<LiveCameraRead> { get }
    var motions: AsyncStream<LiveCameraMotion> { get }
    var preview: LiveCameraPreview { get }
    var maximumZoomRatio: CGFloat { get async }

    func start(epoch: Int) async
    func stop() async
    func setZoom(ratio: CGFloat, epoch: Int) async
    func setLanguages(_ languages: [Locale.Language]) async
    func capturePhoto(croppedTo aspectRatio: CGFloat?) async throws -> UIImage?
}
