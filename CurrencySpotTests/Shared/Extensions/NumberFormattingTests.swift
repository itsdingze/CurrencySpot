@testable import CurrencySpot
import Testing

struct NumberFormattingTests {
    @Test func adjacentGridlinesOnANarrowRangeGetDistinctLabels() {
        let span = 0.895 - 0.885

        let labels = [0.88, 0.885, 0.89, 0.895].map { $0.axisLabel(across: span) }

        #expect(Set(labels).count == labels.count)
    }

    @Test func adjacentGridlinesOnATinyRateGetDistinctLabels() {
        let span = 0.000066 - 0.000062

        let labels = [0.000062, 0.000064, 0.000066].map { $0.axisLabel(across: span) }

        #expect(Set(labels).count == labels.count)
    }

    @Test func roundGridlinesOnAWideRangeKeepShortLabels() {
        #expect(0.88.axisLabel(across: 0.07) == "0.88")
        #expect(150.0.axisLabel(across: 10) == "150")
    }
}
