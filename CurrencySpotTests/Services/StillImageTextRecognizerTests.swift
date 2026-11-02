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

    @Test("small prices on a tall menu are each read once, whole, where they are printed")
    func readsSmallPricesOnATallMenu() async throws {
        let size = CGSize(width: 2016, height: 4032)
        let prices = (1 ... 30).map { "$\($0 + 3).50" }
        let font = UIFont.systemFont(ofSize: 28)
        let pitch = size.height * 0.88 / CGFloat(prices.count)
        let drawnTops = prices.indices.map { size.height * 0.06 + pitch * CGFloat($0) }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let menu = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            for (index, price) in prices.enumerated() {
                NSAttributedString(string: "Item \(index + 1) ........ \(price)", attributes: [.font: font, .foregroundColor: UIColor.black])
                    .draw(at: CGPoint(x: 160, y: drawnTops[index]))
            }
        }

        let result = try await recognizer.recognize(menu, menuCurrency: "USD")

        let amounts = result.items.flatMap { item in item.transcript.matches(of: /\$\d+(?:\.\d+)?/).map { String($0.output) } }
        #expect(Set(prices).subtracting(amounts).sorted().isEmpty, "read: \(amounts)")
        #expect(amounts.count == Set(amounts).count, "read: \(amounts)")
        #expect(amounts.filter { !prices.contains($0) }.isEmpty, "read: \(amounts)")
        for index in [prices.startIndex, prices.endIndex - 1] {
            let line = try #require(result.items.first { $0.transcript.contains(prices[index]) })
            #expect(abs(line.bounds.minY - drawnTops[index]) < size.height * 0.01, "\(prices[index]) at \(line.bounds)")
        }
    }

    @Test("every price on a menu photographed at a tilt is read, short lines beside long ones included")
    func readsEveryPriceOnATiltedMenu() async throws {
        let size = CGSize(width: 1200, height: 1000)
        let prices = (1 ... 14).map { "$\($0 + 10).50" }
        let lines = prices.enumerated().map { index, price in
            index.isMultiple(of: 3) ? "Soup \(price)" : "Grilled dish number \(index + 1) with seasonal vegetables ........ \(price)"
        }
        let font = try #require(UIFont(name: "Helvetica", size: 30))
        let pitch: CGFloat = 54
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let menu = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            context.cgContext.translateBy(x: size.width / 2, y: size.height / 2)
            context.cgContext.rotate(by: 5 * .pi / 180)
            context.cgContext.translateBy(x: -size.width / 2, y: -size.height / 2)
            for (index, line) in lines.enumerated() {
                NSAttributedString(string: line, attributes: [.font: font, .foregroundColor: UIColor.black])
                    .draw(at: CGPoint(x: 96, y: (size.height - pitch * CGFloat(lines.count)) / 2 + pitch * CGFloat(index)))
            }
        }

        let result = try await recognizer.recognize(menu, menuCurrency: "USD")

        let amounts = result.items.flatMap { item in item.transcript.matches(of: /\$\d+\.\d\d/).map { String($0.output) } }
        #expect(Set(prices).subtracting(amounts).sorted().isEmpty, "read: \(result.items.map(\.transcript))")
    }

    @Test("a price tag too tall for one band, straddling the seam between bands, is read once")
    func readsALargePriceTagAcrossABandSeam() async throws {
        let size = CGSize(width: 2016, height: 4032)
        let bands = RecognitionRegion.regions(covering: size).map(\.rect).filter { $0.height < size.height }
        let seam = (bands[0].maxY + bands[1].minY) / 2
        let font = UIFont.systemFont(ofSize: 560, weight: .bold)
        try #require(font.capHeight > bands[0].maxY - bands[1].minY)
        let capTop = seam - font.capHeight / 2
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let photo = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            NSAttributedString(string: "$4.99", attributes: [.font: font, .foregroundColor: UIColor.black])
                .draw(at: CGPoint(x: 100, y: capTop - (font.ascender - font.capHeight)))
        }

        let result = try await recognizer.recognize(photo, menuCurrency: "USD")

        #expect(result.items.filter { $0.transcript.contains("4.99") }.count == 1, "read: \(result.items.map(\.transcript))")
    }

    @Test("the empty result carries no items and no pixel size")
    func emptyResultIsInert() {
        #expect(StillRecognitionResult.empty.items.isEmpty)
        #expect(StillRecognitionResult.empty.imagePixelSize == .zero)
    }
}
