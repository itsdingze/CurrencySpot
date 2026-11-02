@testable import CurrencySpot
import Testing
import UIKit

@Suite("Still Image Text Recognizer Tests", .serialized)
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

    private func menuImage(lines: [String], fontName: String, fontSize: CGFloat = 40, width: CGFloat = 1200) throws -> UIImage {
        let font = try #require(UIFont(name: fontName, size: fontSize))
        let lineHeight = fontSize * 1.9
        let size = CGSize(width: width, height: CGFloat(lines.count) * lineHeight + fontSize * 2)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            for (index, line) in lines.enumerated() {
                NSAttributedString(string: line, attributes: [.font: font, .foregroundColor: UIColor.black])
                    .draw(at: CGPoint(x: 40, y: fontSize + lineHeight * CGFloat(index)))
            }
        }
    }

    @Test("a blank image yields no items and reports its pixel size")
    func blankImageYieldsNoItems() async throws {
        let result = try await recognizer.recognize(solidImage(width: 120, height: 60), menuCurrency: "USD")

        #expect(result.items.isEmpty)
        #expect(result.imagePixelSize == CGSize(width: 120, height: 60))
    }

    @Test("an EXIF-rotated image is normalized to its upright pixel size, not the screen scale")
    func rotatedImageIsNormalized() async throws {
        let landscapePixels = try solidImage(width: 120, height: 60, orientation: .right)

        let result = try await recognizer.recognize(landscapePixels, menuCurrency: "USD")

        #expect(result.imagePixelSize == CGSize(width: 60, height: 120))
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

        let result = try await recognizer.recognize(image, menuCurrency: "USD")

        let item = try #require(result.items.first)
        #expect(item.transcript.contains("USD"))
        #expect(result.imagePixelSize == size)
        #expect(CGRect(origin: .zero, size: size).contains(item.bounds))
    }

    @Test("a menu is read in the policy's languages, limited to those this system can read")
    func readingLanguagesComeFromThePolicyAndTheSystem() {
        let policy = RecognitionLanguagePolicy(preferredLanguageIdentifiers: ["fr-FR", "hu-HU"])

        let languages = StillImageTextRecognizer(languagePolicy: policy).recognitionLanguages(forMenuPricedIn: "JPY")

        #expect(languages == ["ja-JP", "fr-FR", "en-US"].map(Locale.Language.init(identifier:)))
    }

    @Test("a Japanese menu priced in yen is read with every price intact")
    func readsJapaneseMenuPricedInYen() async throws {
        let lines = [
            "ラーメン 850円", "餃子 ¥480", "からあげ定食 ￥1,050（税込）", "生ビール 600円",
            "ご飯 200円", "抹茶アイス ¥350", "天ぷらそば 1,280円",
        ]
        let menu = try menuImage(lines: lines, fontName: "HiraginoSans-W3")

        let result = try await recognizer.recognize(menu, menuCurrency: "JPY")

        let transcripts = result.items.map { $0.transcript.replacingOccurrences(of: "￥", with: "¥").filter { !$0.isWhitespace } }
        let prices = ["850円", "¥480", "1,050", "600円", "200円", "¥350", "1,280円"]
        let unread = prices.filter { price in !transcripts.contains { $0.contains(price) } }
        #expect(unread.isEmpty, "read: \(transcripts)")
    }

    @Test("the empty result carries no items and no pixel size")
    func emptyResultIsInert() {
        #expect(StillRecognitionResult.empty.items.isEmpty)
        #expect(StillRecognitionResult.empty.imagePixelSize == .zero)
    }
}
