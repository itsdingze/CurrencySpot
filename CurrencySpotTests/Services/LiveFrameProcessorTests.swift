@testable import CurrencySpot
import CoreMedia
import Foundation
import Testing
import UIKit

struct LiveFrameProcessorTests {
    private let image: CGImage

    init() throws {
        let bundle = Bundle(for: ProcessorFixtureMarker.self).bundleURL
        let url = try #require(
            FileManager.default.enumerator(at: bundle, includingPropertiesForKeys: nil)?
                .compactMap { $0 as? URL }
                .first { $0.lastPathComponent == "1-menu-en-yen.png" }
        )
        image = try #require(UIImage(contentsOfFile: url.path)?.cgImage)
    }

    private func frame(at seconds: Int64) throws -> CapturedFrame {
        try #require(CapturedFrame.rendering(image, presentationTime: CMTime(value: seconds, timescale: 1)))
    }

    @Test("frames captured before a zoom took effect are neither read nor registered")
    func framesFromBeforeAZoomAreSkipped() throws {
        var processor = LiveFrameProcessor()
        processor.restart(epoch: 2, takingFramesAfter: CMTime(value: 10, timescale: 1))

        let early = processor.receive(try frame(at: 9), thermalState: .nominal, now: .now)
        let first = processor.receive(try frame(at: 11), thermalState: .nominal, now: .now)
        let second = processor.receive(try frame(at: 12), thermalState: .nominal, now: .now)

        #expect(early.read == nil)
        #expect(early.motion == nil)
        #expect(first.read?.epoch == 2)
        #expect(first.motion == nil)
        #expect(second.motion?.epoch == 2)
    }
}

private final class ProcessorFixtureMarker {}
