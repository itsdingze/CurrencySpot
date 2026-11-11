@testable import CurrencySpot
import CoreGraphics
import Foundation
import Testing
import UIKit

struct FrameMotionEstimatorTests {
    @Test("the first frame has nothing to compare against")
    func firstFrameHasNoMotion() throws {
        var estimator = FrameMotionEstimator()

        #expect(try estimator.displacement(to: Self.frame(windowAt: CGPoint(x: 40, y: 100))) == nil)
    }

    @Test("content that moves up and left reports a negative displacement in frame pixels")
    func reportsContentDisplacement() throws {
        var estimator = FrameMotionEstimator()
        _ = try estimator.displacement(to: Self.frame(windowAt: CGPoint(x: 40, y: 100)))

        let displacement = try #require(try estimator.displacement(to: Self.frame(windowAt: CGPoint(x: 80, y: 124))))

        #expect(abs(displacement.x + 40) <= 4)
        #expect(abs(displacement.y + 24) <= 4)
    }

    private static func frame(windowAt origin: CGPoint) throws -> CVPixelBuffer {
        let bundle = Bundle(for: MotionFixtureMarker.self).bundleURL
        let url = try #require(
            FileManager.default.enumerator(at: bundle, includingPropertiesForKeys: nil)?
                .compactMap { $0 as? URL }
                .first { $0.lastPathComponent == "1-menu-en-yen.png" }
        )
        let photo = try #require(UIImage(contentsOfFile: url.path)?.cgImage)
        let window = try #require(photo.cropping(to: CGRect(origin: origin, size: CGSize(width: 600, height: 1100))))
        return try #require(CapturedFrame.rendering(window)).pixelBuffer
    }
}

private final class MotionFixtureMarker {}
