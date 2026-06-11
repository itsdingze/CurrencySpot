//
//  StillImageTextRecognizer.swift
//  CurrencySpot
//

import UIKit
import Vision

/// Still-image counterpart of the live scanner: recognizes text in a frozen
/// frame or an imported photo. Bounds are in pixel coordinates (origin
/// top-left) of `imagePixelSize` — the caller maps them into view space.
struct StillRecognitionResult: Equatable, Sendable {
    let items: [RecognizedTextItem]
    let imagePixelSize: CGSize

    static let empty = StillRecognitionResult(items: [], imagePixelSize: .zero)
}

protocol StillTextRecognitionService: Sendable {
    func recognize(_ image: UIImage) async throws -> StillRecognitionResult
}

struct StillImageTextRecognizer: StillTextRecognitionService {
    func recognize(_ image: UIImage) async throws -> StillRecognitionResult {
        guard let cgImage = image.orientationNormalized.cgImage else { return .empty }

        let request = RecognizeTextRequest()
        let observations = try await request.perform(on: cgImage)

        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let items = observations.compactMap { observation -> RecognizedTextItem? in
            guard let transcript = observation.topCandidates(1).first?.string else { return nil }
            return RecognizedTextItem(
                id: observation.uuid,
                transcript: transcript,
                bounds: observation.boundingBox.toImageCoordinates(imageSize, origin: .upperLeft)
            )
        }
        return StillRecognitionResult(items: items, imagePixelSize: imageSize)
    }
}

private extension UIImage {
    /// Vision works on the raw CGImage, which ignores EXIF orientation.
    /// Redraw rotated photos so pixels match what the user sees.
    var orientationNormalized: UIImage {
        guard imageOrientation != .up else { return self }
        return UIGraphicsImageRenderer(size: size).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
