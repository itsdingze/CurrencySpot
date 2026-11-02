import UIKit
import Vision

nonisolated protocol StillTextRecognitionService: Sendable {
    func recognitionLanguages(forMenuPricedIn currency: CurrencyCode) -> [Locale.Language]
    @concurrent func recognize(_ image: UIImage, menuCurrency: CurrencyCode) async throws -> StillRecognitionResult
}

nonisolated struct StillImageTextRecognizer: StillTextRecognitionService {
    private static let supportedLanguages = RecognizeTextRequest().supportedRecognitionLanguages
    private static let maximumReadings = 5

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
        let items = Self.withInkGaps(RecognizedTextMerger.merge(candidates), in: cgImage)
        return StillRecognitionResult(items: items, imagePixelSize: imageSize)
    }

    private static func withInkGaps(_ items: [RecognizedTextItem], in image: CGImage) -> [RecognizedTextItem] {
        let hasDigits = { (item: RecognizedTextItem) in item.transcript.contains(where: \.isNumber) }
        guard items.contains(where: hasDigits), let grayscale = GrayscaleImage(image) else { return items }
        return items.map { hasDigits($0) ? $0.with(inkGaps: LineInkGaps.gaps(along: $0.quad, in: grayscale)) : $0 }
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
            let readings = observation.topCandidates(maximumReadings)
            guard let topCandidate = readings.first else { return nil }
            let bounds = observation.boundingBox.toImageCoordinates(from: regionOfInterest, imageSize: imageSize, origin: .upperLeft)
            guard region.keeps(bounds) else { return nil }
            func imagePoint(_ point: NormalizedPoint) -> CGPoint {
                point.toImageCoordinates(from: regionOfInterest, imageSize: imageSize, origin: .upperLeft)
            }
            let item = RecognizedTextItem(
                id: observation.uuid,
                transcript: topCandidate.string,
                quad: Quad(
                    topLeft: imagePoint(observation.topLeft),
                    topRight: imagePoint(observation.topRight),
                    bottomRight: imagePoint(observation.bottomRight),
                    bottomLeft: imagePoint(observation.bottomLeft)
                ),
                characterSpans: characterSpans(of: topCandidate, along: Quad(normalized: observation)),
                alternateTranscripts: readings.dropFirst().map(\.string)
            )
            return RecognizedTextCandidate(item: item, confidence: topCandidate.confidence)
        }
    }

    private static func characterSpans(of text: RecognizedText, along line: Quad) -> [ClosedRange<CGFloat>]? {
        let transcript = text.string
        guard transcript.contains(where: \.isNumber) else { return nil }
        var spans: [ClosedRange<CGFloat>] = []
        var index = transcript.startIndex
        while index < transcript.endIndex {
            let next = transcript.index(after: index)
            guard let glyph = text.boundingBox(for: index ..< next) else { return nil }
            spans.append(line.baselineSpan(of: Quad(normalized: glyph)))
            index = next
        }
        return spans
    }
}

private nonisolated extension Quad {
    init(normalized region: some QuadrilateralProviding) {
        self.init(
            topLeft: CGPoint(x: region.topLeft.x, y: region.topLeft.y),
            topRight: CGPoint(x: region.topRight.x, y: region.topRight.y),
            bottomRight: CGPoint(x: region.bottomRight.x, y: region.bottomRight.y),
            bottomLeft: CGPoint(x: region.bottomLeft.x, y: region.bottomLeft.y)
        )
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
