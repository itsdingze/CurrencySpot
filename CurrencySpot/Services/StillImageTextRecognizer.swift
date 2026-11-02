import UIKit
import Vision

nonisolated protocol StillTextRecognitionService: Sendable {
    func recognitionLanguages(forMenuPricedIn currency: CurrencyCode) -> [Locale.Language]
    @concurrent func recognize(_ image: UIImage, menuCurrency: CurrencyCode) async throws -> StillRecognitionResult
}

nonisolated struct StillImageTextRecognizer: StillTextRecognitionService {
    private static let supportedLanguages = RecognizeTextRequest().supportedRecognitionLanguages

    private let languagePolicy: RecognitionLanguagePolicy

    init(languagePolicy: RecognitionLanguagePolicy = RecognitionLanguagePolicy(preferredLanguageIdentifiers: Locale.preferredLanguages)) {
        self.languagePolicy = languagePolicy
    }

    func recognitionLanguages(forMenuPricedIn currency: CurrencyCode) -> [Locale.Language] {
        languagePolicy.languages(forMenuPricedIn: currency, supportedBy: Self.supportedLanguages)
    }

    @concurrent
    func recognize(_ image: UIImage, menuCurrency: CurrencyCode) async throws -> StillRecognitionResult {
        guard let cgImage = image.orientationNormalized.cgImage else { return .empty }

        var request = RecognizeTextRequest()
        request.recognitionLanguages = recognitionLanguages(forMenuPricedIn: menuCurrency)
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
