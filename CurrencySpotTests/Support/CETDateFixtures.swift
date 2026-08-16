@testable import CurrencySpot
import Foundation

func createCETDate(year: Int, month: Int, day: Int) -> Date? {
    let components = DateComponents(
        timeZone: TimeZoneManager.cetTimeZone,
        year: year,
        month: month,
        day: day
    )
    return TimeZoneManager.cetCalendar.date(from: components)
}
