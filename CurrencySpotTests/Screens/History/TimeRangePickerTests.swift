import CoreGraphics
@testable import CurrencySpot
import Testing

struct TimeRangePickerTests {
    @Test func labelsThatFitKeepFullSize() {
        #expect(TimeRangePicker.sharedLabelScale(available: 40, widestLabel: 30) == 1)
    }

    @Test func oneLabelTooWideShrinksEveryLabelByTheSameFactor() {
        #expect(TimeRangePicker.sharedLabelScale(available: 40, widestLabel: 50) == 0.8)
    }

    @Test func oversizedLabelsStayVisibleAsSpaceShrinks() {
        let narrowScale = TimeRangePicker.sharedLabelScale(available: 20, widestLabel: 200)
        let widerScale = TimeRangePicker.sharedLabelScale(available: 40, widestLabel: 200)

        #expect(narrowScale > 0)
        #expect(narrowScale <= widerScale)
        #expect(widerScale <= 1)
    }

    @Test func unmeasuredLabelsKeepFullSize() {
        #expect(TimeRangePicker.sharedLabelScale(available: 40, widestLabel: 0) == 1)
    }
}
