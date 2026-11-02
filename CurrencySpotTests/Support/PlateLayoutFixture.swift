import CoreGraphics
import Foundation
import SwiftUI
import Testing
import UIKit
@testable import CurrencySpot

struct PlateLayoutFixture {
    static let frameSize = CGSize(width: 402, height: 760)

    nonisolated static let names = [
        "1-menu-en-yen",
        "2-menu-en-yen-tilt8",
        "3-menu-ja",
        "4-tags-eu",
        "5-noise-and-multi",
        "6-real-sushi-menu",
        "7-real-price-tag",
    ]

    private struct Recording: Decodable {
        struct Line: Decodable {
            let transcript: String
            let alternates: [String]
            let quad: [Double]
            let characterSpans: [[Double]]?
        }

        let photo: String
        let imageWidth: Double
        let imageHeight: Double
        let baseCurrency: String
        let targetCurrency: String
        let rate: String
        let lines: [Line]
    }

    let name: String
    let photoURL: URL
    let imageSize: CGSize
    let items: [RecognizedTextItem]
    let detected: [DetectedItem]
    let targetCurrency: CurrencyCode

    var imageFrame: CGRect {
        AspectFitMapping(imageSize: imageSize, viewSize: Self.frameSize)
            .viewRect(for: CGRect(origin: .zero, size: imageSize))
    }

    var prices: [DetectedItem] {
        detected.filter(\.conversion.isPrice)
    }

    init(_ name: String) throws {
        let recording = try Self.recording(named: name)
        let items = recording.lines.enumerated().map { index, line in
            RecognizedTextItem(
                id: Self.lineID(name: name, index: index),
                transcript: line.transcript,
                quad: Self.quad(from: line.quad),
                characterSpans: line.characterSpans.map(Self.spans),
                alternateTranscripts: line.alternates
            )
        }
        try self.init(name: name, recording: recording, imageItems: items)
    }

    static func readOnThisDevice(_ name: String) async throws -> PlateLayoutFixture {
        let recording = try recording(named: name)
        let photoURL = try #require(resource(named: recording.photo, in: bundleDirectory))
        let image = try #require(UIImage(contentsOfFile: photoURL.path))
        let recognizer = StillImageTextRecognizer(languagePolicy: RecognitionLanguagePolicy(preferredLanguageIdentifiers: ["en-US"]))
        let result = try await recognizer.recognize(image, menuCurrency: CurrencyCode(validating: recording.baseCurrency))
        return try PlateLayoutFixture(name: name, recording: recording, imageItems: result.items)
    }

    private static var bundleDirectory: URL {
        Bundle(for: FixtureBundleMarker.self).bundleURL
    }

    private static func recording(named name: String) throws -> Recording {
        let jsonURL = try #require(resource(named: "\(name).json", in: bundleDirectory))
        return try JSONDecoder().decode(Recording.self, from: Data(contentsOf: jsonURL))
    }

    private init(name: String, recording: Recording, imageItems: [RecognizedTextItem]) throws {
        let directory = Self.bundleDirectory
        let imageSize = CGSize(width: recording.imageWidth, height: recording.imageHeight)
        let mapping = AspectFitMapping(imageSize: imageSize, viewSize: Self.frameSize)
        let items = imageItems.map { $0.mapped(mapping.viewPoint) }
        let base = try CurrencyCode(validating: recording.baseCurrency)
        let target = try CurrencyCode(validating: recording.targetCurrency)
        let rate = try #require(Double(recording.rate))
        let rates = base == .usd
            ? [ExchangeRate(currencyCode: target, rate: rate)]
            : [ExchangeRate(currencyCode: base, rate: 1), ExchangeRate(currencyCode: target, rate: rate)]
        self.name = name
        self.imageSize = imageSize
        self.items = items
        self.targetCurrency = target
        photoURL = Self.resource(named: recording.photo, in: directory) ?? directory
        detected = ScanConversionUseCase().detect(
            in: items,
            baseCurrency: base,
            targetCurrency: target,
            exchangeRates: rates
        ).items
    }

    func plateText(_ item: DetectedItem) -> String {
        item.conversion.converted.formatted(.currency(code: targetCurrency.rawValue).locale(Locale(identifier: "en_US")))
    }

    func layout() -> PlateLayout.Result {
        PlateLayout(frame: imageFrame, measureText: { PlateTextWidth.of($0, fontSize: $1, legibilityWeight: .regular) })
            .layout(detected, text: plateText)
    }

    private static func quad(from values: [Double]) -> Quad {
        let points = stride(from: 0, to: 8, by: 2).map { CGPoint(x: values[$0], y: values[$0 + 1]) }
        return Quad(topLeft: points[0], topRight: points[1], bottomRight: points[2], bottomLeft: points[3])
    }

    private static func spans(_ values: [[Double]]) -> [ClosedRange<CGFloat>] {
        values.map { pair -> ClosedRange<CGFloat> in CGFloat(pair[0])...CGFloat(pair[1]) }
    }

    private static func lineID(name: String, index: Int) -> UUID {
        var bytes = UUID(uuidString: "00000000-0000-4000-8000-000000000000")?.uuid ?? UUID().uuid
        bytes.0 = UInt8(names.firstIndex(of: name) ?? 0)
        bytes.14 = UInt8(index / 256)
        bytes.15 = UInt8(index % 256)
        return UUID(uuid: bytes)
    }

    private static func resource(named name: String, in directory: URL) -> URL? {
        let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil)
        return enumerator?.compactMap { $0 as? URL }.first { $0.lastPathComponent == name }
    }
}

private final class FixtureBundleMarker {}
