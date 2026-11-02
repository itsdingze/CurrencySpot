@testable import CurrencySpot
import Testing
import UIKit

@Suite("Still Image Decoder Tests")
struct StillImageDecoderTests {
    private let decoder = StillImageDecoder()

    private func jpegData(width: Int, height: Int, orientation: UIImage.Orientation = .up) throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let size = CGSize(width: width, height: height)
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.gray.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        let cgImage = try #require(rendered.cgImage)
        return try #require(UIImage(cgImage: cgImage, scale: 1, orientation: orientation).jpegData(compressionQuality: 0.8))
    }

    @Test("a photo larger than the cap is decoded with its long side at the cap and its shape kept")
    func largePhotoIsCappedAtTheLongSide() async throws {
        let data = try jpegData(width: 5000, height: 200)

        let image = try #require(await decoder.decode(data))

        let cgImage = try #require(image.cgImage)
        #expect(cgImage.width == 4096)
        #expect(abs(cgImage.height - 164) <= 1)
    }

    @Test("a photo within the cap keeps its pixel size")
    func smallPhotoIsNotUpscaled() async throws {
        let data = try jpegData(width: 120, height: 60)

        let image = try #require(await decoder.decode(data))

        #expect(image.cgImage?.width == 120)
        #expect(image.cgImage?.height == 60)
    }

    @Test("a photo stored sideways with an EXIF rotation is decoded upright")
    func rotatedPhotoIsDecodedUpright() async throws {
        let data = try jpegData(width: 120, height: 60, orientation: .right)

        let image = try #require(await decoder.decode(data))

        #expect(image.imageOrientation == .up)
        #expect(image.cgImage?.width == 60)
        #expect(image.cgImage?.height == 120)
    }

    @Test("data that is not an image decodes to nothing")
    func undecodableDataYieldsNothing() async {
        let image = await decoder.decode(Data("not an image".utf8))

        #expect(image == nil)
    }
}
