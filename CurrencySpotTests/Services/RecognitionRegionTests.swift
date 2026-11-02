@testable import CurrencySpot
import CoreGraphics
import Testing

@Suite("Recognition Region Tests")
struct RecognitionRegionTests {
    @Test("a short image is read whole")
    func shortImageIsReadWhole() {
        let size = CGSize(width: 1200, height: 900)

        let regions = RecognitionRegion.regions(covering: size)

        #expect(regions.map(\.rect) == [CGRect(origin: .zero, size: size)])
    }

    @Test("a tall image is read in full-width bands that overlap and together cover its height", arguments: [
        CGSize(width: 2016, height: 4032), CGSize(width: 4032, height: 3024),
    ])
    func tallImageIsReadInOverlappingBands(size: CGSize) throws {
        let bands = RecognitionRegion.regions(covering: size).map(\.rect).filter { $0.height < size.height }

        #expect(bands.count > 1)
        #expect(bands.allSatisfy { $0.minX == 0 && $0.width == size.width })
        #expect(bands.first?.minY == 0)
        #expect(bands.last?.maxY == size.height)
        #expect(zip(bands, bands.dropFirst()).allSatisfy { upper, lower in lower.minY < upper.maxY })
    }

    @Test("a band leaves out a line that its edge with the next band cuts through")
    func bandDropsLineCutByItsInteriorEdge() throws {
        let regions = RecognitionRegion.regions(covering: CGSize(width: 2016, height: 4032))
        let upperBand = try #require(regions.first)
        let lowerBand = try #require(regions.dropFirst().first)
        let cutAtBottom = CGRect(x: 100, y: upperBand.rect.maxY - 42, width: 400, height: 30)
        let cutAtTop = CGRect(x: 100, y: lowerBand.rect.minY + 12, width: 400, height: 30)

        #expect(upperBand.keeps(cutAtBottom) == false)
        #expect(lowerBand.keeps(cutAtTop) == false)
    }

    @Test("a band keeps lines inside it and lines at the image's own edges")
    func bandKeepsWholeLinesAndImageEdges() throws {
        let size = CGSize(width: 2016, height: 4032)
        let regions = RecognitionRegion.regions(covering: size)
        let upperBand = try #require(regions.first)
        let lastBand = try #require(regions.last { $0.rect.maxY == size.height && $0.rect.minY > 0 })
        let inside = CGRect(x: 100, y: upperBand.rect.midY, width: 400, height: 30)
        let atImageTop = CGRect(x: 100, y: 0, width: 400, height: 30)
        let atImageBottom = CGRect(x: 100, y: size.height - 30, width: 400, height: 30)

        #expect(upperBand.keeps(inside))
        #expect(upperBand.keeps(atImageTop))
        #expect(lastBand.keeps(atImageBottom))
    }

    @Test("a tall image is also read whole, for lines too tall to fit inside one band")
    func tallImageIsAlsoReadWholeForTallLines() throws {
        let size = CGSize(width: 2016, height: 4032)
        let regions = RecognitionRegion.regions(covering: size)
        let wholeFrame = try #require(regions.first { $0.rect == CGRect(origin: .zero, size: size) })
        let bands = regions.filter { $0 != wholeFrame }.map(\.rect)
        let overlap = try #require(zip(bands, bands.dropFirst()).map { upper, lower in upper.maxY - lower.minY }.min())
        let tooTallForABand = CGRect(x: 100, y: 1100, width: 1200, height: overlap + 100)
        let smallLine = CGRect(x: 100, y: 1100, width: 400, height: 30)

        #expect(wholeFrame.keeps(tooTallForABand))
        #expect(wholeFrame.keeps(smallLine) == false)
    }
}
