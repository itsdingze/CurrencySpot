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

    @Test func smallRateKeepsFourSignificantDigits() {
        #expect(0.0063509.rateText == "0.006351")
        #expect(0.00006154.rateText == "0.00006154")
    }

    @Test func largerRateKeepsFiveSignificantDigitsAndEveryWholeDigit() {
        #expect(1.401.rateText == "1.4010")
        #expect(157.458.rateText == "157.46")
        #expect(1338.12.rateText == "1,338.1")
        #expect(123_456.7.rateText == "123,457")
    }

    @Test func zeroRateShowsAsZero() {
        #expect(0.0.rateText == "0")
    }

    @Test func rateChangeShowsAsManyDecimalsAsItsRate() {
        #expect(0.00466.rateText(matching: 0.8959) == "0.0047")
        #expect(0.93.rateText(matching: 158.01) == "0.93")
        #expect(0.0000321.rateText(matching: 0.006351) == "0.000032")
    }

    @Test func roundGridlinesOnAWideRangeKeepShortLabels() {
        #expect(0.88.axisLabel(across: 0.07) == "0.88")
        #expect(150.0.axisLabel(across: 10) == "150")
    }
}
