//
//  TestSupport.swift
//  CurrencySpotTests
//

@testable import CurrencySpot
import Foundation

/// Builds a Date at midnight CET from calendar components, for use as a test fixture.
func createCETDate(year: Int, month: Int, day: Int) -> Date? {
    let components = DateComponents(
        timeZone: TimeZoneManager.cetTimeZone,
        year: year,
        month: month,
        day: day
    )
    return TimeZoneManager.cetCalendar.date(from: components)
}
