@testable import CurrencySpot
import Testing
import UIKit

@Suite("Still Image Text Recognizer Tests")
struct StillImageTextRecognizerTests {
    private let recognizer = StillImageTextRecognizer()

    private func solidImage(width: Int, height: Int, orientation: UIImage.Orientation = .up) throws -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let size = CGSize(width: width, height: height)
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        let cgImage = try #require(rendered.cgImage)
        return UIImage(cgImage: cgImage, scale: 1, orientation: orientation)
    }

    @Test("a blank image yields no items and reports its pixel size")
    func blankImageYieldsNoItems() async throws {
        let result = try await recognizer.recognize(solidImage(width: 120, height: 60))

        #expect(result.items.isEmpty)
        #expect(result.imagePixelSize == CGSize(width: 120, height: 60))
    }

    @Test("an EXIF-rotated image is normalized before recognition")
    func rotatedImageIsNormalized() async throws {
        let landscapePixels = try solidImage(width: 120, height: 60, orientation: .right)

        let result = try await recognizer.recognize(landscapePixels)

        #expect(result.imagePixelSize.width < result.imagePixelSize.height)
    }

    @Test("recognized text is reported with bounds inside the image")
    func recognizesRenderedText() async throws {
        let size = CGSize(width: 400, height: 200)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 96, weight: .bold),
                .foregroundColor: UIColor.black,
            ]
            NSAttributedString(string: "USD", attributes: attributes)
                .draw(at: CGPoint(x: 40, y: 50))
        }

        let result = try await recognizer.recognize(image)

        let item = try #require(result.items.first)
        #expect(item.transcript.contains("USD"))
        #expect(result.imagePixelSize == size)
        #expect(CGRect(origin: .zero, size: size).contains(item.bounds))
    }

    @Test("the empty result carries no items and no pixel size")
    func emptyResultIsInert() {
        #expect(StillRecognitionResult.empty.items.isEmpty)
        #expect(StillRecognitionResult.empty.imagePixelSize == .zero)
    }
}
