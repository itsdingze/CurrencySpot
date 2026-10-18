@testable import CurrencySpot
import Foundation

func createCETDate(year: Int, month: Int, day: Int) -> Date? {
    let components = DateComponents(
        timeZone: CETCalendar.timeZone,
        year: year,
        month: month,
        day: day
    )
    return CETCalendar.calendar.date(from: components)
}
