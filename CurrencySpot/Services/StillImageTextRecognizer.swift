import UIKit
import Vision

nonisolated struct StillRecognitionResult: Equatable, Sendable {
    let items: [RecognizedTextItem]
    let imagePixelSize: CGSize

    static let empty = StillRecognitionResult(items: [], imagePixelSize: .zero)
}

nonisolated protocol StillTextRecognitionService: Sendable {
    @concurrent func recognize(_ image: UIImage) async throws -> StillRecognitionResult
}

nonisolated struct StillImageTextRecognizer: StillTextRecognitionService {
    @concurrent
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

private nonisolated extension UIImage {
    var orientationNormalized: UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
