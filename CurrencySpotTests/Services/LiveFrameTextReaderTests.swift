@testable import CurrencySpot
import Foundation
import Testing
import UIKit

@Suite("Live Frame Text Reader Tests", .serialized)
struct LiveFrameTextReaderTests {
    private static let frameWidth: CGFloat = 1080

    private let recognizer = StillImageTextRecognizer()
    private let rates = [
        ExchangeRate(currencyCode: "JPY", rate: 150),
        ExchangeRate(currencyCode: "EUR", rate: 0.9),
        ExchangeRate(currencyCode: "USD", rate: 1),
    ]

    @Test(
        "a full-frame live read finds the same prices as the freeze recognizer",
        arguments: [
            ("1-any-base.png", "USD"),
            ("1-menu-en-yen.png", "JPY"),
            ("2-menu-en-yen-tilt8.png", "JPY"),
            ("3-menu-ja.png", "JPY"),
            ("4-tags-eu.png", "EUR"),
            ("5-noise-and-multi.png", "USD"),
        ] as [(String, CurrencyCode)]
    )
    func liveReadMatchesFreeze(photo: String, base: CurrencyCode) async throws {
        let image = try Self.redrawnAtFrameWidth(Self.fixture(named: photo))
        let frame = try #require(image.cgImage.flatMap { CapturedFrame.rendering($0) })
        let languages = recognizer.recognitionLanguages(forMenuPricedIn: base)

        let live = try await LiveFrameTextReader().read(frame, languages: languages)
        let freeze = try await recognizer.recognize(image, menuCurrency: base).items

        let liveAmounts = priceAmounts(in: live, base: base)
        let freezeAmounts = priceAmounts(in: freeze, base: base)
        Attachment.record(
            "\(photo) \(base.rawValue) live \(live.count) lines \(liveAmounts), freeze \(freeze.count) lines \(freezeAmounts)",
            named: "parity-\(photo).txt"
        )
        #expect(!freezeAmounts.isEmpty)
        #expect(liveAmounts == freezeAmounts)
    }

    private func priceAmounts(in items: [RecognizedTextItem], base: CurrencyCode) -> [Decimal] {
        ScanConversionUseCase()
            .detect(in: items, baseCurrency: base, targetCurrency: base == .usd ? "EUR" : "USD", exchangeRates: rates)
            .items
            .filter(\.conversion.isPrice)
            .map(\.conversion.amount)
            .sorted()
    }

    private static func fixture(named name: String) throws -> UIImage {
        let bundle = Bundle(for: LiveCameraFixtureMarker.self).bundleURL
        let url = try #require(
            FileManager.default.enumerator(at: bundle, includingPropertiesForKeys: nil)?
                .compactMap { $0 as? URL }
                .first { $0.lastPathComponent == name }
        )
        return try #require(UIImage(contentsOfFile: url.path))
    }

    private static func redrawnAtFrameWidth(_ source: UIImage) -> UIImage {
        let size = CGSize(width: frameWidth, height: (source.size.height * frameWidth / source.size.width).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            source.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

private final class LiveCameraFixtureMarker {}
