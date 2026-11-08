import AVFoundation
import Foundation
import Synchronization

nonisolated final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, Sendable {
    private let continuation: Mutex<CheckedContinuation<Data, any Error>?>

    init(continuation: CheckedContinuation<Data, any Error>) {
        self.continuation = Mutex(continuation)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: (any Error)?) {
        if let error {
            resume(with: .failure(error))
        } else if let data = photo.fileDataRepresentation() {
            resume(with: .success(data))
        } else {
            resume(with: .failure(AppError.cameraCaptureFailed))
        }
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: (any Error)?
    ) {
        resume(with: .failure(error ?? AppError.cameraCaptureFailed))
    }

    private func resume(with result: Result<Data, any Error>) {
        continuation.withLock { $0.take() }?.resume(with: result)
    }
}
