@testable import CurrencySpot
import Foundation
import SwiftUI
import Testing

@Suite("ChartSelection Tests")
struct ChartSelectionTests {
    private let points: [ChartDataPoint]

    init() throws {
        points = try (1 ... 3).map { day in
            ChartDataPoint(date: try #require(createCETDate(year: 2025, month: 6, day: day)), rate: Double(day))
        }
    }

    @Test("a VoiceOver swipe starts from the latest point and stops at either end")
    func stepStartsAtTheLatestPointAndClamps() {
        var selection = ChartSelection()

        selection.step(.increment, through: points)
        #expect(selection.accessibilityIndex == 2)
        #expect(selection.date == points[2].date)

        selection.step(.decrement, through: points)
        selection.step(.decrement, through: points)
        selection.step(.decrement, through: points)
        #expect(selection.accessibilityIndex == 0)
        #expect(selection.date == points[0].date)
        #expect(selection.isActive)
    }

    @Test("ending the VoiceOver selection drops it and returns to the chart summary")
    func endingTheAccessibilitySelectionClearsIt() {
        var selection = ChartSelection()
        selection.step(.decrement, through: points)

        selection.endAccessibilitySelection()

        #expect(selection.isActive == false)
        #expect(selection.accessibilityIndex == nil)
    }

    @Test("ending the VoiceOver selection leaves a finger scrub alone")
    func endingTheAccessibilitySelectionKeepsAScrub() {
        var selection = ChartSelection()
        selection.date = points[1].date

        selection.endAccessibilitySelection()

        #expect(selection.date == points[1].date)
        #expect(selection.isActive)
    }

    @Test("clearing drops both a scrub and a VoiceOver selection")
    func clearDropsEverySelection() {
        var selection = ChartSelection()
        selection.step(.decrement, through: points)

        selection.clear()

        #expect(selection == ChartSelection())
        #expect(selection.isActive == false)
    }
}
