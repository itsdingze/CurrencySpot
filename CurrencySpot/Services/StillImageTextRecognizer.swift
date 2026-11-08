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
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)

        var candidates: [RecognizedTextCandidate] = []
        for region in RecognitionRegion.regions(covering: imageSize) {
            try Task.checkCancellation()
            candidates += try await Self.candidates(in: region, of: cgImage, sized: imageSize, using: request)
        }
        try Task.checkCancellation()
        let items = LineInkGaps.marking(RecognizedTextMerger.merge(candidates), in: GrayscaleImage(cgImage))
        return StillRecognitionResult(items: items, imagePixelSize: imageSize)
    }

    private static func candidates(
        in region: RecognitionRegion,
        of image: CGImage,
        sized imageSize: CGSize,
        using request: RecognizeTextRequest
    ) async throws -> [RecognizedTextCandidate] {
        var request = request
        let regionOfInterest = region.normalizedRect(in: imageSize)
        request.regionOfInterest = regionOfInterest
        return try await request.perform(on: image).compactMap { observation in
            let bounds = observation.boundingBox.toImageCoordinates(from: regionOfInterest, imageSize: imageSize, origin: .upperLeft)
            guard region.keeps(bounds) else { return nil }
            return RecognizedTextCandidate(observation, regionOfInterest: regionOfInterest, imageSize: imageSize)
        }
    }
}

private nonisolated extension RecognitionRegion {
    func normalizedRect(in imageSize: CGSize) -> NormalizedRect {
        NormalizedRect(
            x: rect.minX / imageSize.width,
            y: 1 - rect.maxY / imageSize.height,
            width: rect.width / imageSize.width,
            height: rect.height / imageSize.height
        )
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
